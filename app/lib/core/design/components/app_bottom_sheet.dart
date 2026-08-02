import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// A modal sheet.
///
/// [show] is the entry point rather than a constructor, because a sheet is a
/// route, not a widget a screen composes.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    required this.title,
    required this.child,
    this.closeTooltip = 'Schliessen',
    super.key,
  });

  final String title;
  final Widget child;
  final String closeTooltip;

  /// Presents the sheet and resolves with whatever it is popped with.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget child,
  }) =>
      showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: context.colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
        builder: (_) => AppBottomSheet(title: title, child: child),
      );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      // Lifts the sheet above the keyboard when it contains a field.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: ExcludeSemantics(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outline,
                  borderRadius: AppRadii.radiusPill,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.titleMedium
                        .copyWith(color: colors.onSurface),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Semantics(
                    button: true,
                    label: closeTooltip,
                    child: const SizedBox(
                      width: AppSpacing.minTapTarget,
                      height: AppSpacing.minTapTarget,
                      child: Icon(Icons.close, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
