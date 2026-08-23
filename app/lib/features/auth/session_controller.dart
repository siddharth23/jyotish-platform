/// Holds the device's session and renews it (US-016).
///
/// ## Refreshing twice concurrently signs the user out
///
/// This is the constraint the whole class is shaped around. The server rotates
/// the refresh token on every use and treats a *second* presentation of an
/// already-rotated token as proof the token was copied — it revokes the entire
/// family and forces a real login. See `api/src/modules/identity/session.ts`.
///
/// So the ordinary client bug of firing a refresh per in-flight request is not
/// merely wasteful here: three requests hitting a stale access token at once
/// means three refreshes with the same token, of which one succeeds and two
/// look exactly like theft. The user is signed out of every device because
/// their app opened three screens at once.
///
/// [SessionController.currentAccessToken] therefore collapses concurrent
/// callers onto a single in-flight refresh and hands them all its result. The
/// single-flight is not an optimisation; it is what makes rotation safe.
///
/// ## A late read must never resurrect a signed-out session
///
/// Restoring from disk is asynchronous, and sign-out is not. Without a guard,
/// a user who signs out while the launch read is still in flight gets their
/// tokens handed back to them a moment later. The same shape has already bitten
/// this codebase three times — see `flag_repository.dart`,
/// `telemetry_consent.dart` and `onboarding_controller.dart` — so it is
/// guarded here explicitly rather than hoped away.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/observability/app_logger.dart';
import 'secure_token_store.dart';
import 'session_tokens.dart';

/// Why a session ended without the user asking.
enum SessionEndReason {
  /// The refresh token was rejected: revoked, expired, or reused.
  ///
  /// Indistinguishable from the client's side on purpose — the server does not
  /// tell a possible thief which it was.
  refreshRejected,

  /// The refresh could not be attempted. The session may still be fine.
  network,
}

sealed class SessionState {
  const SessionState();
}

/// Before the stored tokens have been read. Distinct from [SessionSignedOut]:
/// routing on it would flash the sign-in screen at every launch.
class SessionRestoring extends SessionState {
  const SessionRestoring();
}

class SessionSignedOut extends SessionState {
  const SessionSignedOut({this.reason});

  /// Null when the user signed out deliberately.
  final SessionEndReason? reason;
}

class SessionActive extends SessionState {
  const SessionActive(this.tokens);

  final SessionTokens tokens;
}

/// Exchanges a refresh token for a new pair. Implemented against the API's
/// `/auth/refresh` once `api/src/main.ts` has an HTTP layer.
abstract interface class SessionRefresher {
  /// Returns the new pair, or null if the server rejected the token.
  ///
  /// Throws for a network failure: a rejection and an unreachable server must
  /// not be conflated, because one means sign out and the other means retry.
  Future<SessionTokens?> refresh(String refreshToken);
}

/// The refresher until the API exists. Always throws, so nothing in this flow
/// can be mistaken for working — as with `UnavailableAuthGateway`.
class UnavailableSessionRefresher implements SessionRefresher {
  const UnavailableSessionRefresher();

  @override
  Future<SessionTokens?> refresh(String refreshToken) =>
      throw StateError('The API has no refresh endpoint yet.');
}

class SessionController extends StateNotifier<SessionState> {
  SessionController({
    required SecureTokenStore store,
    required SessionRefresher refresher,
    required AppLogger logger,
    DateTime Function()? now,
  })  : _store = store,
        _refresher = refresher,
        _logger = logger,
        _now = now ?? DateTime.now,
        super(const SessionRestoring());

  final SecureTokenStore _store;
  final SessionRefresher _refresher;
  final AppLogger _logger;
  final DateTime Function() _now;

  /// The in-flight refresh, if any. The single-flight latch — see the header.
  Future<SessionTokens?>? _inFlight;

  /// Set the moment anything decides this session is over.
  ///
  /// The guard against a late restore or a late refresh writing tokens back
  /// after sign-out. Checked rather than assumed because both of those run
  /// asynchronously and sign-out does not wait for them.
  bool _ended = false;

  /// Reads the stored tokens at launch.
  Future<void> restore() async {
    final stored = await _store.read();
    // Signed out while this read was in flight. Honour the sign-out.
    if (_ended || !mounted) return;
    state = stored == null ? const SessionSignedOut() : SessionActive(stored);
  }

  /// Records a freshly issued session after a successful sign-in.
  Future<void> begin(SessionTokens tokens) async {
    _ended = false;
    await _store.write(tokens);
    if (!mounted) return;
    state = SessionActive(tokens);
  }

  /// Returns a usable access token, refreshing first if it is spent.
  ///
  /// Every caller shares one refresh. Returns null when there is no session, or
  /// when the refresh was rejected and the device has just been signed out.
  Future<String?> currentAccessToken() async {
    final current = state;
    if (current is! SessionActive) return null;
    if (!current.tokens.needsRefresh(_now())) return current.tokens.accessToken;

    final refreshed = await _refreshOnce(current.tokens.refreshToken);
    return refreshed?.accessToken;
  }

  /// Collapses concurrent refreshes onto one call.
  ///
  /// The latch is set *before* the first `await` so a second caller arriving
  /// synchronously after the first still sees it. Dart's single thread makes
  /// that sufficient; an `await` before the assignment would not be.
  Future<SessionTokens?> _refreshOnce(String refreshToken) {
    final existing = _inFlight;
    if (existing != null) return existing;

    final attempt = _performRefresh(refreshToken);
    _inFlight = attempt;
    return attempt.whenComplete(() {
      if (identical(_inFlight, attempt)) _inFlight = null;
    });
  }

  Future<SessionTokens?> _performRefresh(String refreshToken) async {
    final SessionTokens? renewed;
    try {
      renewed = await _refresher.refresh(refreshToken);
    } catch (_) {
      // Unreachable server. The session is not known to be bad, so the tokens
      // stay put and the caller can try again — signing out on a dropped
      // connection would log people out on the underground.
      _logger.warn('session refresh failed', const {
        'operation': 'session_refresh',
      });
      return null;
    }

    if (_ended) return null;

    if (renewed == null) {
      // Revoked, expired or reused. All three end the session.
      await _endSession(SessionEndReason.refreshRejected);
      return null;
    }

    await _store.write(renewed);
    if (_ended || !mounted) return null;
    state = SessionActive(renewed);
    return renewed;
  }

  /// Signs this device out locally.
  ///
  /// Clearing the stored tokens is the whole of the local job; telling the
  /// server to revoke the session is the API call that goes with it, and is
  /// what makes the sixty-day refresh token stop working for good.
  Future<void> signOut() => _endSession(null);

  Future<void> _endSession(SessionEndReason? reason) async {
    _ended = true;
    _inFlight = null;
    await _store.clear();
    if (!mounted) return;
    state = SessionSignedOut(reason: reason);
  }
}

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>((ref) {
  throw UnimplementedError(
    'Override sessionControllerProvider at the root of the app.',
  );
});
