import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/app_motion.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// One segment of an [AppSegmentedControl].
@immutable
class AppSegment<T> {
  const AppSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// A small set of mutually exclusive views.
///
/// For switching chart style — North Indian, South Indian, Western — where the
/// options are few, fixed, and worth keeping visible.
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    required this.segments,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<AppSegment<T>> segments;
  final T value;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: AppRadii.radiusSm,
      ),
      child: Row(
        children: [
          for (final segment in segments)
            Expanded(
              child: Semantics(
                inMutuallyExclusiveGroup: true,
                selected: segment.value == value,
                label: segment.label,
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: onChanged == null
                      ? null
                      : () => onChanged!(segment.value),
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    curve: AppMotion.standard,
                    constraints: const BoxConstraints(
                      minHeight: AppSpacing.minTapTarget,
                    ),
                    decoration: BoxDecoration(
                      color: segment.value == value
                          ? colors.surface
                          : const Color(0x00000000),
                      borderRadius: AppRadii.radiusXs,
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (segment.icon != null) ...[
                            Icon(
                              segment.icon,
                              size: 16,
                              color: segment.value == value
                                  ? colors.onSurface
                                  : colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                          ],
                          Flexible(
                            child: Text(
                              segment.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSmall.copyWith(
                                color: segment.value == value
                                    ? colors.onSurface
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
