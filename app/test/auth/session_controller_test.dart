import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish_app/core/observability/app_logger.dart';
import 'package:jyotish_app/features/auth/secure_token_store.dart';
import 'package:jyotish_app/features/auth/session_controller.dart';
import 'package:jyotish_app/features/auth/session_tokens.dart';

/// Synthetic throughout: CLAUDE.md forbids real personal data in fixtures.
final DateTime now = DateTime.utc(2026, 8, 6, 9);

SessionTokens tokensExpiringIn(Duration ttl, {String suffix = '1'}) =>
    SessionTokens(
      accessToken: 'access-$suffix',
      accessTokenExpiresAt: now.add(ttl),
      refreshToken: 'refresh-$suffix',
      sessionId: 'session-$suffix',
    );

/// A refresher whose behaviour each test dictates.
class FakeRefresher implements SessionRefresher {
  FakeRefresher({this.result, this.throws = false});

  SessionTokens? result;
  bool throws;
  int calls = 0;
  final List<String> presented = [];

  /// Set to hold refreshes open, so a test can have two callers in flight.
  Completer<void>? gate;

  @override
  Future<SessionTokens?> refresh(String refreshToken) async {
    calls += 1;
    presented.add(refreshToken);
    if (gate != null) await gate!.future;
    if (throws) throw StateError('unreachable');
    return result;
  }
}

SessionController makeController({
  required SecureTokenStore store,
  required SessionRefresher refresher,
}) {
  final controller = SessionController(
    store: store,
    refresher: refresher,
    logger: AppLogger(sink: MemoryLogSink()),
    now: () => now,
  );
  // A Riverpod 3 Notifier draws `ref` and `state` from its provider element,
  // so a merely-constructed one throws "uninitialized state". Reading the
  // provider once runs `build` and mounts it.
  final container = ProviderContainer(
    overrides: [sessionControllerProvider.overrideWith(() => controller)],
  );
  addTearDown(container.dispose);
  container.read(sessionControllerProvider);
  return controller;
}

void main() {
  group('US-016 AC2 — tokens are held in the secure store', () {
    test('a restored session comes back from the store', () async {
      final store =
          InMemoryTokenStore(tokensExpiringIn(const Duration(hours: 1)));
      final controller = makeController(
        store: store,
        refresher: FakeRefresher(),
      );

      await controller.restore();

      expect(controller.state, isA<SessionActive>());
      expect(
        (controller.state as SessionActive).tokens.sessionId,
        'session-1',
      );
    });

    test('no stored tokens means signed out, not restoring', () async {
      final controller = makeController(
        store: InMemoryTokenStore(),
        refresher: FakeRefresher(),
      );

      await controller.restore();

      expect(controller.state, isA<SessionSignedOut>());
    });

    test('signing out clears the store, not just the state', () async {
      final store =
          InMemoryTokenStore(tokensExpiringIn(const Duration(hours: 1)));
      final controller = makeController(
        store: store,
        refresher: FakeRefresher(),
      );
      await controller.restore();

      await controller.signOut();

      expect(await store.read(), isNull);
      expect(controller.state, isA<SessionSignedOut>());
    });

    test('tokens never appear in toString', () {
      final tokens = tokensExpiringIn(const Duration(hours: 1));
      expect(tokens.toString(), isNot(contains('access-1')));
      expect(tokens.toString(), isNot(contains('refresh-1')));
      expect(tokens.toString(), contains('session-1'));
    });

    test('a corrupt stored blob reads as signed out rather than throwing', () {
      expect(SessionTokens.fromJson(const {'accessToken': 'a'}), isNull);
      expect(
        SessionTokens.fromJson(const {
          'accessToken': 'a',
          'accessTokenExpiresAt': 'not-a-date',
          'refreshToken': 'r',
          'sessionId': 's',
        }),
        isNull,
      );
    });

    test('a written pair round-trips', () {
      final tokens = tokensExpiringIn(const Duration(hours: 1));
      final restored = SessionTokens.fromJson(tokens.toJson());
      expect(restored!.accessToken, tokens.accessToken);
      expect(restored.refreshToken, tokens.refreshToken);
      expect(restored.accessTokenExpiresAt, tokens.accessTokenExpiresAt);
    });
  });

  group('US-016 AC1 — the access token is renewed before it expires', () {
    test('a live token is used as-is, with no refresh', () async {
      final refresher = FakeRefresher();
      final controller = makeController(
        store:
            InMemoryTokenStore(tokensExpiringIn(const Duration(minutes: 10))),
        refresher: refresher,
      );
      await controller.restore();

      expect(await controller.currentAccessToken(), 'access-1');
      expect(refresher.calls, 0);
    });

    test('a token inside the skew window is renewed early', () async {
      // Expiring in twenty seconds, skew is thirty: spent, though not expired.
      final refresher = FakeRefresher(
        result: tokensExpiringIn(const Duration(minutes: 15), suffix: '2'),
      );
      final controller = makeController(
        store:
            InMemoryTokenStore(tokensExpiringIn(const Duration(seconds: 20))),
        refresher: refresher,
      );
      await controller.restore();

      expect(await controller.currentAccessToken(), 'access-2');
      expect(refresher.calls, 1);
    });

    test('the renewed pair is persisted, not just held in memory', () async {
      final store = InMemoryTokenStore(tokensExpiringIn(Duration.zero));
      final controller = makeController(
        store: store,
        refresher: FakeRefresher(
          result: tokensExpiringIn(const Duration(minutes: 15), suffix: '2'),
        ),
      );
      await controller.restore();

      await controller.currentAccessToken();

      expect((await store.read())!.refreshToken, 'refresh-2');
    });

    test('no session means no token and no refresh attempt', () async {
      final refresher = FakeRefresher();
      final controller = makeController(
        store: InMemoryTokenStore(),
        refresher: refresher,
      );
      await controller.restore();

      expect(await controller.currentAccessToken(), isNull);
      expect(refresher.calls, 0);
    });
  });

  group('US-016 AC1 — concurrent refreshes must not look like token theft', () {
    test('three callers produce exactly one refresh', () async {
      // The server revokes the whole family if a rotated token is presented
      // twice. Three refreshes here would sign the user out of every device.
      final refresher = FakeRefresher(
        result: tokensExpiringIn(const Duration(minutes: 15), suffix: '2'),
      )..gate = Completer<void>();
      final store = InMemoryTokenStore(tokensExpiringIn(Duration.zero));
      final controller = makeController(store: store, refresher: refresher);
      await controller.restore();

      final calls = [
        controller.currentAccessToken(),
        controller.currentAccessToken(),
        controller.currentAccessToken(),
      ];
      refresher.gate!.complete();
      final results = await Future.wait(calls);

      expect(refresher.calls, 1);
      expect(results, ['access-2', 'access-2', 'access-2']);
      expect(store.writes, 1, reason: 'one refresh, one write');
    });

    test('the rotated token is presented once and only once', () async {
      final refresher = FakeRefresher(
        result: tokensExpiringIn(const Duration(minutes: 15), suffix: '2'),
      )..gate = Completer<void>();
      final controller = makeController(
        store: InMemoryTokenStore(tokensExpiringIn(Duration.zero)),
        refresher: refresher,
      );
      await controller.restore();

      final calls = [
        controller.currentAccessToken(),
        controller.currentAccessToken(),
      ];
      refresher.gate!.complete();
      await Future.wait(calls);

      expect(refresher.presented, ['refresh-1']);
    });

    test('a later refresh runs again rather than reusing the finished one',
        () async {
      final refresher = FakeRefresher(
        result: tokensExpiringIn(Duration.zero, suffix: '2'),
      );
      final controller = makeController(
        store: InMemoryTokenStore(tokensExpiringIn(Duration.zero)),
        refresher: refresher,
      );
      await controller.restore();

      await controller.currentAccessToken();
      await controller.currentAccessToken();

      expect(refresher.calls, 2, reason: 'the latch clears when it completes');
    });
  });

  group('US-016 AC3/AC4 — a rejected refresh ends the session', () {
    test('a rejection signs the device out and clears the store', () async {
      final store = InMemoryTokenStore(tokensExpiringIn(Duration.zero));
      final controller = makeController(
        store: store,
        refresher: FakeRefresher(result: null),
      );
      await controller.restore();

      expect(await controller.currentAccessToken(), isNull);
      expect(controller.state, isA<SessionSignedOut>());
      expect(
        (controller.state as SessionSignedOut).reason,
        SessionEndReason.refreshRejected,
      );
      expect(await store.read(), isNull);
    });

    test('a network failure keeps the session so the user can retry', () async {
      // Signing out on a dropped connection would log people out on the
      // underground. A rejection and an unreachable server are not the same.
      final store = InMemoryTokenStore(tokensExpiringIn(Duration.zero));
      final controller = makeController(
        store: store,
        refresher: FakeRefresher(throws: true),
      );
      await controller.restore();

      expect(await controller.currentAccessToken(), isNull);
      expect(controller.state, isA<SessionActive>());
      expect(await store.read(), isNotNull);
    });
  });

  group('US-016 — a late read must not resurrect a signed-out session', () {
    test('signing out during restore wins', () async {
      final controller = makeController(
        store: SlowStore(tokensExpiringIn(const Duration(hours: 1))),
        refresher: FakeRefresher(),
      );

      final restoring = controller.restore();
      await controller.signOut();
      await restoring;

      expect(controller.state, isA<SessionSignedOut>());
    });

    test('signing out during a refresh wins', () async {
      final refresher = FakeRefresher(
        result: tokensExpiringIn(const Duration(minutes: 15), suffix: '2'),
      )..gate = Completer<void>();
      final store = InMemoryTokenStore(tokensExpiringIn(Duration.zero));
      final controller = makeController(store: store, refresher: refresher);
      await controller.restore();

      final pending = controller.currentAccessToken();
      await controller.signOut();
      refresher.gate!.complete();

      expect(await pending, isNull);
      expect(controller.state, isA<SessionSignedOut>());
      expect(await store.read(), isNull,
          reason: 'the refresh must not rewrite');
    });
  });
}

/// A store whose read does not complete until the event loop turns, so a test
/// can interleave a sign-out with it.
class SlowStore implements SecureTokenStore {
  SlowStore(this._tokens);

  SessionTokens? _tokens;

  @override
  Future<SessionTokens?> read() async {
    await Future<void>.delayed(Duration.zero);
    return _tokens;
  }

  @override
  Future<void> write(SessionTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}
