import 'package:flutter/widgets.dart';

/// Semantic colour roles.
///
/// Screens reference roles, never raw hex. A role says what a colour is *for*
/// (`onSurfaceVariant` — secondary text on a raised surface), not what it looks
/// like, so the same widget code works in both themes.
///
/// **Every foreground/background pairing here is verified at 4.5:1 or better by
/// `test/design/contrast_test.dart`**, which recomputes WCAG relative luminance
/// rather than trusting these values. Non-text UI boundaries (`outline`) are held
/// to the 3:1 that WCAG 1.4.11 requires. Changing any value re-runs that check.
@immutable
class AppColors {
  const AppColors({
    required this.background,
    required this.onBackground,
    required this.surface,
    required this.onSurface,
    required this.surfaceVariant,
    required this.onSurfaceVariant,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.accent,
    required this.onAccent,
    required this.accentContainer,
    required this.onAccentContainer,
    required this.success,
    required this.warning,
    required this.error,
    required this.onError,
    required this.outline,
    required this.overlay,
  });

  /// The colour behind everything.
  final Color background;
  final Color onBackground;

  /// Cards, sheets and anything lifted off the background.
  final Color surface;
  final Color onSurface;

  /// A quieter surface for grouping — input fills, list backgrounds.
  final Color surfaceVariant;

  /// Secondary text and icons. Still meets 4.5:1; it is quieter, not weaker.
  final Color onSurfaceVariant;

  /// Brand indigo. Primary actions and selected states.
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;

  /// Saffron. Reserved for the paid product and moments that should feel
  /// distinct from ordinary primary actions. Used sparingly or it stops meaning
  /// anything.
  final Color accent;
  final Color onAccent;
  final Color accentContainer;
  final Color onAccentContainer;

  final Color success;
  final Color warning;
  final Color error;
  final Color onError;

  /// Borders and dividers. Non-text, so held to 3:1.
  final Color outline;

  /// Scrim behind modals.
  final Color overlay;

  /// Light theme.
  static const AppColors light = AppColors(
    background: Color(0xFFFFFFFF),
    onBackground: Color(0xFF16181D),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF16181D),
    surfaceVariant: Color(0xFFF2F3F7),
    onSurfaceVariant: Color(0xFF4A4F5C),
    primary: Color(0xFF2E3A8C),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE3E7FF),
    onPrimaryContainer: Color(0xFF131A44),
    accent: Color(0xFF8A4B08),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFFDF0DC),
    onAccentContainer: Color(0xFF5C3206),
    success: Color(0xFF1B6B3A),
    warning: Color(0xFF8A5A00),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    outline: Color(0xFF6B7280),
    overlay: Color(0x99000000),
  );

  /// Dark theme.
  ///
  /// Not an inversion of [light]. Saturated brand colours vibrate against dark
  /// backgrounds, so primary and accent are lightened and their foregrounds
  /// darkened, which is why both directions are contrast-tested.
  static const AppColors dark = AppColors(
    background: Color(0xFF0E1014),
    onBackground: Color(0xFFE9EBF2),
    surface: Color(0xFF14171D),
    onSurface: Color(0xFFE9EBF2),
    surfaceVariant: Color(0xFF1E222B),
    onSurfaceVariant: Color(0xFFAAB1C0),
    primary: Color(0xFFAFBAFF),
    onPrimary: Color(0xFF131A44),
    primaryContainer: Color(0xFF293573),
    onPrimaryContainer: Color(0xFFDDE2FF),
    accent: Color(0xFFF0B429),
    onAccent: Color(0xFF2A1B02),
    accentContainer: Color(0xFF5C3206),
    onAccentContainer: Color(0xFFFBE3B8),
    success: Color(0xFF6FD99A),
    warning: Color(0xFFF0B429),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    outline: Color(0xFF8A92A3),
    overlay: Color(0xB3000000),
  );
}
