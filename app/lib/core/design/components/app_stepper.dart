import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// Progress through a multi-step flow.
///
/// Birth-data capture runs to several screens, and a user part-way through needs
/// to know how much is left before abandoning it. The bar is decorative; the
/// position is announced as text, since a row of dots means nothing spoken aloud.
class AppStepper extends StatelessWidget {
  const AppStepper({
    required this.currentStep,
    required this.totalSteps,
    this.stepLabel,
    super.key,
  });

  /// 1-based.
  final int currentStep;
  final int totalSteps;

  /// Name of the current step, announced after the position.
  final String? stepLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final position = 'Schritt $currentStep von $totalSteps';

    return Semantics(
      label: stepLabel == null ? position : '$position, $stepLabel',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 1; i <= totalSteps; i++) ...[
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= currentStep
                          ? colors.primary
                          : colors.surfaceVariant,
                      borderRadius: AppRadii.radiusPill,
                    ),
                  ),
                ),
                if (i < totalSteps) const SizedBox(width: AppSpacing.xs),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            stepLabel == null ? position : '$position — $stepLabel',
            style: AppTypography.bodySmall
                .copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
