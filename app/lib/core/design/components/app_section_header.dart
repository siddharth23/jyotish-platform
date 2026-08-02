import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// A heading above a group of content.
///
/// Marked as a header for assistive technology, which is what lets a screen-reader
/// user jump between sections instead of reading a long chart screen top to bottom.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: AppTypography.titleSmall
                        .copyWith(color: colors.onSurface),
                  ),
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
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
