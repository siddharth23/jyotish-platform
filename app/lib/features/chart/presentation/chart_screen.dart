import 'package:flutter/material.dart';

import '../../../core/design/design_system.dart';
import '../../../core/l10n/generated/app_l10n.dart';

/// Kundali. Placeholder until birth-data capture (E03) and the engine exist.
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
      // No destination yet: the birth-data flow is US-020 onwards.
      onAction: null,
    );
  }
}
