import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// A compact selectable or filter token.
///
/// Selection is signalled by fill, border weight *and* an optional check glyph,
/// never by colour alone.
class AppChip extends StatelessWidget {
  const AppChip({
    required this.label,
    this.onTap,
    this.isSelected = false,
    this.icon,
    this.onDeleted,
    this.deleteTooltip,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isSelected;
  final IconData? icon;

  /// Shows a remove affordance. Requires [deleteTooltip] for its label.
  final VoidCallback? onDeleted;
  final String? deleteTooltip;

  @override
  Widget build(BuildContext context) {
    assert(
      onDeleted == null || deleteTooltip != null,
      'A deletable chip needs deleteTooltip so the remove control can be announced.',
    );
    final colors = context.colors;

    final background =
        isSelected ? colors.primaryContainer : colors.surfaceVariant;
    final foreground =
        isSelected ? colors.onPrimaryContainer : colors.onSurfaceVariant;

    return Semantics(
      button: onTap != null,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: background,
        borderRadius: AppRadii.radiusPill,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.radiusPill,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTapTarget,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                borderRadius: AppRadii.radiusPill,
                border: Border.all(
                  color: isSelected ? colors.primary : colors.outline,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected) ...[
                    Icon(Icons.check, size: 16, color: foreground),
                    const SizedBox(width: AppSpacing.xs),
                  ] else if (icon != null) ...[
                    Icon(icon, size: 16, color: foreground),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppTypography.labelSmall.copyWith(color: foreground),
                    ),
                  ),
                  if (onDeleted != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    GestureDetector(
                      onTap: onDeleted,
                      child: Semantics(
                        button: true,
                        label: deleteTooltip,
                        child: Icon(Icons.close, size: 16, color: foreground),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
