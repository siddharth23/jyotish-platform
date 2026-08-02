/// Spacing scale, in logical pixels.
///
/// A 4pt base with a roughly geometric progression. Every margin, padding and gap
/// comes from here — arbitrary values make rhythm drift screen by screen, which is
/// the thing a spacing scale exists to prevent.
abstract final class AppSpacing {
  /// 2 — hairline separation, icon to its own label.
  static const double xxs = 2;

  /// 4 — tight grouping inside a control.
  static const double xs = 4;

  /// 8 — related elements.
  static const double sm = 8;

  /// 12 — inner padding of compact controls.
  static const double md = 12;

  /// 16 — the default. Screen gutters and card padding.
  static const double lg = 16;

  /// 24 — between distinct groups.
  static const double xl = 24;

  /// 32 — between sections.
  static const double xxl = 32;

  /// 48 — major breaks, empty-state breathing room.
  static const double xxxl = 48;

  /// Minimum interactive dimension, in logical pixels.
  ///
  /// 44 is the stricter of the two platform guidelines (Apple 44pt, Android 48dp)
  /// and the figure US-004 names. Every interactive component is asserted against
  /// it by `test/design/tap_target_test.dart`, including when its visible artwork
  /// is smaller — a 20pt checkbox still has to occupy 44pt of touchable space.
  static const double minTapTarget = 44;
}
