import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// A labelled on/off toggle.
///
/// The label is part of the target — tapping the text toggles it, which matters on
/// a phone where the switch itself is a small thumb.
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onChanged != null;

    return Semantics(
      toggled: value,
      enabled: enabled,
      label: description == null ? label : '$label, $description',
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? () => onChanged!(!value) : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: AppTypography.bodyLarge
                            .copyWith(color: colors.onSurface),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          description!,
                          style: AppTypography.bodySmall
                              .copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
