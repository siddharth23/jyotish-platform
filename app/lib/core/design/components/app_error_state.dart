import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import 'app_button.dart';

/// Shown when something failed.
///
/// Distinct from an empty state: empty is expected, this is not. The retry action
/// is prominent because a transient network failure is the common case.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    required this.title,
    required this.message,
    this.retryLabel,
    this.onRetry,
    super.key,
  });

  final String title;
  final String message;
  final String? retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colors.error),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style:
                    AppTypography.titleMedium.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium
                    .copyWith(color: colors.onSurfaceVariant),
              ),
              if (retryLabel != null && onRetry != null) ...[
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: retryLabel!,
                  onPressed: onRetry,
                  variant: AppButtonVariant.secondary,
                  icon: Icons.refresh,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
