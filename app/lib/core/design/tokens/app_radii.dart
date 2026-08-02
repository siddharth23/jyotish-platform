import 'package:flutter/widgets.dart';

/// Corner radii.
abstract final class AppRadii {
  /// 0 — flush edges, full-bleed imagery.
  static const double none = 0;

  /// 4 — badges, small tags.
  static const double xs = 4;

  /// 8 — inputs, chips.
  static const double sm = 8;

  /// 12 — buttons, cards.
  static const double md = 12;

  /// 16 — larger cards, dialogs.
  static const double lg = 16;

  /// 24 — bottom sheets.
  static const double xl = 24;

  /// Fully round. Large enough to round any control this system defines.
  static const double pill = 999;

  static const BorderRadius radiusXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius radiusXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius radiusPill =
      BorderRadius.all(Radius.circular(pill));

  /// Sheets round only their top corners.
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
}
