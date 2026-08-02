import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import 'app_theme_extension.dart';

/// Builds [ThemeData] from the tokens.
///
/// Material's own widgets are themed here too, not just this system's components:
/// a stray `TextField` or `AlertDialog` from the framework should still look like
/// the rest of the app rather than announcing itself as unstyled.
abstract final class AppTheme {
  static ThemeData get light => _build(AppColors.light, Brightness.light);
  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors colors, Brightness brightness) {
    final textTheme = _textTheme(colors);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.surface,
      fontFamily: AppTypography.fontFamily,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.primary,
        onPrimary: colors.onPrimary,
        primaryContainer: colors.primaryContainer,
        onPrimaryContainer: colors.onPrimaryContainer,
        secondary: colors.accent,
        onSecondary: colors.onAccent,
        secondaryContainer: colors.accentContainer,
        onSecondaryContainer: colors.onAccentContainer,
        error: colors.error,
        onError: colors.onError,
        surface: colors.surface,
        onSurface: colors.onSurface,
        surfaceContainerHighest: colors.surfaceVariant,
        onSurfaceVariant: colors.onSurfaceVariant,
        outline: colors.outline,
      ),
      textTheme: textTheme,
      extensions: [AppThemeExtension(colors: colors)],
      dividerTheme: DividerThemeData(
        color: colors.outline.withValues(alpha: 0.35),
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.onBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.titleMedium.copyWith(
          color: colors.onBackground,
        ),
      ),
      // Every framework control that can be tapped gets the same floor as this
      // system's own components.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkSparkle.splashFactory,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadii.radiusSm,
          borderSide: BorderSide(color: colors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.radiusSm,
          borderSide: BorderSide(color: colors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.radiusSm,
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.radiusSm,
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.radiusSm,
          borderSide: BorderSide(color: colors.error, width: 2),
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.radiusLg),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.onSurface,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: colors.surface,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.radiusSm),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static TextTheme _textTheme(AppColors colors) {
    final onSurface = colors.onSurface;
    final muted = colors.onSurfaceVariant;
    return TextTheme(
      displayLarge: AppTypography.displayLarge.copyWith(color: onSurface),
      displayMedium: AppTypography.displayMedium.copyWith(color: onSurface),
      titleLarge: AppTypography.titleLarge.copyWith(color: onSurface),
      titleMedium: AppTypography.titleMedium.copyWith(color: onSurface),
      titleSmall: AppTypography.titleSmall.copyWith(color: onSurface),
      bodyLarge: AppTypography.bodyLarge.copyWith(color: onSurface),
      bodyMedium: AppTypography.bodyMedium.copyWith(color: onSurface),
      bodySmall: AppTypography.bodySmall.copyWith(color: muted),
      labelLarge: AppTypography.label.copyWith(color: onSurface),
      labelSmall: AppTypography.labelSmall.copyWith(color: muted),
    );
  }
}
