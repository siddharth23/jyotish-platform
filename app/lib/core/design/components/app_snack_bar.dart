import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// Severity of a transient message.
enum AppSnackTone { neutral, success, danger }

/// Brief confirmation of something that already happened.
///
/// Only for messages the user can afford to miss — it disappears on its own. If
/// they must act on it, use an [AppBanner] instead, which does not time out.
abstract final class AppSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    AppSnackTone tone = AppSnackTone.neutral,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final colors = context.colors;

    final (Color background, Color foreground, IconData? icon) = switch (tone) {
      AppSnackTone.neutral => (colors.onSurface, colors.surface, null),
      AppSnackTone.success => (
          colors.success,
          colors.onPrimary,
          Icons.check_circle_outline
        ),
      AppSnackTone.danger => (
          colors.error,
          colors.onError,
          Icons.error_outline
        ),
    };

    ScaffoldMessenger.of(context)
      // Queued snackbars pile up and outlive the screen that sent them.
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.radiusSm),
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.bodyMedium.copyWith(color: foreground),
                ),
              ),
            ],
          ),
          action: actionLabel == null || onAction == null
              ? null
              : SnackBarAction(
                  label: actionLabel,
                  textColor: foreground,
                  onPressed: onAction,
                ),
        ),
      );
  }
}
