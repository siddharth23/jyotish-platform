import 'package:flutter/material.dart';

import '../../l10n/generated/app_l10n.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// Visual weight of an [AppButton].
enum AppButtonVariant {
  /// The one action a screen most wants. At most one per view.
  primary,

  /// Supporting actions.
  secondary,

  /// Low emphasis — cancel, "not now".
  tertiary,

  /// Irreversible or costly. Deleting data, cancelling a paid order.
  destructive,
}

enum AppButtonSize { small, medium, large }

/// The system's button.
///
/// Handles three things screens should not have to re-solve: the 44pt minimum
/// target even at [AppButtonSize.small], a loading state that keeps its own width
/// so the layout does not jump mid-submit, and long German labels — the label
/// wraps to two lines rather than being ellipsised, because a truncated
/// `Auswertung kostenpflichtig bestellen` is worse than a taller button.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.semanticLabel,
    super.key,
  });

  final String label;

  /// Null disables the button. A loading button is also non-interactive.
  final VoidCallback? onPressed;

  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  /// Overrides what screen readers announce, when [label] alone lacks context.
  final String? semanticLabel;

  bool get _enabled => onPressed != null && !isLoading;

  double get _minHeight => switch (size) {
        // Never below the tap-target floor, whatever the visual size.
        AppButtonSize.small => AppSpacing.minTapTarget,
        AppButtonSize.medium => 48,
        AppButtonSize.large => 56,
      };

  EdgeInsets get _padding => switch (size) {
        AppButtonSize.small => const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        AppButtonSize.medium => const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        AppButtonSize.large => const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final (Color background, Color foreground, Color? border) =
        switch (variant) {
      AppButtonVariant.primary => (colors.primary, colors.onPrimary, null),
      AppButtonVariant.secondary => (
          colors.surfaceVariant,
          colors.onSurface,
          colors.outline,
        ),
      AppButtonVariant.tertiary => (
          const Color(0x00000000),
          colors.primary,
          null,
        ),
      AppButtonVariant.destructive => (colors.error, colors.onError, null),
    };

    // Disabled styling reduces opacity rather than swapping in a grey, so the
    // control still reads as the same button.
    final opacity = _enabled ? 1.0 : 0.38;

    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(foreground),
            ),
          )
        : Row(
            mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  // Two lines, not ellipsis: German labels are long and a
                  // half-shown verb changes what the button appears to do.
                  maxLines: 2,
                  style: AppTypography.label.copyWith(color: foreground),
                ),
              ),
            ],
          );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: semanticLabel ?? label,
      // The visual spinner is not announced; this is.
      hint: isLoading ? AppL10n.of(context).commonLoading : null,
      excludeSemantics: true,
      child: Opacity(
        opacity: opacity,
        child: Material(
          color: background,
          borderRadius: AppRadii.radiusMd,
          child: InkWell(
            onTap: _enabled ? onPressed : null,
            borderRadius: AppRadii.radiusMd,
            child: Container(
              constraints: BoxConstraints(
                minHeight: _minHeight,
                minWidth: AppSpacing.minTapTarget,
              ),
              width: isFullWidth ? double.infinity : null,
              padding: _padding,
              decoration: BoxDecoration(
                borderRadius: AppRadii.radiusMd,
                border: border == null ? null : Border.all(color: border),
              ),
              child: Center(
                widthFactor: isFullWidth ? null : 1,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
