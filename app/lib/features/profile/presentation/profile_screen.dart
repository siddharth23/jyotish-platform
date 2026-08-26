import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design_system.dart';
import '../../../core/flags/feature_flag.dart';
import '../../../core/flags/flag_providers.dart';
import '../../../core/l10n/generated/app_l10n.dart';
import '../../../core/l10n/language_selector.dart';
import '../../../core/navigation/app_routes.dart';

/// Profile and settings.
///
/// The only tab with real content so far: the language override from US-085
/// lives here rather than in the design gallery, which is where a user would
/// actually look for it.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final showGallery =
        ref.watch(featureFlagProvider(FeatureFlag.designGallery));
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      children: [
        AppSectionHeader(title: l10n.settingsLanguage),
        const LanguageSelector(),
        const AppDivider(),
        if (showGallery) ...[
          AppSectionHeader(title: l10n.profileDeveloperSection),
          AppListTile(
            title: l10n.galleryTitle,
            subtitle: l10n.profileDesignGallerySubtitle,
            leading: const Icon(Icons.palette_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.designGallery),
          ),
          const AppDivider(),
        ],

        // Last, and deliberately so. A destructive action does not belong
        // above the settings someone opened this tab to change.
        AppSectionHeader(title: l10n.accountSectionTitle),
        AppListTile(
          title: l10n.accountDelete,
          subtitle: l10n.accountDeleteSubtitle,
          leading: const Icon(Icons.delete_outline),
          trailing: const Icon(Icons.chevron_right),
          isDestructive: true,
          // Two taps to here (Profile tab, this row), one to confirm in the
          // dialog: three, as AC1 requires. Apple 5.1.1(v) requires it to
          // exist in the app at all.
          onTap: () => context.push(AppRoutes.deleteAccount),
        ),
      ],
    );
  }
}
