import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/design_system.dart';
import '../l10n/generated/app_l10n.dart';
import 'connectivity_controller.dart';

/// A strip shown above the content while the device is offline.
///
/// Sits inside the shell rather than over it, so it pushes content down instead
/// of covering a control. It also animates in rather than appearing instantly —
/// a banner that pops in and out on a flaky connection is more alarming than the
/// connection itself.
///
/// It states what still works, not just that something is broken. Saved charts
/// are readable offline; only ordering and delivery need the network.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectivityControllerProvider);
    final l10n = AppL10n.of(context);

    return AnimatedSize(
      duration: AppMotion.normal,
      curve: AppMotion.standard,
      alignment: Alignment.topCenter,
      child: status == NetworkStatus.online
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
              child: AppBanner(
                message: l10n.offlineMessage,
                tone: AppBannerTone.warning,
              ),
            ),
    );
  }
}
