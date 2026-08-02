/// Every flag the app knows about, with the value it uses when no configuration
/// has been fetched yet.
///
/// **The default is what a brand-new install runs on**, before its first fetch
/// and if that fetch fails. Choosing it is a product decision, not a technical
/// one, so each is stated with its reasoning rather than defaulting to false.
///
/// A key the server sends that is not listed here is ignored. Treating an
/// unknown key as "off" would let a typo in the admin console silently disable a
/// feature that no client has ever heard of.
enum FeatureFlag {
  /// The €11 expert evaluation — ordering, payment and fulfilment.
  ///
  /// **This is the kill switch US-006 exists for.** Turning it off stops new
  /// orders without a store release, for the cases where taking money would be
  /// irresponsible: no astrologer available to meet the 72-hour SLA, a payment
  /// or fulfilment outage, or a pricing or VAT error.
  ///
  /// Defaults to **on**. A first-run user whose config fetch failed also has no
  /// network to complete a Stripe checkout, so defaulting off would prevent
  /// nothing real while making the product look broken on a flaky connection.
  /// Once any configuration has been fetched it is cached, so the switch
  /// survives later network loss — see `FlagRepository`.
  paidEvaluation('paid_evaluation', defaultValue: true),

  /// Career & Industry Fit.
  ///
  /// Off by default: the rule set needs expert sign-off (US-087) and the feature
  /// carries the AI Act and AGG exposure documented in `docs/adr/0005`. It
  /// should ship deliberately, not because a config fetch failed.
  careerAnalysis('career_analysis', defaultValue: false),

  /// Daily panchang notifications.
  dailyPanchang('daily_panchang', defaultValue: false),

  /// Shows the design system gallery entry in Profile.
  designGallery('design_gallery', defaultValue: true);

  const FeatureFlag(this.key, {required this.defaultValue});

  /// Wire identifier. Must match the `key` in the served document.
  final String key;

  /// Value used until configuration says otherwise.
  final bool defaultValue;

  static FeatureFlag? fromKey(String key) {
    for (final flag in FeatureFlag.values) {
      if (flag.key == key) return flag;
    }
    return null;
  }
}
