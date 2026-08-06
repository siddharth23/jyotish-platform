import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish_app/features/auth/account_linking.dart';
import 'package:jyotish_app/features/auth/social_credential.dart';
import 'package:jyotish_app/features/auth/social_provider.dart';

SocialCredential credential({
  SocialProvider provider = SocialProvider.google,
  String? email = 'anna@example.de',
  bool verified = true,
}) =>
    SocialCredential(
      provider: provider,
      subjectId: 'subject-1',
      identityToken: 'token.for.tests',
      email: email,
      providerAssertsEmailVerified: verified,
    );

const passwordAccount = ExistingAccountMatch(
  method: ExistingSignInMethod.password,
  maskedEmail: 'a***a@example.de',
);

void main() {
  group('US-012 AC3 — linking on a matching address', () {
    test('links when the provider has verified the address', () {
      final decision = AccountLinkPolicy.decide(
        credential: credential(),
        match: passwordAccount,
      );

      expect(decision, isA<LinkToExistingAccount>());
      expect((decision as LinkToExistingAccount).match, passwordAccount);
    });

    test('creates a new account when nothing matches', () {
      final decision =
          AccountLinkPolicy.decide(credential: credential(), match: null);

      expect(decision, isA<CreateNewAccount>());
      expect((decision as CreateNewAccount).isPrivateRelay, isFalse);
    });

    test('refuses to link on an unverified address', () {
      // The takeover this rule exists for: claim the victim's address at a
      // provider that does not check, sign in, and receive their account —
      // their orders, their birth data, their paid reports.
      final decision = AccountLinkPolicy.decide(
        credential: credential(verified: false),
        match: passwordAccount,
      );

      expect(decision, isA<ProofOfControlRequired>());
    });

    test('the unverified case is refused for every provider', () {
      for (final provider in SocialProvider.values) {
        expect(
          AccountLinkPolicy.decide(
            credential: credential(provider: provider, verified: false),
            match: passwordAccount,
          ),
          isA<ProofOfControlRequired>(),
          reason: provider.wireName,
        );
      }
    });

    test('the rule is stated as a predicate as well', () {
      expect(AccountLinkPolicy.mayLinkAutomatically(credential()), isTrue);
      expect(
        AccountLinkPolicy.mayLinkAutomatically(credential(verified: false)),
        isFalse,
      );
    });

    test('an existing account is matched whatever its sign-in method', () {
      for (final method in ExistingSignInMethod.values) {
        final decision = AccountLinkPolicy.decide(
          credential: credential(),
          match: ExistingAccountMatch(
            method: method,
            maskedEmail: 'a***a@example.de',
          ),
        );
        expect(decision, isA<LinkToExistingAccount>(), reason: method.name);
      }
    });
  });

  group('US-012 AC4 — a relay address never matches', () {
    final relay = credential(
      provider: SocialProvider.apple,
      email: 'xyz@privaterelay.appleid.com',
    );

    test('linking could never apply to it', () {
      // Nothing else in the world uses that address, so offering to link would
      // be offering something that cannot happen.
      expect(AccountLinkPolicy.couldMatchAnExistingAccount(relay), isFalse);
    });

    test('a new account is created, and flagged as relay-only', () {
      final decision = AccountLinkPolicy.decide(credential: relay, match: null);

      expect(decision, isA<CreateNewAccount>());
      // Surfaced rather than left for the user to discover at checkout: this
      // account is separate from any they made with their real address, and
      // the report is delivered to a forwarding address they can switch off.
      expect((decision as CreateNewAccount).isPrivateRelay, isTrue);
    });

    test('a credential with no address could not match either', () {
      // A repeat Apple sign-in with nothing restored from the store.
      expect(
        AccountLinkPolicy.couldMatchAnExistingAccount(
          credential(provider: SocialProvider.apple, email: null),
        ),
        isFalse,
      );
    });

    test('a real address could match', () {
      expect(AccountLinkPolicy.couldMatchAnExistingAccount(credential()), isTrue);
    });
  });

  group('wire names', () {
    test('parse the methods the API sends', () {
      expect(
        ExistingSignInMethod.fromWireName('password'),
        ExistingSignInMethod.password,
      );
      expect(
        ExistingSignInMethod.fromWireName('apple'),
        ExistingSignInMethod.apple,
      );
      expect(
        ExistingSignInMethod.fromWireName('google'),
        ExistingSignInMethod.google,
      );
    });

    test('an unrecognised method is null, not a guess', () {
      // A method added by a later API version must not be silently read as one
      // this build already knows how to link.
      expect(ExistingSignInMethod.fromWireName('saml'), isNull);
      expect(ExistingSignInMethod.fromWireName(''), isNull);
    });

    test('a password account maps to no provider', () {
      expect(ExistingSignInMethod.password.provider, isNull);
      expect(ExistingSignInMethod.apple.provider, SocialProvider.apple);
    });
  });
}
