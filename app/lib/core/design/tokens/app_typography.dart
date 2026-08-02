import 'package:flutter/widgets.dart';

/// Type scale.
///
/// **Line heights are deliberately generous.** German runs roughly 30% longer than
/// English (`Geburtsdatum` for `birth date`, `Widerrufsbelehrung` for `withdrawal
/// notice`), so labels wrap where their English drafts did not. Tight leading turns
/// that wrapping into a cramped mess, and compound nouns cannot be hyphenated away.
///
/// Sizes are unscaled. Widgets must let `MediaQuery.textScaler` do its work rather
/// than hard-coding heights around these numbers, or large-text accessibility
/// settings clip the very labels that needed the room.
abstract final class AppTypography {
  static const String fontFamily = 'Roboto';

  /// 32/40 — one per screen at most.
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  /// 28/36 — screen titles.
  static const TextStyle displayMedium = TextStyle(
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
  );

  /// 22/28 — section headings.
  static const TextStyle titleLarge = TextStyle(
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w600,
  );

  /// 18/24 — card headings.
  static const TextStyle titleMedium = TextStyle(
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
  );

  /// 16/22 — list row titles, emphasised body.
  static const TextStyle titleSmall = TextStyle(
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w600,
  );

  /// 16/24 — default reading size.
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  );

  /// 14/20 — secondary copy.
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );

  /// 12/18 — captions, field hints, timestamps.
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w400,
  );

  /// 15/20 — button text. Slightly tighter than body so buttons stay compact.
  static const TextStyle label = TextStyle(
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  /// 13/16 — chips, badges, overline.
  static const TextStyle labelSmall = TextStyle(
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  /// 14/20 tabular — degrees, times, dasha dates.
  ///
  /// Tabular figures keep columns of numbers aligned; proportional digits make a
  /// chart's degree column visibly ragged.
  static const TextStyle numeric = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
