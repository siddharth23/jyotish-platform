import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// A row in a list.
///
/// The whole row is one semantic node, so a screen reader announces
/// "Geburtsdatum, 17. Mai 1990, button" rather than stopping on each fragment.
class AppListTile extends StatelessWidget {
  const AppListTile({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final titleColor = isDestructive ? colors.error : colors.onSurface;

    return Semantics(
      button: onTap != null,
      label: subtitle == null ? title : '$title, $subtitle',
      excludeSemantics: true,
      child: Material(
        color: const Color(0x00000000),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.radiusSm,
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(minHeight: AppSpacing.minTapTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: AppTypography.titleSmall
                              .copyWith(color: titleColor),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            subtitle!,
                            style: AppTypography.bodySmall
                                .copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: AppSpacing.md),
                    trailing!,
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
