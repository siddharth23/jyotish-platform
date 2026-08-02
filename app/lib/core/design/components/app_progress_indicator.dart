import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/app_radii.dart';

/// An indeterminate spinner.
class AppProgressIndicator extends StatelessWidget {
  const AppProgressIndicator({this.size = 24, this.label, super.key});

  final double size;

  /// Announced while busy. Defaults to a generic loading message.
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label ?? 'Wird geladen',
        liveRegion: true,
        child: SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: size / 12,
            valueColor: AlwaysStoppedAnimation<Color>(context.colors.primary),
          ),
        ),
      );
}

/// A determinate bar, for known-length work such as a PDF upload.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({required this.value, this.label, super.key});

  /// 0.0 to 1.0.
  final double value;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final percent = (value.clamp(0.0, 1.0) * 100).round();
    return Semantics(
      // The percentage is announced; a bare bar tells a screen-reader user nothing.
      label: label == null ? '$percent Prozent' : '$label, $percent Prozent',
      value: '$percent%',
      child: ClipRRect(
        borderRadius: AppRadii.radiusPill,
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          minHeight: 8,
          backgroundColor: colors.surfaceVariant,
          valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
        ),
      ),
    );
  }
}
