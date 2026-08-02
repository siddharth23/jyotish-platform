import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

/// Carries the token set through the widget tree.
///
/// Components read `context.colors` rather than importing [AppColors.light] or
/// [AppColors.dark] directly. Reading the constants directly would compile and look
/// right in light mode, then silently paint light colours inside a dark screen —
/// exactly the bug a theme is supposed to make impossible.
@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({required this.colors});

  final AppColors colors;

  @override
  AppThemeExtension copyWith({AppColors? colors}) =>
      AppThemeExtension(colors: colors ?? this.colors);

  /// Token sets are discrete, so there is nothing meaningful to interpolate
  /// between. Snapping at the midpoint avoids inventing colours that were never
  /// contrast-checked.
  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return t < 0.5 ? this : other;
  }
}

/// Token access from a [BuildContext].
extension AppThemeContext on BuildContext {
  /// The active colour roles.
  ///
  /// Throws if no [AppThemeExtension] is installed, which means the widget is
  /// outside the app's theme. Falling back to a default would hide that.
  AppColors get colors {
    final extension = Theme.of(this).extension<AppThemeExtension>();
    assert(
      extension != null,
      'No AppThemeExtension found. Wrap this subtree in AppTheme.light or '
      'AppTheme.dark — see core/design/theme/app_theme.dart.',
    );
    return extension?.colors ??
        (Theme.of(this).brightness == Brightness.dark
            ? AppColors.dark
            : AppColors.light);
  }

  /// Whether the dark token set is active.
  bool get isDarkTheme => Theme.of(this).brightness == Brightness.dark;
}
