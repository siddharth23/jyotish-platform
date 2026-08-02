import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/app_spacing.dart';

/// A hairline rule between sections.
///
/// Decorative by default, so screen readers skip it rather than announcing a
/// separator between every row.
class AppDivider extends StatelessWidget {
  const AppDivider({this.indent = 0, this.endIndent = 0, super.key});

  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Divider(
          color: context.colors.outline.withValues(alpha: 0.35),
          thickness: 1,
          height: AppSpacing.lg,
          indent: indent,
          endIndent: endIndent,
        ),
      );
}
