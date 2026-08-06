/// Linking a social sign-in to an existing account (US-012 AC3).
///
/// ## Why matching on email is dangerous
///
/// "An account already exists with this address, so sign them into it" is the
/// obvious reading of AC3 and, done directly, it is an account-takeover
/// primitive. The attack is short: create an account at a provider that lets
/// you claim an address without proving you own it, sign in here, and the
/// matching rule hands over the victim's account — their orders, their birth
/// data, their paid reports.
///
/// So the rule below turns on one thing: whether the provider *asserts* the
/// address has been verified by it. Google supplies `email_verified` and it is
/// not always true — a Workspace domain can carry unverified addresses. Apple's
/// are verified by construction.
///
/// **The claim must be read from the verified identity token on the server, not
/// from the field the SDK handed the client.** This file states the rule; the
/// API is the only place that can apply it safely. See `social_credential.dart`.
///
/// ## Why a relay address never matches
///
/// An Apple "Hide My Email" address is unique to this app and this user, so no
/// existing account can ever share it. A user who signed up with a password and
/// later signs in with Apple while hiding their email gets a *second* account,
/// with none of their orders in it. That is correct — we have no evidence the
/// two are the same person — but it is surprising, so it is surfaced rather
/// than left for them to discover on the checkout screen.
library;

import 'social_credential.dart';
import 'social_provider.dart';

/// How an existing account signs in today.
enum ExistingSignInMethod {
  password,
  apple,
  google;

  static ExistingSignInMethod? fromWireName(String value) => switch (value) {
        'password' => ExistingSignInMethod.password,
        'apple' => ExistingSignInMethod.apple,
        'google' => ExistingSignInMethod.google,
        _ => null,
      };
}

/// What the API found for the address in a verified identity token.
class ExistingAccountMatch {
  const ExistingAccountMatch({
    required this.method,
    required this.maskedEmail,
  });

  final ExistingSignInMethod method;

  /// The address with its local part obscured — `a***a@example.de`.
  ///
  /// Masked by the API, not here. Returning the full address would let anyone
  /// holding a provider account read back the address of any account they can
  /// provoke a match against, which is the enumeration problem US-011 spent its
  /// effort closing.
  final String maskedEmail;
}

/// What should happen for a social sign-in.
sealed class LinkDecision {
  const LinkDecision();
}

/// No existing account. Create one from the credential.
class CreateNewAccount extends LinkDecision {
  const CreateNewAccount({required this.isPrivateRelay});

  /// Whether the new account will be reachable only through Apple's forwarding.
  ///
  /// Worth telling the user: the €11 report is delivered by email, and a
  /// forwarding address they later switch off is an undeliverable order.
  final bool isPrivateRelay;
}

/// Attach the provider to the existing account without further proof.
///
/// Permitted only when the provider has verified the address. Signing in with
/// Apple to an account created with a password is then safe: Apple has
/// established that the person at the keyboard controls that mailbox, which is
/// the same evidence the password-reset flow relies on.
class LinkToExistingAccount extends LinkDecision {
  const LinkToExistingAccount({required this.match});

  final ExistingAccountMatch match;
}

/// An account exists, but the provider has not verified the address.
///
/// The user has to prove they control the existing account first — by signing
/// in with their password, or by clicking a verification link sent to it.
/// Never link on an unverified claim.
class ProofOfControlRequired extends LinkDecision {
  const ProofOfControlRequired({required this.match});

  final ExistingAccountMatch match;
}

/// The rule AC3 rests on.
///
/// Written as a pure function so it can be asserted over every combination, and
/// so client and API describe the same behaviour in the same words. **The API
/// is the authority**: it is the only side that has verified the identity token
/// the claims come from. This copy exists so the app can explain the outcome
/// and can refuse to draw a "link accounts" button the rule would not allow.
abstract final class AccountLinkPolicy {
  static LinkDecision decide({
    required SocialCredential credential,
    required ExistingAccountMatch? match,
  }) {
    if (match == null) {
      return CreateNewAccount(isPrivateRelay: credential.isApplePrivateRelay);
    }
    if (!credential.providerAssertsEmailVerified) {
      return ProofOfControlRequired(match: match);
    }
    return LinkToExistingAccount(match: match);
  }

  /// Whether a provider may be linked automatically on a verified address.
  ///
  /// Split out because it reads as a policy statement and because the negative
  /// case is the one worth being able to point at in review.
  static bool mayLinkAutomatically(SocialCredential credential) =>
      credential.providerAssertsEmailVerified;

  /// Whether linking could ever apply to this credential.
  ///
  /// False for a relay address: nothing else in the world uses it, so a match
  /// is impossible and offering to link would be offering something that cannot
  /// happen. Used to decide whether to warn the user before they choose to hide
  /// their address.
  static bool couldMatchAnExistingAccount(SocialCredential credential) =>
      !credential.isApplePrivateRelay && credential.email != null;
}

/// Providers, as the linking prompt names them.
extension ExistingSignInMethodLabelKey on ExistingSignInMethod {
  /// The provider this method corresponds to, or null for a password account.
  SocialProvider? get provider => switch (this) {
        ExistingSignInMethod.password => null,
        ExistingSignInMethod.apple => SocialProvider.apple,
        ExistingSignInMethod.google => SocialProvider.google,
      };
}
