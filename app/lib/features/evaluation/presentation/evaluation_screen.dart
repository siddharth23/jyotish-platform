import 'package:flutter/material.dart';

import '../../../core/design/design_system.dart';
import '../../../core/l10n/generated/app_l10n.dart';

/// Expert evaluations — the paid product.
class EvaluationScreen extends StatelessWidget {
  const EvaluationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppEmptyState(
      icon: Icons.article_outlined,
      title: l10n.navEvaluation,
      message: l10n.placeholderNotBuilt,
    );
  }
}
