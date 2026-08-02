import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// A labelled text input with error and helper text.
///
/// The error message is announced via [Semantics.liveRegion] as well as shown, and
/// the field is never left communicating its state by colour alone — a red border
/// is invisible to a red-green colour-blind user, so the message text carries the
/// meaning.
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    this.controller,
    this.hint,
    this.helperText,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofillHints,
    this.isRequired = false,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helperText;

  /// Non-null puts the field in its error state.
  final String? errorText;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;
  final int maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final Iterable<String>? autofillHints;
  final bool isRequired;

  bool get _hasError => errorText != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(color: colors.onSurface),
            ),
            if (isRequired) ...[
              const SizedBox(width: AppSpacing.xxs),
              // Marked required in text as well as glyph, so it is not
              // conveyed by a lone asterisk.
              Semantics(
                label: 'Pflichtfeld',
                child: Text(
                  '*',
                  style: AppTypography.labelSmall.copyWith(color: colors.error),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          maxLines: obscureText ? 1 : maxLines,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          autofillHints: autofillHints,
          style: AppTypography.bodyLarge.copyWith(color: colors.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            // Error and helper are rendered below rather than by the framework,
            // so the live region wraps only the message.
            counterText: '',
            errorText: null,
          ),
        ),
        if (_hasError || helperText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            liveRegion: _hasError,
            child: Text(
              errorText ?? helperText!,
              style: AppTypography.bodySmall.copyWith(
                color: _hasError ? colors.error : colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
