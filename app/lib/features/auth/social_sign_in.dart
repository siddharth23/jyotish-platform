/// The port to the platform sign-in sheets (US-012 AC1, AC2).
///
/// ## Why this is an interface with no real implementation yet
///
/// The adapters are two thin wrappers — `sign_in_with_apple` and
/// `google_sign_in` — and neither can do anything without credentials that do
/// not exist: an Apple Services ID and the Sign in with Apple capability on a
/// provisioning profile, and OAuth client IDs for both an Android signing
/// certificate and an iOS bundle. `.env.example` has no entry for either
/// because there is nothing yet to put in one.
///
/// Everything that is hard about this story — the Guideline 4.8 rule, Apple's
/// first-authorisation disclosure, when an account may be linked — is decided
/// on this side of the port and is tested. What is missing is the twenty lines
/// that call an SDK. See the module README for exactly what wiring them needs.
library;

import 'social_credential.dart';
import 'social_provider.dart';

/// The result of asking a provider to authorise.
sealed class SocialAuthorisation {
  const SocialAuthorisation();
}

class SocialAuthorisationGranted extends SocialAuthorisation {
  const SocialAuthorisationGranted(this.credential);

  final SocialCredential credential;
}

/// The user dismissed the sheet.
///
/// A distinct case, not an error. Cancelling is the most common outcome of a
/// sign-in sheet and showing an error for it makes the app look broken.
class SocialAuthorisationCancelled extends SocialAuthorisation {
  const SocialAuthorisationCancelled();
}

class SocialAuthorisationFailed extends SocialAuthorisation {
  const SocialAuthorisationFailed(this.reason);

  final SocialAuthorisationFailureReason reason;
}

enum SocialAuthorisationFailureReason {
  /// No usable connection. Retryable, and the only reason worth a retry button.
  network,

  /// The SDK is present but unusable — missing configuration, no Apple ID on
  /// the device, Play Services out of date.
  providerUnavailable,

  /// The provider returned something that did not parse.
  malformedResponse,

  unknown,
}

/// Drives the platform sign-in sheet for one provider.
abstract interface class SocialSignIn {
  /// Whether this build can actually run [provider].
  ///
  /// Distinct from [SocialSignInAvailability]: that answers what the *rules*
  /// permit, this answers what the device and the binary can do. A provider
  /// must pass both.
  Future<bool> isAvailable(SocialProvider provider);

  Future<SocialAuthorisation> authorise(SocialProvider provider);

  /// Clears any cached provider session.
  ///
  /// Called on sign-out. Without it, Google's SDK silently re-authorises the
  /// previous account and "sign out, sign in as someone else" returns the
  /// person who just left — which on a shared device is a data breach.
  Future<void> signOut();
}

/// A [SocialSignIn] with no providers at all.
///
/// What ships until the adapters exist. Reports every provider unavailable,
/// which makes [SocialSignInAvailability.providersFor] collapse to an empty
/// list and the sign-in screen fall back to email and password — the flow that
/// does work (US-011). Nothing pretends to succeed.
class UnconfiguredSocialSignIn implements SocialSignIn {
  const UnconfiguredSocialSignIn();

  @override
  Future<bool> isAvailable(SocialProvider provider) async => false;

  @override
  Future<SocialAuthorisation> authorise(SocialProvider provider) async =>
      const SocialAuthorisationFailed(
        SocialAuthorisationFailureReason.providerUnavailable,
      );

  @override
  Future<void> signOut() async {}
}

/// A scripted [SocialSignIn] for tests and for driving the UI in development.
class FakeSocialSignIn implements SocialSignIn {
  FakeSocialSignIn({
    Map<SocialProvider, SocialAuthorisation>? responses,
    Set<SocialProvider> available = const {
      SocialProvider.apple,
      SocialProvider.google,
    },
  })  : _responses = responses ?? {},
        _available = available;

  final Map<SocialProvider, SocialAuthorisation> _responses;
  final Set<SocialProvider> _available;

  /// Providers [authorise] has been called for, in order.
  final List<SocialProvider> authorisations = [];
  int signOutCount = 0;

  void respondWith(SocialProvider provider, SocialAuthorisation response) {
    _responses[provider] = response;
  }

  @override
  Future<bool> isAvailable(SocialProvider provider) async =>
      _available.contains(provider);

  @override
  Future<SocialAuthorisation> authorise(SocialProvider provider) async {
    authorisations.add(provider);
    return _responses[provider] ??
        const SocialAuthorisationFailed(
          SocialAuthorisationFailureReason.unknown,
        );
  }

  @override
  Future<void> signOut() async => signOutCount += 1;
}
