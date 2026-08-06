import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish_app/features/auth/account_linking.dart';
import 'package:jyotish_app/features/auth/apple_authorisation_store.dart';
import 'package:jyotish_app/features/auth/auth_controller.dart';
import 'package:jyotish_app/features/auth/auth_gateway.dart';
import 'package:jyotish_app/features/auth/social_credential.dart';
import 'package:jyotish_app/features/auth/social_provider.dart';
import 'package:jyotish_app/features/auth/social_sign_in.dart';

SocialCredential appleCredential({String? email, bool verified = true}) =>
    SocialCredential(
      provider: SocialProvider.apple,
      subjectId: '001234.abcdef.0001',
      identityToken: 'token.for.tests',
      email: email,
      providerAssertsEmailVerified: verified,
    );

/// A gateway whose answers the test chooses.
class ScriptedGateway implements AuthGateway {
  ScriptedGateway({this.exchange, this.link});

  SocialExchangeResult Function(SocialCredential)? exchange;
  SocialExchangeResult Function(SocialCredential)? link;

  final List<SocialCredential> exchanged = [];
  final List<SocialCredential> linked = [];

  /// Completes the next exchange only when the test says so.
  Completer<void>? gate;

  @override
  Future<SocialExchangeResult> exchangeSocialCredential(
    SocialCredential credential,
  ) async {
    exchanged.add(credential);
    await gate?.future;
    return exchange?.call(credential) ??
        const SocialExchangeFailed(SocialExchangeFailureReason.unknown);
  }

  @override
  Future<SocialExchangeResult> confirmLink(SocialCredential credential) async {
    linked.add(credential);
    return link?.call(credential) ??
        const SocialExchangeFailed(SocialExchangeFailureReason.unknown);
  }
}

const signedIn = SocialExchangeSignedIn(
  accountId: 'account-1',
  isNewAccount: true,
  emailVerified: true,
);

({
  AuthController controller,
  FakeSocialSignIn signIn,
  ScriptedGateway gateway,
  InMemoryAppleAuthorisationStore store
}) harness({
  SocialAuthorisation? appleResponse,
  SocialExchangeResult Function(SocialCredential)? exchange,
  SocialExchangeResult Function(SocialCredential)? link,
}) {
  final signIn = FakeSocialSignIn();
  if (appleResponse != null) {
    signIn.respondWith(SocialProvider.apple, appleResponse);
  }
  final gateway = ScriptedGateway(exchange: exchange, link: link);
  final store = InMemoryAppleAuthorisationStore();
  return (
    controller: AuthController(
      signIn: signIn,
      gateway: gateway,
      appleStore: store,
    ),
    signIn: signIn,
    gateway: gateway,
    store: store,
  );
}

void main() {
  group('signing in', () {
    test('a granted authorisation that exchanges cleanly signs the user in',
        () async {
      final h = harness(
        appleResponse: SocialAuthorisationGranted(
          appleCredential(email: 'anna@example.de'),
        ),
        exchange: (_) => signedIn,
      );

      await h.controller.signInWith(SocialProvider.apple);

      final state = h.controller.state;
      expect(state, isA<AuthSignedIn>());
      expect((state as AuthSignedIn).accountId, 'account-1');
      expect(state.emailVerified, isTrue);
      expect(state.usedPrivateRelay, isFalse);
    });

    test('cancelling returns to idle without an error', () async {
      // Dismissing the sheet is the most common thing that happens to it. An
      // error banner for it makes the app look broken.
      final h = harness(appleResponse: const SocialAuthorisationCancelled());

      await h.controller.signInWith(SocialProvider.apple);

      expect(h.controller.state, isA<AuthIdle>());
      expect(h.gateway.exchanged, isEmpty);
    });

    test('a provider failure surfaces as a matching reason', () async {
      final h = harness(
        appleResponse: const SocialAuthorisationFailed(
          SocialAuthorisationFailureReason.network,
        ),
      );

      await h.controller.signInWith(SocialProvider.apple);

      expect(h.controller.state, isA<AuthFailure>());
      expect(
        (h.controller.state as AuthFailure).reason,
        AuthFailureReason.network,
      );
    });

    test('a second tap while a sheet is open is ignored', () async {
      // Two taps open two sheets on Android and one on iOS, so the platforms
      // disagree about what just happened.
      final h = harness(
        appleResponse: SocialAuthorisationGranted(appleCredential()),
        exchange: (_) => signedIn,
      );
      h.gateway.gate = Completer<void>();

      final first = h.controller.signInWith(SocialProvider.apple);
      await h.controller.signInWith(SocialProvider.apple);
      expect(h.signIn.authorisations, [SocialProvider.apple]);

      h.gateway.gate!.complete();
      await first;
      expect(h.controller.state, isA<AuthSignedIn>());
    });

    test('the failure can be dismissed back to the buttons', () async {
      final h = harness(
        appleResponse: const SocialAuthorisationFailed(
          SocialAuthorisationFailureReason.unknown,
        ),
      );
      await h.controller.signInWith(SocialProvider.apple);

      h.controller.dismissFailure();
      expect(h.controller.state, isA<AuthIdle>());
    });

    test('the unconfigured adapter fails rather than pretending', () async {
      final controller = AuthController(
        signIn: const UnconfiguredSocialSignIn(),
        gateway: const UnavailableAuthGateway(),
        appleStore: InMemoryAppleAuthorisationStore(),
      );

      await controller.signInWith(SocialProvider.google);

      expect(
        (controller.state as AuthFailure).reason,
        AuthFailureReason.providerUnavailable,
      );
    });
  });

  group('US-012 AC4 — the address Apple disclosed once', () {
    test('is stored before the exchange is attempted', () async {
      final h = harness(
        appleResponse: SocialAuthorisationGranted(
          appleCredential(email: 'anna@example.de'),
        ),
        exchange: (_) =>
            const SocialExchangeFailed(SocialExchangeFailureReason.network),
      );

      await h.controller.signInWith(SocialProvider.apple);

      // The exchange failed, and the address survived it.
      expect(h.controller.state, isA<AuthFailure>());
      expect(
        (await h.store.read('001234.abcdef.0001'))?.email,
        'anna@example.de',
      );
    });

    test('is restored onto a later authorisation that carries none', () async {
      final h = harness(exchange: (_) => signedIn);
      h.signIn.respondWith(
        SocialProvider.apple,
        SocialAuthorisationGranted(appleCredential(email: 'anna@example.de')),
      );
      await h.controller.signInWith(SocialProvider.apple);

      h.signIn.respondWith(
        SocialProvider.apple,
        SocialAuthorisationGranted(appleCredential()),
      );
      await h.controller.signInWith(SocialProvider.apple);

      expect(h.gateway.exchanged.last.email, 'anna@example.de');
    });

    test('a relay sign-in is flagged so the user can be told', () async {
      final h = harness(
        appleResponse: SocialAuthorisationGranted(
          appleCredential(email: 'xyz@privaterelay.appleid.com'),
        ),
        exchange: (_) => signedIn,
      );

      await h.controller.signInWith(SocialProvider.apple);

      expect((h.controller.state as AuthSignedIn).usedPrivateRelay, isTrue);
    });
  });

  group('US-012 AC3 — linking', () {
    const match = ExistingAccountMatch(
      method: ExistingSignInMethod.password,
      maskedEmail: 'a***a@example.de',
    );

    test('a link decision parks the flow and holds the credential', () async {
      final h = harness(
        appleResponse: SocialAuthorisationGranted(
          appleCredential(email: 'anna@example.de'),
        ),
        exchange: (_) => const SocialExchangeNeedsLinking(
          decision: LinkToExistingAccount(match: match),
        ),
      );

      await h.controller.signInWith(SocialProvider.apple);

      final state = h.controller.state;
      expect(state, isA<AuthAwaitingLinkDecision>());
      // Held so confirming does not require authorising a second time.
      expect((state as AuthAwaitingLinkDecision).credential.email,
          'anna@example.de');
    });

    test('confirming completes the link', () async {
      final h = harness(
        appleResponse: SocialAuthorisationGranted(appleCredential()),
        exchange: (_) => const SocialExchangeNeedsLinking(
          decision: LinkToExistingAccount(match: match),
        ),
        link: (_) => signedIn,
      );
      await h.controller.signInWith(SocialProvider.apple);

      await h.controller.confirmLink();

      expect(h.gateway.linked, hasLength(1));
      expect(h.controller.state, isA<AuthSignedIn>());
    });

    test('confirming a proof-of-control decision does nothing', () async {
      // The one control that must never work. Approving here would be linking
      // on an address the provider never verified.
      final h = harness(
        appleResponse: SocialAuthorisationGranted(appleCredential()),
        exchange: (_) => const SocialExchangeNeedsLinking(
          decision: ProofOfControlRequired(match: match),
        ),
        link: (_) => signedIn,
      );
      await h.controller.signInWith(SocialProvider.apple);

      await h.controller.confirmLink();

      expect(h.gateway.linked, isEmpty);
      expect(h.controller.state, isA<AuthAwaitingLinkDecision>());
    });

    test('confirming outside a link prompt does nothing', () async {
      final h = harness();
      await h.controller.confirmLink();
      expect(h.gateway.linked, isEmpty);
    });

    test('dismissing returns to the buttons', () async {
      final h = harness(
        appleResponse: SocialAuthorisationGranted(appleCredential()),
        exchange: (_) => const SocialExchangeNeedsLinking(
          decision: LinkToExistingAccount(match: match),
        ),
      );
      await h.controller.signInWith(SocialProvider.apple);

      h.controller.dismissLinkPrompt();
      expect(h.controller.state, isA<AuthIdle>());
    });
  });

  group('signing out', () {
    test('clears the provider session too', () async {
      // Google re-authorises the last account silently. Without this, "sign out
      // and sign in as someone else" returns the person who just left.
      final h = harness(
        appleResponse: SocialAuthorisationGranted(appleCredential()),
        exchange: (_) => signedIn,
      );
      await h.controller.signInWith(SocialProvider.apple);

      await h.controller.signOut();

      expect(h.signIn.signOutCount, 1);
      expect(h.controller.state, isA<AuthIdle>());
    });
  });

  group('exchange failures map onto reasons the screen can explain', () {
    test('each API failure has its own reason', () async {
      const expected = {
        SocialExchangeFailureReason.network: AuthFailureReason.network,
        SocialExchangeFailureReason.tokenRejected:
            AuthFailureReason.tokenRejected,
        SocialExchangeFailureReason.notImplemented:
            AuthFailureReason.notImplemented,
        SocialExchangeFailureReason.unknown: AuthFailureReason.unknown,
      };

      for (final entry in expected.entries) {
        final h = harness(
          appleResponse: SocialAuthorisationGranted(appleCredential()),
          exchange: (_) => SocialExchangeFailed(entry.key),
        );
        await h.controller.signInWith(SocialProvider.apple);

        expect(
          (h.controller.state as AuthFailure).reason,
          entry.value,
          reason: entry.key.name,
        );
      }
    });
  });
}
