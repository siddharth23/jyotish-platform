import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// A label and its value on one line.
///
/// The backbone of every chart detail view — graha to degree, dasha to date range.
/// The value uses the tabular numeric style so a column of degrees lines up
/// instead of jittering with the width of each digit.
class AppKeyValueRow extends StatelessWidget {
  const AppKeyValueRow({
    required this.label,
    required this.value,
    this.isNumeric = true,
    this.trailing,
    super.key,
  });

  final String label;
  final String value;

  /// Set false for values that are words rather than figures.
  final bool isNumeric;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      // One node: "Aszendent, 5 Grad Löwe" rather than two disconnected reads.
      label: '$label, $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyMedium
                    .copyWith(color: colors.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Flexible, not a bare Text: a long value — a translated status, a
            // German sign name — otherwise overflows the row rather than
            // wrapping. Loose fit so short values such as '5°12′ Löwe' still
            // shrink to their content instead of claiming half the row.
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: (isNumeric
                        ? AppTypography.numeric
                        : AppTypography.bodyMedium)
                    .copyWith(color: colors.onSurface),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
