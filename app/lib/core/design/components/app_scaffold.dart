import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/app_spacing.dart';
import 'app_icon_button.dart';

/// The standard screen frame.
///
/// Screens use this rather than [Scaffold] directly so the app bar, background and
/// safe-area handling stay identical everywhere. [bottomBar] sits outside the
/// scroll view and inside the safe area, which is where a primary action such as
/// "Auswertung bestellen" belongs.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.body,
    this.title,
    this.onBack,
    this.backTooltip,
    this.actions = const [],
    this.bottomBar,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget body;
  final String? title;

  /// Shows a back control. Requires [backTooltip].
  final VoidCallback? onBack;
  final String? backTooltip;

  final List<Widget> actions;
  final Widget? bottomBar;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    assert(
      onBack == null || backTooltip != null,
      'A back control needs backTooltip so it can be announced.',
    );
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: title == null && onBack == null
          ? null
          : AppBar(
              title: title == null ? null : Text(title!),
              leading: onBack == null
                  ? null
                  : AppIconButton(
                      icon: Icons.arrow_back,
                      onPressed: onBack,
                      tooltip: backTooltip!,
                    ),
              actions: actions,
            ),
      body: SafeArea(
        child: Padding(padding: padding, child: body),
      ),
      bottomNavigationBar: bottomBar == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(AppSpacing.lg),
              child: bottomBar!,
            ),
    );
  }
}
