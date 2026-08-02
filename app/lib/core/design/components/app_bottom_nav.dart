import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// A destination in [AppBottomNav].
@immutable
class AppNavDestination {
  const AppNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Primary navigation between top-level sections.
///
/// Labels are always shown, never icon-only. German section names are long enough
/// that an unlabelled glyph becomes a guess, and permanently visible labels are
/// also the accessible default.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.destinations,
    required this.currentIndex,
    required this.onSelected,
    super.key,
  });

  final List<AppNavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.outline.withValues(alpha: 0.3)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < destinations.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == currentIndex,
                  label: destinations[i].label,
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => onSelected(i),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AppSpacing.minTapTarget,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              i == currentIndex
                                  ? destinations[i].selectedIcon
                                  : destinations[i].icon,
                              size: 22,
                              color: i == currentIndex
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              destinations[i].label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSmall.copyWith(
                                fontSize: 11,
                                color: i == currentIndex
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
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
      ),
    );
  }
}
