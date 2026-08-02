import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// Semantic tone of a badge.
enum AppBadgeTone { neutral, info, success, warning, danger, accent }

/// A small status label.
///
/// Used for order state — `BEZAHLT`, `IN BEARBEITUNG`, `GELIEFERT`. The tone sets
/// the colour, but the text always states the status, so tone is reinforcement and
/// never the only carrier of meaning.
class AppBadge extends StatelessWidget {
  const AppBadge({
    required this.label,
    this.tone = AppBadgeTone.neutral,
    this.icon,
    super.key,
  });

  final String label;
  final AppBadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final (Color background, Color foreground) = switch (tone) {
      AppBadgeTone.neutral => (colors.surfaceVariant, colors.onSurfaceVariant),
      AppBadgeTone.info => (colors.primaryContainer, colors.onPrimaryContainer),
      AppBadgeTone.success => (
          colors.success.withValues(alpha: 0.16),
          colors.success,
        ),
      AppBadgeTone.warning => (
          colors.warning.withValues(alpha: 0.16),
          colors.warning,
        ),
      AppBadgeTone.danger => (
          colors.error.withValues(alpha: 0.16),
          colors.error
        ),
      AppBadgeTone.accent => (colors.accentContainer, colors.onAccentContainer),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.radiusXs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
