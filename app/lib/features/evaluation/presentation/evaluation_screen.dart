import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_system.dart';
import '../../../core/flags/feature_flag.dart';
import '../../../core/flags/flag_providers.dart';
import '../../../core/l10n/generated/app_l10n.dart';

/// Expert evaluations — the paid product.
///
/// Gated on [FeatureFlag.paidEvaluation], the kill switch from US-006. When it
/// is off the ordering path is not merely hidden but absent, so there is no way
/// to reach checkout from here at all: a hidden-but-present button is still
/// reachable by deep link or by a stale widget tree.
class EvaluationScreen extends ConsumerWidget {
  const EvaluationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final canOrder = ref.watch(featureFlagProvider(FeatureFlag.paidEvaluation));

    if (!canOrder) {
      return AppEmptyState(
        icon: Icons.pause_circle_outline,
        title: l10n.evaluationUnavailableTitle,
        message: l10n.evaluationUnavailableMessage,
      );
    }

    return AppEmptyState(
      icon: Icons.article_outlined,
      title: l10n.navEvaluation,
      message: l10n.placeholderNotBuilt,
    );
  }
}
