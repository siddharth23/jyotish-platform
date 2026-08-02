import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// One option within an [AppRadioGroup].
@immutable
class AppRadioOption<T> {
  const AppRadioOption({
    required this.value,
    required this.label,
    this.description,
  });

  final T value;
  final String label;
  final String? description;
}

/// A vertical set of mutually exclusive options.
///
/// Used where a dropdown would hide the choices — ayanamsa and house system, which
/// the user should be able to compare at a glance rather than discover one at a
/// time.
class AppRadioGroup<T> extends StatelessWidget {
  const AppRadioGroup({
    required this.options,
    required this.value,
    required this.onChanged,
    this.groupLabel,
    super.key,
  });

  final List<AppRadioOption<T>> options;
  final T? value;
  final ValueChanged<T>? onChanged;
  final String? groupLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final enabled = onChanged != null;

    // RadioGroup owns the selection; individual Radios only declare their value.
    // The per-Radio groupValue/onChanged pair was deprecated after 3.32.
    //
    // RadioGroup.onChanged is non-nullable, so a disabled group cannot express
    // itself by passing null the way most controls do. Interaction is blocked at
    // the pointer level instead, and the dimming plus `enabled: false` on each
    // option is what actually communicates the state.
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.38,
        child: RadioGroup<T>(
          groupValue: value,
          onChanged: (v) {
            if (v != null) onChanged?.call(v);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (groupLabel != null) ...[
                Text(
                  groupLabel!,
                  style: AppTypography.labelSmall
                      .copyWith(color: colors.onSurface),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              for (final option in options)
                Semantics(
                  inMutuallyExclusiveGroup: true,
                  checked: option.value == value,
                  label: option.description == null
                      ? option.label
                      : '${option.label}, ${option.description}',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: onChanged == null
                        ? null
                        : () => onChanged!(option.value),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                          minHeight: AppSpacing.minTapTarget),
                      child: Row(
                        children: [
                          Radio<T>(value: option.value),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  option.label,
                                  style: AppTypography.bodyLarge
                                      .copyWith(color: colors.onSurface),
                                ),
                                if (option.description != null)
                                  Text(
                                    option.description!,
                                    style: AppTypography.bodySmall.copyWith(
                                        color: colors.onSurfaceVariant),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
