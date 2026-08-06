import 'social_provider.dart';

/// What a provider hands back after the user authorises (US-012 AC3, AC4).
///
/// ## The client is not the source of truth
///
/// [email] and [displayName] arrive as plain fields from an SDK running in a
/// process the user controls. They are fine for showing on screen and useless
/// as evidence. **Account linking must be decided from the claims inside
/// [identityToken], verified server-side against the provider's public keys** —
/// linking on a client-supplied email string is a take-over primitive: send the
/// victim's address, receive their account.
///
/// The fields are kept anyway because the screen needs something to render
/// before the round trip, and because of the first-authorisation problem below.
class SocialCredential {
  const SocialCredential({
    required this.provider,
    required this.subjectId,
    required this.identityToken,
    this.authorisationCode,
    this.email,
    this.displayName,
    this.providerAssertsEmailVerified = false,
  });

  final SocialProvider provider;

  /// The provider's stable identifier for this user and this app.
  ///
  /// Apple's `user` and Google's `sub`. Stable across sign-ins and across
  /// reinstalls, and the only field that is always present — which is why the
  /// account is keyed on it rather than on the address.
  final String subjectId;

  /// The signed JWT. Verified by the API, never by this app.
  final String identityToken;

  /// Single-use code the API exchanges with the provider.
  final String? authorisationCode;

  /// The address the provider disclosed, if it disclosed one this time.
  ///
  /// Null is normal and expected. **Apple returns the email and the name only
  /// on the very first authorisation** — every sign-in after that carries the
  /// identifier and nothing else. See [AppleAuthorisationDetails].
  final String? email;

  /// Also first-authorisation-only on Apple.
  final String? displayName;

  /// Whether the provider states the address has been verified by it.
  ///
  /// Google supplies `email_verified`, and it is not always true — a Google
  /// Workspace account can carry an unverified address. Apple's addresses are
  /// verified by construction, relay or not.
  ///
  /// This drives whether an account may be linked automatically. See
  /// `account_linking.dart`.
  final bool providerAssertsEmailVerified;

  /// The domain Apple issues forwarding addresses on.
  static const String applePrivateRelayDomain = 'privaterelay.appleid.com';

  /// Whether [email] is an Apple "Hide My Email" forwarding address.
  ///
  /// Matched on the full domain after the `@`, case-insensitively. A
  /// `contains` check would also match `privaterelay.appleid.com.example.de`,
  /// which is a domain an attacker can register.
  bool get isApplePrivateRelay => isPrivateRelayAddress(email);

  /// Whether [address] is an Apple relay address.
  static bool isPrivateRelayAddress(String? address) {
    if (address == null) return false;
    final at = address.lastIndexOf('@');
    if (at < 0) return false;
    return address.substring(at + 1).toLowerCase() == applePrivateRelayDomain;
  }

  SocialCredential copyWith({String? email, String? displayName}) =>
      SocialCredential(
        provider: provider,
        subjectId: subjectId,
        identityToken: identityToken,
        authorisationCode: authorisationCode,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        providerAssertsEmailVerified: providerAssertsEmailVerified,
      );

  /// Redacted on purpose.
  ///
  /// This type holds an address and a signed token. `CLAUDE.md` forbids either
  /// in logs, and a `toString` that prints them will eventually reach one —
  /// through an error message, a crash report, or a debugger's console.
  @override
  String toString() =>
      'SocialCredential(${provider.wireName}, subject: ${_maskSubject(subjectId)}, '
      'email: ${email == null ? 'absent' : 'present'})';

  static String _maskSubject(String subject) =>
      subject.length <= 6 ? '***' : '${subject.substring(0, 3)}***';
}

/// What Apple disclosed on a user's **first** authorisation.
///
/// ## Why this exists
///
/// Apple returns the email address and the full name exactly once — on the
/// first authorisation for this Apple ID and this app. Every later sign-in
/// returns the identifier alone. If the app loses what it was given the first
/// time, it cannot ask again: the user has to visit Settings, revoke the app
/// under their Apple ID, and start over. Nobody does that. Support carries it
/// instead.
///
/// Losing it is easy. Apple returns the address, the app posts it to the API,
/// the request times out on a train, the user taps the button again, and the
/// second authorisation carries no address at all. So the details are written
/// to disk the instant they arrive, before anything is sent anywhere, and
/// replayed onto later credentials for the same [subjectId].
///
/// This is device-local storage of an address the user has just chosen to share
/// with this app. Deleting the app deletes it.
class AppleAuthorisationDetails {
  const AppleAuthorisationDetails({
    required this.subjectId,
    this.email,
    this.displayName,
  });

  final String subjectId;
  final String? email;
  final String? displayName;

  bool get isEmpty => email == null && displayName == null;

  /// Whether the stored address is a forwarding address.
  bool get isPrivateRelay => SocialCredential.isPrivateRelayAddress(email);
}

/// Persists first-authorisation details across launches.
///
/// An interface so the controller can be tested without a disk, and so the
/// implementation can move from `SharedPreferences` to the Keychain later
/// without touching callers.
abstract interface class AppleAuthorisationStore {
  Future<AppleAuthorisationDetails?> read(String subjectId);

  /// Records details for [subjectId].
  ///
  /// Implementations must **not** overwrite a stored non-null value with null.
  /// The whole point is that the second authorisation carries less than the
  /// first; letting it win would erase exactly what is being protected.
  Future<void> write(AppleAuthorisationDetails details);

  /// Forgets a subject. Called when the account is deleted (US-015).
  Future<void> clear(String subjectId);
}

/// Restores what Apple disclosed the first time onto a later credential.
///
/// Returns [credential] unchanged for Google, which discloses the address on
/// every sign-in, and for a first Apple authorisation, which already has it.
Future<SocialCredential> withRememberedAppleDetails(
  SocialCredential credential,
  AppleAuthorisationStore store,
) async {
  if (credential.provider != SocialProvider.apple) return credential;

  // A first authorisation: record it before anything else can fail.
  if (credential.email != null || credential.displayName != null) {
    await store.write(AppleAuthorisationDetails(
      subjectId: credential.subjectId,
      email: credential.email,
      displayName: credential.displayName,
    ));
    return credential;
  }

  final remembered = await store.read(credential.subjectId);
  if (remembered == null || remembered.isEmpty) return credential;
  return credential.copyWith(
    email: remembered.email,
    displayName: remembered.displayName,
  );
}
