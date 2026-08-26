import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design/design_system.dart';
import '../../../core/l10n/generated/app_l10n.dart';
import '../account_deletion_controller.dart';

/// Self-service account deletion (US-015).
///
/// ## Why this screen exists at all, rather than a support address
///
/// Apple guideline 5.1.1(v): an app that lets you create an account must let
/// you delete it *from inside the app*. A link to a web form or an email
/// address is a review rejection, so this route is not a nicety — it gates
/// store submission.
///
/// ## The screen is mostly explanation, and that is the point
///
/// AC2 requires the user to be told what is deleted and what is kept before
/// they confirm. "Delete my account" and "erase every trace of me" are not the
/// same promise: German tax law obliges us to keep invoices for ten years
/// (§ 147 AO), and GDPR Article 17(3)(b) is what makes that lawful. A user who
/// discovers that afterwards has a complaint to a supervisory authority; a user
/// who reads it here does not.
///
/// The retained item names the paragraph so it can be checked, and says what
/// the kept record contains. Vagueness here reads as evasion.
class DeleteAccountScreen extends ConsumerWidget {
  const DeleteAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final state = ref.watch(accountDeletionControllerProvider);

    return AppScaffold(
      title: l10n.deleteAccountTitle,
      onBack: () => Navigator.of(context).maybePop(),
      backTooltip: l10n.commonClose,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      body: ListView(
        children: [
          const SizedBox(height: AppSpacing.md),
          Text(l10n.deleteAccountIntro,
              style: AppTypography.bodyLarge
                  .copyWith(color: context.colors.onSurface)),
          const SizedBox(height: AppSpacing.lg),

          AppSectionHeader(title: l10n.deleteAccountErasedHeading),
          _Bullets(
            items: [
              l10n.deleteAccountErasedBirthData,
              l10n.deleteAccountErasedCharts,
              l10n.deleteAccountErasedCareer,
              l10n.deleteAccountErasedAccount,
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Not folded into the list above. What we keep is the part a user
          // does not expect, so it gets its own heading rather than being the
          // last bullet of something they have stopped reading.
          AppSectionHeader(title: l10n.deleteAccountRetainedHeading),
          Text(
            l10n.deleteAccountRetainedInvoices,
            style: AppTypography.bodyMedium.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (state case AccountDeletionScheduled(:final purgeDueAt)) ...[
            AppBanner(
              title: l10n.deleteAccountScheduled,
              message: '${_purgeDate(context, purgeDueAt)}\n'
                  '${l10n.deleteAccountCancelHint}',
            ),
          ] else ...[
            if (state is AccountDeletionFailed)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppBanner(
                  title: l10n.errorGenericTitle,
                  message: l10n.deleteAccountFailed,
                  tone: AppBannerTone.danger,
                ),
              ),
            AppButton(
              label: l10n.deleteAccountCta,
              variant: AppButtonVariant.destructive,
              isLoading: state is AccountDeletionInProgress,
              onPressed: () => _confirm(context, ref),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  String _purgeDate(BuildContext context, DateTime purgeDueAt) {
    final l10n = AppL10n.of(context);
    // Explicit pattern rather than a locale default: `yMd` renders German as
    // 6.8.2026, and a deletion date is the wrong place to be casual about
    // which number is the month. Matches the app's other date formatting.
    final pattern = Localizations.localeOf(context).languageCode == 'de'
        ? 'dd.MM.yyyy'
        : 'dd/MM/yyyy';
    return l10n.deleteAccountPurgeDate(DateFormat(pattern).format(purgeDueAt));
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final l10n = AppL10n.of(context);
    final confirmed = await AppDialog.confirm(
      context: context,
      title: l10n.deleteAccountDialogTitle,
      // The dialog repeats the retention point. It is the last thing shown
      // before an irreversible action, and it must not be the one screen where
      // the promise is simpler than the truth.
      message: l10n.deleteAccountDialogMessage,
      confirmLabel: l10n.deleteAccountDialogConfirm,
      cancelLabel: l10n.commonCancel,
      isDestructive: true,
    );
    if (!confirmed) return;
    await ref
        .read(accountDeletionControllerProvider.notifier)
        .requestDeletion();
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ',
                    style: AppTypography.bodyMedium
                        .copyWith(color: context.colors.onSurface)),
                // Flexible, not a bare Text: German runs about 30% longer than
                // English and these strings wrap. See `AppKeyValueRow`, which
                // overflowed for exactly this reason.
                Flexible(
                    child: Text(item,
                        style: AppTypography.bodyMedium
                            .copyWith(color: context.colors.onSurface))),
              ],
            ),
          ),
      ],
    );
  }
}
