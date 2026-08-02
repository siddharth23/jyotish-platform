import 'package:flutter/material.dart';

import '../../../core/design/design_system.dart';
import '../../../core/l10n/generated/app_l10n.dart';

/// A single evaluation, opened from its delivery email or push notification.
///
/// Exists mainly so the deep link has somewhere real to land: a link that
/// resolves to a 404 in a paid delivery email is worse than no link.
class EvaluationDetailScreen extends StatelessWidget {
  const EvaluationDetailScreen({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppEmptyState(
      icon: Icons.receipt_long_outlined,
      title: l10n.evaluationOrderTitle(orderId),
      message: l10n.placeholderNotBuilt,
    );
  }
}
