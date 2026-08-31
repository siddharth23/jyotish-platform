import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design_system.dart';
import '../../../core/l10n/generated/app_l10n.dart';
import '../../../core/navigation/app_routes.dart';

/// Kundali.
///
/// Still a placeholder for the chart itself — the engine is US-031 onwards —
/// but the empty state's action now goes somewhere: birth-data capture is the
/// first step of getting a chart, and this tab is the only place a user would
/// look for it.
class ChartScreen extends StatelessWidget {
  const ChartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppEmptyState(
      icon: Icons.grid_on_outlined,
      title: l10n.emptyChartTitle,
      message: l10n.emptyChartMessage,
      actionLabel: l10n.emptyChartAction,
      onAction: () => context.push(AppRoutes.birthData),
    );
  }
}
