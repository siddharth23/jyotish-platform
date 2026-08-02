import 'package:flutter/material.dart';

import '../../../core/design/design_system.dart';
import '../../../core/l10n/generated/app_l10n.dart';

/// Career and industry fit.
///
/// Personal use only — see docs/adr/0005. This screen must never grow an
/// employer-facing or multi-candidate mode.
class CareerScreen extends StatelessWidget {
  const CareerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppEmptyState(
      icon: Icons.work_outline,
      title: l10n.navCareer,
      message: l10n.placeholderNotBuilt,
    );
  }
}
