import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/observability/app_logger.dart';
import '../../core/observability/observability_providers.dart';
import 'account_linking.dart';
import 'apple_authorisation_store.dart';
import 'auth_gateway.dart';
import 'social_credential.dart';
import 'social_provider.dart';
import 'social_sign_in.dart';

/// Where the sign-in flow currently is (US-012).
sealed class AuthState {
  const AuthState();
}

/// Nothing happening. The state the screen is drawn from.
class AuthIdle extends AuthState {
  const AuthIdle();
}

/// A provider sheet is open, or its result is being exchanged with the API.
class AuthInProgress extends AuthState {
  const AuthInProgress(this.provider);

  final SocialProvider provider;
}

class AuthSignedIn extends AuthState {
  const AuthSignedIn({
    required this.accountId,
    required this.emailVerified,
    required this.isNewAccount,
    required this.usedPrivateRelay,
  });

  final String accountId;
  final bool emailVerified;
  final bool isNewAccount;

  /// Whether this account is reachable only through Apple's forwarding.
  ///
  /// The screen tells the user, once, at the point they have just created such
  /// an account: the €11 report arrives by email, and a forwarding address they
  /// later switch off makes the order undeliverable.
  final bool usedPrivateRelay;
}

/// An account already exists for this address, and the user has to decide.
class AuthAwaitingLinkDecision extends AuthState {
  const AuthAwaitingLinkDecision({
    required this.decision,
    required this.credential,
  });

  final LinkDecision decision;

  /// Held so confirming does not require authorising a second time.
  ///
  /// It stays in memory only. Persisting a live identity token would leave a
  /// bearer credential on disk for the length of an undecided prompt.
  final SocialCredential credential;
}

class AuthFailure extends AuthState {
  const AuthFailure(this.reason);

  final AuthFailureReason reason;
}

/// Why a sign-in did not complete.
///
/// Codes, not sentences. The strings are ICU resources; German is authored
/// first and is about 30% longer than English, so no message text lives here.
enum AuthFailureReason {
  /// Retryable — the only reason that should offer a retry button.
  network,

  /// The provider is not usable on this device or in this build.
  providerUnavailable,

  /// The provider's token did not verify server-side.
  tokenRejected,

  /// No endpoint yet. See [UnavailableAuthGateway].
  notImplemented,

  unknown,
}

/// Runs social sign-in (US-012).
///
/// Owns three things the screen should not: the double-tap guard, restoring
/// what Apple disclosed on a first authorisation, and keeping a cancelled sheet
/// from looking like an error.
class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required SocialSignIn signIn,
    required AuthGateway gateway,
    required AppleAuthorisationStore appleStore,
    AppLogger logger = const AppLogger(),
  })  : _signIn = signIn,
        _gateway = gateway,
        _appleStore = appleStore,
        _logger = logger,
        super(const AuthIdle());

  final SocialSignIn _signIn;
  final AuthGateway _gateway;
  final AppleAuthorisationStore _appleStore;
  final AppLogger _logger;

  Future<void> signInWith(SocialProvider provider) async {
    // A second tap while a sheet is open opens a second sheet on Android and
    // is silently dropped on iOS, so the two platforms disagree about what just
    // happened. Guarding here rather than by disabling the button means it also
    // holds for a programmatic caller.
    if (state is AuthInProgress) return;
    state = AuthInProgress(provider);

    final authorisation = await _signIn.authorise(provider);
    switch (authorisation) {
      case SocialAuthorisationCancelled():
        // Not a failure. Dismissing the sheet is the most common thing that
        // happens to it, and an error banner for it makes the app look broken.
        state = const AuthIdle();
        return;
      case SocialAuthorisationFailed(:final reason):
        _logger.warn('social authorisation failed', {
          'operation': 'social_sign_in',
          'errorCode': reason.name,
        });
        state = AuthFailure(_failureFor(reason));
        return;
      case SocialAuthorisationGranted(:final credential):
        await _exchange(credential);
    }
  }

  Future<void> _exchange(SocialCredential credential) async {
    // Written to disk before the network is touched. Apple discloses the
    // address once; a request that fails after this point must not take it with
    // it, because there is no way to ask for it again.
    final enriched = await withRememberedAppleDetails(credential, _appleStore);

    final result = await _gateway.exchangeSocialCredential(enriched);
    _applyExchangeResult(result, enriched);
  }

  /// Completes a link the user approved on the prompt.
  Future<void> confirmLink() async {
    final current = state;
    if (current is! AuthAwaitingLinkDecision) return;
    if (current.decision is! LinkToExistingAccount) {
      // Proof of control is not something this screen can collect. Approving it
      // here would be linking on an unverified address, which is the takeover
      // this flow exists to prevent.
      return;
    }
    state = AuthInProgress(current.credential.provider);
    final result = await _gateway.confirmLink(current.credential);
    _applyExchangeResult(result, current.credential);
  }

  /// Dismisses the link prompt without linking.
  void dismissLinkPrompt() {
    if (state is AuthAwaitingLinkDecision) state = const AuthIdle();
  }

  /// Clears an error so the screen returns to its buttons.
  void dismissFailure() {
    if (state is AuthFailure) state = const AuthIdle();
  }

  Future<void> signOut() async {
    // The provider's own session has to go too. Google re-authorises the last
    // account silently, so without this "sign out and sign in as someone else"
    // returns the person who just left — on a shared device, a data breach.
    await _signIn.signOut();
    state = const AuthIdle();
  }

  void _applyExchangeResult(
    SocialExchangeResult result,
    SocialCredential credential,
  ) {
    switch (result) {
      case SocialExchangeSignedIn(
          :final accountId,
          :final isNewAccount,
          :final emailVerified
        ):
        _logger.info('social sign-in complete', {
          'operation': 'social_sign_in',
          'userId': accountId,
        });
        state = AuthSignedIn(
          accountId: accountId,
          emailVerified: emailVerified,
          isNewAccount: isNewAccount,
          usedPrivateRelay: credential.isApplePrivateRelay,
        );
      case SocialExchangeNeedsLinking(:final decision):
        state = AuthAwaitingLinkDecision(
          decision: decision,
          credential: credential,
        );
      case SocialExchangeFailed(:final reason):
        _logger.warn('social exchange failed', {
          'operation': 'social_sign_in',
          'errorCode': reason.name,
        });
        state = AuthFailure(switch (reason) {
          SocialExchangeFailureReason.network => AuthFailureReason.network,
          SocialExchangeFailureReason.tokenRejected =>
            AuthFailureReason.tokenRejected,
          SocialExchangeFailureReason.notImplemented =>
            AuthFailureReason.notImplemented,
          SocialExchangeFailureReason.unknown => AuthFailureReason.unknown,
        });
    }
  }

  AuthFailureReason _failureFor(SocialAuthorisationFailureReason reason) =>
      switch (reason) {
        SocialAuthorisationFailureReason.network => AuthFailureReason.network,
        SocialAuthorisationFailureReason.providerUnavailable =>
          AuthFailureReason.providerUnavailable,
        SocialAuthorisationFailureReason.malformedResponse =>
          AuthFailureReason.unknown,
        SocialAuthorisationFailureReason.unknown => AuthFailureReason.unknown,
      };
}

/// The platform sign-in adapter.
///
/// [UnconfiguredSocialSignIn] until the Apple and Google credentials exist —
/// see `social_sign_in.dart`. Overridden in tests and in the design gallery.
final socialSignInProvider = Provider<SocialSignIn>(
  (ref) => const UnconfiguredSocialSignIn(),
);

/// The API. Unavailable until the backend has an HTTP layer.
final authGatewayProvider = Provider<AuthGateway>(
  (ref) => const UnavailableAuthGateway(),
);

final appleAuthorisationStoreProvider = Provider<AppleAuthorisationStore>(
  (ref) => SharedPreferencesAppleAuthorisationStore(),
);

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(
    signIn: ref.watch(socialSignInProvider),
    gateway: ref.watch(authGatewayProvider),
    appleStore: ref.watch(appleAuthorisationStoreProvider),
    logger: ref.watch(appLoggerProvider),
  ),
);

/// Which providers this build may offer, for the platform it is running on.
///
/// Combines the Guideline 4.8 rules with what the adapters can actually do.
/// Both must agree — a provider the rules permit but the binary cannot run
/// would draw a button that fails on tap.
final availableSocialProvidersProvider =
    FutureProvider.family<List<SocialProvider>, SignInPlatform>(
  (ref, platform) async {
    final signIn = ref.watch(socialSignInProvider);
    final usable = <SocialProvider>{};
    for (final provider in SocialSignInAvailability.supportedOn(platform)) {
      if (await signIn.isAvailable(provider)) usable.add(provider);
    }
    return SocialSignInAvailability.providersFor(platform, enabled: usable);
  },
);
