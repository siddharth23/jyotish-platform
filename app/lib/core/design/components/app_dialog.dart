import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import 'app_button.dart';

/// A blocking confirmation.
///
/// Reserved for decisions that cannot be undone. The confirm action takes the
/// destructive variant when [isDestructive] is set, and cancel is always present —
/// a modal with one way out is a dead end.
class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    this.isDestructive = false,
    super.key,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;

  /// Resolves true when confirmed, false when cancelled or dismissed.
  static Future<bool> confirm({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    required String cancelLabel,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AppDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Dialog(
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.radiusLg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style:
                  AppTypography.titleMedium.copyWith(color: colors.onSurface),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTypography.bodyMedium
                  .copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xl),
            // Stacked rather than side by side: two long German labels do not
            // fit across a phone, and a wrapped row of buttons looks broken.
            AppButton(
              label: confirmLabel,
              isFullWidth: true,
              variant: isDestructive
                  ? AppButtonVariant.destructive
                  : AppButtonVariant.primary,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: cancelLabel,
              isFullWidth: true,
              variant: AppButtonVariant.tertiary,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
