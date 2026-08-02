import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// A labelled checkbox.
///
/// Used for the consent boxes at checkout, where the label is a full sentence of
/// legal text. The box stays top-aligned so it does not drift to the middle of a
/// four-line Widerrufsbelehrung.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
    this.isRequired = false,
    this.errorText,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool isRequired;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onChanged != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          checked: value,
          enabled: enabled,
          label: isRequired ? '$label, Pflichtfeld' : label,
          excludeSemantics: true,
          child: InkWell(
            onTap: enabled ? () => onChanged!(!value) : null,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(minHeight: AppSpacing.minTapTarget),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: value,
                    // Framework signature is nullable for tristate; this
                    // checkbox is binary, so null is coerced to false.
                    onChanged: enabled ? (v) => onChanged!(v ?? false) : null,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Padding(
                      // Aligns the first text line with the box beside it.
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: Text(
                        label,
                        style: AppTypography.bodyMedium
                            .copyWith(color: colors.onSurface),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.lg),
            child: Semantics(
              liveRegion: true,
              child: Text(
                errorText!,
                style: AppTypography.bodySmall.copyWith(color: colors.error),
              ),
            ),
          ),
      ],
    );
  }
}
