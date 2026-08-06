/// The port to the API's identity module (US-012 AC3).
///
/// The app sends the credential; the API verifies the identity token against
/// the provider's public keys, reads the address and the `email_verified` claim
/// out of it, and decides. **No decision in this flow may be made from a field
/// the client filled in** — see `social_credential.dart`.
///
/// Unimplemented, because the API has no HTTP layer yet: `api/src/main.ts` is a
/// stub. `UnavailableAuthGateway` is what ships.
library;

import 'account_linking.dart';
import 'social_credential.dart';

/// The outcome of exchanging a credential with the API.
sealed class SocialExchangeResult {
  const SocialExchangeResult();
}

/// Signed in. [isNewAccount] distinguishes a registration from a return.
class SocialExchangeSignedIn extends SocialExchangeResult {
  const SocialExchangeSignedIn({
    required this.accountId,
    required this.isNewAccount,
    required this.emailVerified,
  });

  final String accountId;
  final bool isNewAccount;

  /// Whether the address on the account has been proven.
  ///
  /// Ordering a report requires it. A social sign-in usually supplies it
  /// already — the provider verified the mailbox — which is most of the value
  /// of this story to the paid flow.
  final bool emailVerified;
}

/// An account exists for this address and the API wants a decision first.
class SocialExchangeNeedsLinking extends SocialExchangeResult {
  const SocialExchangeNeedsLinking({required this.decision});

  /// Either [LinkToExistingAccount] — offer to link — or
  /// [ProofOfControlRequired] — send them to sign in the existing way first.
  final LinkDecision decision;
}

class SocialExchangeFailed extends SocialExchangeResult {
  const SocialExchangeFailed(this.reason);

  final SocialExchangeFailureReason reason;
}

enum SocialExchangeFailureReason {
  /// The provider's token did not verify. Either an expired token — retryable
  /// by authorising again — or something forged.
  tokenRejected,
  network,

  /// No endpoint. The state this ships in.
  notImplemented,
  unknown,
}

abstract interface class AuthGateway {
  Future<SocialExchangeResult> exchangeSocialCredential(
    SocialCredential credential,
  );

  /// Completes a link the user has approved.
  ///
  /// Separate from the exchange because approving a link is a decision the user
  /// makes on a screen, not something a sign-in tap can imply.
  Future<SocialExchangeResult> confirmLink(SocialCredential credential);
}

/// The gateway until the API exists.
///
/// Returns [SocialExchangeFailureReason.notImplemented] rather than throwing,
/// so the UI renders its ordinary error state instead of a crash — and so
/// nothing in this flow can be mistaken for working.
class UnavailableAuthGateway implements AuthGateway {
  const UnavailableAuthGateway();

  @override
  Future<SocialExchangeResult> exchangeSocialCredential(
    SocialCredential credential,
  ) async =>
      const SocialExchangeFailed(SocialExchangeFailureReason.notImplemented);

  @override
  Future<SocialExchangeResult> confirmLink(SocialCredential credential) async =>
      const SocialExchangeFailed(SocialExchangeFailureReason.notImplemented);
}
