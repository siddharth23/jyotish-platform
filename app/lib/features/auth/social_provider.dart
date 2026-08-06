/// Which social sign-in providers each platform offers (US-012 AC1, AC2).
///
/// ## The App Store rule this encodes
///
/// App Review Guideline 4.8: an app that offers any third-party or social login
/// must also offer Sign in with Apple on iOS. Breaking it is a rejection, and
/// `CLAUDE.md` already lists Apple review as a launch risk for this app.
///
/// The rule is written here as a function rather than left to whoever builds
/// the sign-in screen, because the way it gets broken is never a developer
/// deciding to break it. It is a feature flag turning Apple off during an
/// incident, or a provider list built by appending, and the result ships as a
/// screen offering Google alone on an iPhone.
///
/// So [providersFor] fails *closed*: on iOS, if Apple is unavailable for any
/// reason, no social provider is shown at all. Losing one-tap sign-in for the
/// length of an incident costs some conversions. Shipping a 4.8 violation costs
/// a release.
library;

/// The platform the app is running on, as far as sign-in is concerned.
///
/// A parameter rather than a read of `Platform.isIOS`, so the rules can be
/// tested for every platform on one machine. A rule that can only be exercised
/// by running the app on an iPhone is a rule that gets exercised in review.
enum SignInPlatform {
  ios,
  android,

  /// Anything else. The consoles are web and do not use this flow.
  other,
}

enum SocialProvider {
  apple,
  google;

  /// The identifier used in analytics and in the API's provider column.
  ///
  /// Deliberately not [name]: an enum rename is a refactor, and it must not
  /// silently repoint stored rows or break an event series.
  String get wireName => switch (this) {
        SocialProvider.apple => 'apple',
        SocialProvider.google => 'google',
      };
}

/// Decides which providers a sign-in screen may show.
abstract final class SocialSignInAvailability {
  /// The providers built into each platform's binary.
  ///
  /// Apple is not offered on Android. It is technically possible through a web
  /// flow, but it is not required there, and a browser hand-off is a worse
  /// experience than the native sheet Android users expect. Google is offered
  /// on both: an iOS user with a Google account should not be forced into an
  /// Apple ID.
  static Set<SocialProvider> supportedOn(SignInPlatform platform) =>
      switch (platform) {
        SignInPlatform.ios => const {SocialProvider.apple, SocialProvider.google},
        SignInPlatform.android => const {SocialProvider.google},
        SignInPlatform.other => const {},
      };

  /// The providers to show, in display order.
  ///
  /// [enabled] is the set still switched on — by feature flag, by a kill
  /// switch, or by an SDK that failed to initialise. Anything not supported on
  /// [platform] is dropped first, so a flag cannot conjure a provider the
  /// binary has no code for.
  ///
  /// On iOS the whole list collapses to empty when Apple is missing. See the
  /// library comment: that is the point of this function.
  static List<SocialProvider> providersFor(
    SignInPlatform platform, {
    Set<SocialProvider> enabled = const {
      SocialProvider.apple,
      SocialProvider.google,
    },
  }) {
    final supported = supportedOn(platform);
    final available = <SocialProvider>{
      for (final provider in enabled)
        if (supported.contains(provider)) provider,
    };

    if (platform == SignInPlatform.ios &&
        !available.contains(SocialProvider.apple)) {
      return const [];
    }

    // Order is not cosmetic. Apple's Human Interface Guidelines require Sign in
    // with Apple to appear no less prominently than other sign-in options, and
    // "below Google" is less prominent.
    return [
      for (final provider in _displayOrder)
        if (available.contains(provider)) provider,
    ];
  }

  static const List<SocialProvider> _displayOrder = [
    SocialProvider.apple,
    SocialProvider.google,
  ];

  /// Whether a set of offered providers satisfies Guideline 4.8 on [platform].
  ///
  /// Exposed so a test can assert it over every combination rather than over
  /// the handful a screen happens to produce. Offering nothing satisfies it —
  /// 4.8 is conditional on a third-party login being offered at all.
  static bool satisfiesGuideline48(
    SignInPlatform platform,
    Iterable<SocialProvider> offered,
  ) {
    if (platform != SignInPlatform.ios) return true;
    final providers = offered.toSet();
    if (providers.isEmpty) return true;
    return providers.contains(SocialProvider.apple);
  }
}
