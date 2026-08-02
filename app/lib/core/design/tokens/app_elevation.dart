import 'package:flutter/widgets.dart';

/// Elevation levels, expressed as shadows rather than a bare Material `elevation`
/// number so the same steps read correctly in both themes.
///
/// Shadows barely register on a dark background; depth there comes mostly from the
/// lighter surface colour. The shadows below are therefore tuned for light and kept
/// subtle, and [forBrightness] drops them entirely in dark, where a black blur on a
/// near-black background is wasted rasterisation.
abstract final class AppElevation {
  /// Flush with its parent.
  static const List<BoxShadow> level0 = <BoxShadow>[];

  /// Resting cards.
  static const List<BoxShadow> level1 = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  /// Raised — pressed cards, sticky headers.
  static const List<BoxShadow> level2 = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 12,
      offset: Offset(0, 6),
    ),
  ];

  /// Floating — menus, snackbars.
  static const List<BoxShadow> level3 = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 24,
      offset: Offset(0, 12),
    ),
  ];

  /// Modal — dialogs, bottom sheets.
  static const List<BoxShadow> level4 = [
    BoxShadow(
      color: Color(0x29000000),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 40,
      offset: Offset(0, 20),
    ),
  ];

  /// The shadow to actually paint for [brightness].
  ///
  /// Dark themes get none: the surface colour carries the depth, and a black blur
  /// over a near-black background costs a raster pass to render nothing visible.
  static List<BoxShadow> forBrightness(
    Brightness brightness,
    List<BoxShadow> shadow,
  ) =>
      brightness == Brightness.dark ? level0 : shadow;
}
