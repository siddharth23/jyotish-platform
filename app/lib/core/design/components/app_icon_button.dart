import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';

/// An icon-only button.
///
/// The most common source of undersized tap targets: a 20pt glyph looks complete
/// on screen while offering less than half the required touchable area. The icon
/// is drawn at [iconSize] but the target is always at least 44pt.
///
/// [tooltip] is required rather than optional — an icon with no text has nothing
/// for a screen reader to announce, and "button" is not a description.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.iconSize = 20,
    this.color,
    this.isDestructive = false,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Announced by screen readers and shown on long-press.
  final String tooltip;

  final double iconSize;
  final Color? color;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onPressed != null;
    final foreground =
        color ?? (isDestructive ? colors.error : colors.onSurfaceVariant);

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        excludeSemantics: true,
        child: Material(
          color: const Color(0x00000000),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            borderRadius: AppRadii.radiusPill,
            child: Opacity(
              opacity: enabled ? 1.0 : 0.38,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: AppSpacing.minTapTarget,
                  minHeight: AppSpacing.minTapTarget,
                ),
                child: Center(
                  child: Icon(icon, size: iconSize, color: foreground),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
