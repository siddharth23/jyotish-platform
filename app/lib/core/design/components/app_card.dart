import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/app_elevation.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';

/// A surface for grouping related content.
///
/// Tapping is optional. When [onTap] is supplied the whole card becomes one
/// button to a screen reader rather than a pile of separately-focusable text —
/// otherwise navigating a list of cards means stepping through every line inside
/// each one.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.elevation,
    this.isSelected = false,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  /// Defaults to level 1, or level 0 when the card is a tappable list row.
  final List<BoxShadow>? elevation;

  final bool isSelected;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final brightness = Theme.of(context).brightness;
    final shadow = AppElevation.forBrightness(
      brightness,
      elevation ?? AppElevation.level1,
    );

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.radiusMd,
        boxShadow: shadow,
        border: Border.all(
          color: isSelected
              ? colors.primary
              : colors.outline.withValues(alpha: 0.25),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: child,
    );

    if (onTap == null) {
      return semanticLabel == null
          ? content
          : Semantics(label: semanticLabel, child: content);
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      selected: isSelected,
      child: Material(
        color: const Color(0x00000000),
        borderRadius: AppRadii.radiusMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.radiusMd,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTapTarget,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
