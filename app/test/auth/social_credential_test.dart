import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish_app/features/auth/apple_authorisation_store.dart';
import 'package:jyotish_app/features/auth/social_credential.dart';
import 'package:jyotish_app/features/auth/social_provider.dart';

/// Synthetic throughout. CLAUDE.md forbids real personal data in fixtures.
SocialCredential apple({
  String subjectId = '001234.abcdef.0001',
  String? email,
  String? displayName,
  bool verified = true,
}) =>
    SocialCredential(
      provider: SocialProvider.apple,
      subjectId: subjectId,
      identityToken: 'token.for.tests',
      email: email,
      displayName: displayName,
      providerAssertsEmailVerified: verified,
    );

SocialCredential google({String? email = 'anna@example.de', bool verified = true}) =>
    SocialCredential(
      provider: SocialProvider.google,
      subjectId: 'google-sub-1',
      identityToken: 'token.for.tests',
      email: email,
      providerAssertsEmailVerified: verified,
    );

void main() {
  group('US-012 AC4 — recognising a private relay address', () {
    test('matches the relay domain', () {
      expect(
        apple(email: 'abc123@privaterelay.appleid.com').isApplePrivateRelay,
        isTrue,
      );
    });

    test('is case-insensitive', () {
      expect(
        apple(email: 'ABC@PrivateRelay.AppleID.com').isApplePrivateRelay,
        isTrue,
      );
    });

    test('does not match a look-alike domain an attacker could register', () {
      // A `contains` check would match all of these.
      for (final address in [
        'a@privaterelay.appleid.com.example.de',
        'a@notprivaterelay.appleid.com.de',
        'privaterelay.appleid.com@example.de',
      ]) {
        expect(
          SocialCredential.isPrivateRelayAddress(address),
          isFalse,
          reason: address,
        );
      }
    });

    test('a real address is not a relay address', () {
      expect(apple(email: 'anna@icloud.com').isApplePrivateRelay, isFalse);
      expect(google().isApplePrivateRelay, isFalse);
    });

    test('an absent address is not a relay address', () {
      expect(apple().isApplePrivateRelay, isFalse);
      expect(SocialCredential.isPrivateRelayAddress(null), isFalse);
    });
  });

  group('US-012 AC4 — Apple discloses the address only once', () {
    test('a first authorisation is stored before anything else can fail', () async {
      final store = InMemoryAppleAuthorisationStore();
      final first = apple(email: 'anna@example.de', displayName: 'Anna B.');

      await withRememberedAppleDetails(first, store);

      final stored = await store.read(first.subjectId);
      expect(stored?.email, 'anna@example.de');
      expect(stored?.displayName, 'Anna B.');
    });

    test('a later authorisation gets the address back', () async {
      // Apple returns the identifier and nothing else from the second sign-in
      // on. Without this the app has an account it cannot deliver a report to.
      final store = InMemoryAppleAuthorisationStore();
      await withRememberedAppleDetails(
        apple(email: 'anna@example.de', displayName: 'Anna B.'),
        store,
      );

      final second = await withRememberedAppleDetails(apple(), store);
      expect(second.email, 'anna@example.de');
      expect(second.displayName, 'Anna B.');
    });

    test('a failed exchange does not take the address with it', () async {
      // The exact sequence that loses it: Apple returns the address, the
      // request times out, the user taps again, and the second authorisation
      // carries nothing.
      final store = InMemoryAppleAuthorisationStore();
      await withRememberedAppleDetails(apple(email: 'anna@example.de'), store);
      // ... network failure, nothing sent ...
      final retry = await withRememberedAppleDetails(apple(), store);
      expect(retry.email, 'anna@example.de');
    });

    test('an empty second authorisation never erases a stored value', () async {
      final store = InMemoryAppleAuthorisationStore();
      await store.write(const AppleAuthorisationDetails(
        subjectId: '001234.abcdef.0001',
        email: 'anna@example.de',
        displayName: 'Anna B.',
      ));
      // Apple hands the name back in pieces, so "a name but no address" is a
      // real case rather than a hypothetical.
      await store.write(const AppleAuthorisationDetails(
        subjectId: '001234.abcdef.0001',
        displayName: 'Anna Beispiel',
      ));

      final stored = await store.read('001234.abcdef.0001');
      expect(stored?.email, 'anna@example.de');
      expect(stored?.displayName, 'Anna Beispiel');
    });

    test('one device can hold two Apple IDs without them mixing', () async {
      final store = InMemoryAppleAuthorisationStore();
      await withRememberedAppleDetails(
        apple(subjectId: 'subject-a', email: 'a@example.de'),
        store,
      );
      final other =
          await withRememberedAppleDetails(apple(subjectId: 'subject-b'), store);
      expect(other.email, isNull);
    });

    test('Google is left alone — it discloses the address every time', () async {
      final store = InMemoryAppleAuthorisationStore();
      final result = await withRememberedAppleDetails(google(), store);

      expect(result.email, 'anna@example.de');
      expect(await store.read('google-sub-1'), isNull);
    });

    test('clearing forgets a subject, for account deletion', () async {
      final store = InMemoryAppleAuthorisationStore();
      await withRememberedAppleDetails(apple(email: 'anna@example.de'), store);
      await store.clear('001234.abcdef.0001');

      expect(await store.read('001234.abcdef.0001'), isNull);
    });

    test('a relay address is remembered like any other', () async {
      final store = InMemoryAppleAuthorisationStore();
      await withRememberedAppleDetails(
        apple(email: 'xyz@privaterelay.appleid.com'),
        store,
      );
      final second = await withRememberedAppleDetails(apple(), store);
      expect(second.isApplePrivateRelay, isTrue);
    });
  });

  group('the credential does not leak into logs', () {
    test('toString carries neither the address nor the token', () {
      final rendered = apple(email: 'anna@example.de').toString();

      expect(rendered, isNot(contains('anna@example.de')));
      expect(rendered, isNot(contains('token.for.tests')));
      // Enough to correlate two lines, not enough to identify anyone.
      expect(rendered, contains('apple'));
      expect(rendered, contains('present'));
    });

    test('an absent address is reported as absent, not as null', () {
      expect(apple().toString(), contains('absent'));
    });

    test('a short subject is masked entirely', () {
      expect(apple(subjectId: 'abc').toString(), contains('***'));
    });
  });
}
