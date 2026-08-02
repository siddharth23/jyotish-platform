import 'package:flutter/material.dart';

import '../../../core/design/design_system.dart';
import '../../../core/l10n/generated/app_l10n.dart';

/// Landing screen.
///
/// A placeholder: the daily panchang, transit summary and recent evaluations
/// that belong here all depend on the calculation engine, which has no native
/// build yet.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppEmptyState(
      icon: Icons.auto_awesome_outlined,
      title: l10n.navHome,
      message: l10n.placeholderNotBuilt,
    );
  }
}
