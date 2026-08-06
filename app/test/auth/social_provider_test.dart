import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish_app/features/auth/social_provider.dart';

/// Every subset of the providers, for exhaustive assertions.
Iterable<Set<SocialProvider>> allSubsets() sync* {
  yield const <SocialProvider>{};
  yield const {SocialProvider.apple};
  yield const {SocialProvider.google};
  yield const {SocialProvider.apple, SocialProvider.google};
}

void main() {
  group('US-012 AC1 — Sign in with Apple is mandatory on iOS', () {
    test('iOS offers Apple whenever it offers anything', () {
      // Asserted over every combination rather than the handful the screen
      // happens to produce. Guideline 4.8 is a rejection, and the way it breaks
      // is a flag turning Apple off, not a developer deciding to break it.
      for (final enabled in allSubsets()) {
        final offered = SocialSignInAvailability.providersFor(
          SignInPlatform.ios,
          enabled: enabled,
        );
        expect(
          SocialSignInAvailability.satisfiesGuideline48(
            SignInPlatform.ios,
            offered,
          ),
          isTrue,
          reason: 'enabled: $enabled produced $offered',
        );
      }
    });

    test('iOS shows nothing at all when Apple is unavailable', () {
      // Failing closed. Losing one-tap sign-in for an incident costs some
      // conversions; shipping Google alone on an iPhone costs a release.
      final offered = SocialSignInAvailability.providersFor(
        SignInPlatform.ios,
        enabled: const {SocialProvider.google},
      );
      expect(offered, isEmpty);
    });

    test('Apple comes before Google on iOS', () {
      // The HIG requires Sign in with Apple to be no less prominent than the
      // alternatives, and "below Google" is less prominent.
      final offered = SocialSignInAvailability.providersFor(SignInPlatform.ios);
      expect(offered, [SocialProvider.apple, SocialProvider.google]);
    });

    test('the guideline does not constrain other platforms', () {
      for (final platform in [SignInPlatform.android, SignInPlatform.other]) {
        expect(
          SocialSignInAvailability.satisfiesGuideline48(
            platform,
            const [SocialProvider.google],
          ),
          isTrue,
        );
      }
    });

    test('offering nothing satisfies the guideline', () {
      // 4.8 is conditional on a third-party login being offered at all.
      expect(
        SocialSignInAvailability.satisfiesGuideline48(
          SignInPlatform.ios,
          const <SocialProvider>[],
        ),
        isTrue,
      );
    });
  });

  group('US-012 AC2 — Google Sign-In on Android', () {
    test('Android offers Google', () {
      expect(
        SocialSignInAvailability.providersFor(SignInPlatform.android),
        [SocialProvider.google],
      );
    });

    test('Android does not offer Apple', () {
      // Possible through a web flow, not required there, and a browser hand-off
      // is worse than the sheet Android users expect.
      expect(
        SocialSignInAvailability.supportedOn(SignInPlatform.android),
        isNot(contains(SocialProvider.apple)),
      );
    });

    test('Android with Google disabled falls back to nothing', () {
      expect(
        SocialSignInAvailability.providersFor(
          SignInPlatform.android,
          enabled: const {},
        ),
        isEmpty,
      );
    });
  });

  group('A flag cannot conjure an unsupported provider', () {
    test('Apple enabled on Android is still not offered', () {
      expect(
        SocialSignInAvailability.providersFor(
          SignInPlatform.android,
          enabled: const {SocialProvider.apple, SocialProvider.google},
        ),
        [SocialProvider.google],
      );
    });

    test('nothing is offered on other platforms', () {
      expect(
        SocialSignInAvailability.providersFor(SignInPlatform.other),
        isEmpty,
      );
    });
  });

  group('wire names', () {
    test('are stable identifiers, not the enum name', () {
      // These reach analytics and the API's provider column. An enum rename is
      // a refactor and must not repoint stored rows.
      expect(SocialProvider.apple.wireName, 'apple');
      expect(SocialProvider.google.wireName, 'google');
    });
  });
}
