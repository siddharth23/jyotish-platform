import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_formats.dart';
import '../../l10n/generated/app_l10n.dart';
import '../../l10n/language_selector.dart';
import '../../l10n/locale_controller.dart';
import '../design_system.dart';

/// A live catalogue of every component, in both themes.
///
/// Not a product screen — it ships with the design system so a change to a token
/// can be seen everywhere at once, and so the components can be reviewed on a real
/// device rather than in a screenshot. Also the fastest way to spot a component
/// that only looks right in light mode.
class DesignGallery extends ConsumerStatefulWidget {
  const DesignGallery({super.key});

  @override
  ConsumerState<DesignGallery> createState() => _DesignGalleryState();
}

class _DesignGalleryState extends ConsumerState<DesignGallery> {
  bool _dark = false;
  int _tab = 0;
  bool _switchOn = true;
  bool _checked = false;
  String _ayanamsa = 'lahiri';
  int _chartStyle = 0;
  final Set<String> _selectedVargas = {'D9'};

  @override
  Widget build(BuildContext context) {
    // A null locale means "follow the device", which is what MaterialApp does
    // when the property is omitted.
    final preference = ref.watch(localeControllerProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      locale: preference.locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(builder: _buildGallery),
    );
  }

  Widget _buildGallery(BuildContext context) {
    final colors = context.colors;
    final l10n = AppL10n.of(context);

    return AppScaffold(
      title: l10n.galleryTitle,
      actions: [
        const LanguageToggleButton(),
        AppIconButton(
          icon: _dark ? Icons.light_mode : Icons.dark_mode,
          onPressed: () => setState(() => _dark = !_dark),
          tooltip: _dark ? l10n.galleryThemeLight : l10n.galleryThemeDark,
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          _section(l10n.settingsLanguage),
          const LanguageSelector(),
          _section(l10n.gallerySectionFormatting),
          AppKeyValueRow(
            label: l10n.fieldBirthDate,
            value: AppFormats.longDate(context, DateTime(1990, 5, 17)),
          ),
          AppKeyValueRow(
            label: l10n.fieldBirthTime,
            value: AppFormats.time(context, DateTime(1990, 5, 17, 8, 30)),
          ),
          AppKeyValueRow(
              label: l10n.labelPrice, value: AppFormats.euro(context, 11)),
          AppKeyValueRow(
            label: l10n.labelDeliverBy,
            value: l10n.daysRemaining(2),
          ),
          _section(l10n.gallerySectionColours),
          _ColorGrid(colors: colors),
          _section(l10n.gallerySectionTypography),
          Text('Display Large',
              style: Theme.of(context).textTheme.displayLarge),
          Text('Title Large', style: Theme.of(context).textTheme.titleLarge),
          Text('Body Large — ${l10n.labelAscendant}',
              style: Theme.of(context).textTheme.bodyLarge),
          Text('Body Small — sekundärer Text',
              style: Theme.of(context).textTheme.bodySmall),
          AppKeyValueRow(
              label: l10n.galleryTabularFigures, value: AppFormats.arc(12.576)),
          _section(l10n.gallerySectionButtons),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppButton(label: l10n.galleryButtonPrimary, onPressed: () {}),
              AppButton(
                label: l10n.galleryButtonSecondary,
                variant: AppButtonVariant.secondary,
                onPressed: () {},
              ),
              AppButton(
                label: l10n.galleryButtonTertiary,
                variant: AppButtonVariant.tertiary,
                onPressed: () {},
              ),
              AppButton(
                label: l10n.galleryButtonDestructive,
                variant: AppButtonVariant.destructive,
                icon: Icons.delete_outline,
                onPressed: () {},
              ),
              AppButton(label: l10n.galleryButtonDisabled, onPressed: null),
              AppButton(
                  label: l10n.galleryButtonLoading,
                  isLoading: true,
                  onPressed: () {}),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: l10n.orderCta(AppFormats.euro(context, 11)),
            isFullWidth: true,
            size: AppButtonSize.large,
            onPressed: () => AppSnackBar.show(
              context,
              message: l10n.snackDemoOnly,
              tone: AppSnackTone.success,
            ),
          ),
          _section(l10n.gallerySectionInputs),
          AppTextField(
            label: l10n.fieldBirthPlace,
            hint: l10n.fieldBirthPlaceHint,
            helperText: l10n.fieldBirthPlaceHelper,
            isRequired: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: l10n.fieldBirthTime,
            hint: 'HH:MM',
            errorText: l10n.fieldBirthTimeError,
          ),
          _section(l10n.gallerySectionSelection),
          AppSegmentedControl<int>(
            segments: [
              AppSegment(value: 0, label: l10n.chartStyleNorth),
              AppSegment(value: 1, label: l10n.chartStyleSouth),
              AppSegment(value: 2, label: l10n.chartStyleWestern),
            ],
            value: _chartStyle,
            onChanged: (v) => setState(() => _chartStyle = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final varga in ['D1', 'D9', 'D10', 'D12'])
                AppChip(
                  label: varga,
                  isSelected: _selectedVargas.contains(varga),
                  onTap: () => setState(() {
                    _selectedVargas.contains(varga)
                        ? _selectedVargas.remove(varga)
                        : _selectedVargas.add(varga);
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppRadioGroup<String>(
            groupLabel: l10n.ayanamsaLabel,
            options: [
              AppRadioOption(
                value: 'lahiri',
                label: 'Lahiri',
                description: l10n.ayanamsaLahiriDescription,
              ),
              const AppRadioOption(value: 'raman', label: 'Raman'),
              const AppRadioOption(value: 'kp', label: 'Krishnamurti'),
            ],
            value: _ayanamsa,
            onChanged: (v) => setState(() => _ayanamsa = v),
          ),
          AppSwitch(
            label: l10n.prefsDailyPanchang,
            description: l10n.prefsDailyPanchangDescription,
            value: _switchOn,
            onChanged: (v) => setState(() => _switchOn = v),
          ),
          AppCheckbox(
            label: l10n.consentWithdrawal,
            value: _checked,
            isRequired: true,
            onChanged: (v) => setState(() => _checked = v),
          ),
          _section(l10n.gallerySectionStatus),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppBadge(label: l10n.statusDraft),
              AppBadge(label: l10n.statusPaid, tone: AppBadgeTone.success),
              AppBadge(label: l10n.statusInProgress, tone: AppBadgeTone.info),
              AppBadge(label: l10n.statusSlaRisk, tone: AppBadgeTone.warning),
              AppBadge(label: l10n.statusCancelled, tone: AppBadgeTone.danger),
              AppBadge(label: l10n.statusExpert, tone: AppBadgeTone.accent),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppBanner(
            title: l10n.bannerDeliveryTitle,
            message: l10n.bannerDeliveryMessage,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppBanner(
            message: l10n.bannerPaymentFailed,
            tone: AppBannerTone.danger,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppStepper(
            currentStep: 2,
            totalSteps: 4,
            stepLabel: l10n.fieldBirthPlace,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppProgressBar(value: 0.62, label: l10n.progressPdf),
          _section(l10n.gallerySectionContent),
          AppCard(
            onTap: () {},
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AppAvatar(name: 'Anna Schmidt'),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Anna Schmidt',
                              style: Theme.of(context).textTheme.titleSmall),
                          Text(
                            '${l10n.astrologerRole} · '
                            '${l10n.evaluationCount(128)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const AppBadge(label: 'AKTIV', tone: AppBadgeTone.success),
                  ],
                ),
                const AppDivider(),
                AppKeyValueRow(label: l10n.labelAscendant, value: '5°12′ Löwe'),
                AppKeyValueRow(label: l10n.labelMoon, value: '18°44′ Stier'),
                AppKeyValueRow(
                  label: l10n.labelMahadasha,
                  value: 'Venus bis 2031',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppListTile(
            title: l10n.fieldBirthDate,
            subtitle:
                '${AppFormats.dateTime(context, DateTime(1990, 5, 17, 8, 30))}, Berlin',
            leading: Icon(Icons.event, color: colors.onSurfaceVariant),
            trailing: Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            onTap: () {},
          ),
          _section(l10n.gallerySectionLoading),
          const AppSkeletonText(),
          _section(l10n.gallerySectionEmpty),
          SizedBox(
            height: 260,
            child: AppEmptyState(
              title: l10n.emptyChartTitle,
              message: l10n.emptyChartMessage,
              actionLabel: l10n.emptyChartAction,
              onAction: () {},
            ),
          ),
          SizedBox(
            height: 260,
            child: AppErrorState(
              title: l10n.errorGenericTitle,
              message: l10n.errorEvaluationMessage,
              retryLabel: l10n.commonRetry,
              onRetry: () {},
            ),
          ),
          _section(l10n.gallerySectionOverlays),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppButton(
                label: l10n.galleryDialogButton,
                variant: AppButtonVariant.secondary,
                onPressed: () => AppDialog.confirm(
                  context: context,
                  title: l10n.dialogCancelOrderTitle,
                  message: l10n.dialogCancelOrderMessage,
                  confirmLabel: l10n.dialogCancelOrderConfirm,
                  cancelLabel: l10n.commonCancel,
                  isDestructive: true,
                ),
              ),
              AppButton(
                label: l10n.galleryBottomSheetButton,
                variant: AppButtonVariant.secondary,
                onPressed: () => AppBottomSheet.show<void>(
                  context: context,
                  title: l10n.houseSystemLabel,
                  child: AppRadioGroup<String>(
                    options: [
                      AppRadioOption(
                          value: 'w', label: l10n.houseSystemWholeSign),
                      const AppRadioOption(value: 'p', label: 'Placidus'),
                    ],
                    value: 'w',
                    onChanged: null,
                  ),
                ),
              ),
              AppButton(
                label: l10n.gallerySnackbarButton,
                variant: AppButtonVariant.secondary,
                onPressed: () => AppSnackBar.show(
                  context,
                  message: l10n.snackSaved,
                  tone: AppSnackTone.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
      bottomBar: AppBottomNav(
        destinations: [
          AppNavDestination(
            icon: Icons.auto_awesome_outlined,
            selectedIcon: Icons.auto_awesome,
            label: l10n.navChart,
          ),
          AppNavDestination(
            icon: Icons.work_outline,
            selectedIcon: Icons.work,
            label: l10n.navCareer,
          ),
          AppNavDestination(
            icon: Icons.article_outlined,
            selectedIcon: Icons.article,
            label: l10n.navEvaluation,
          ),
          AppNavDestination(
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            label: l10n.navProfile,
          ),
        ],
        currentIndex: _tab,
        onSelected: (i) => setState(() => _tab = i),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xl),
        child: AppSectionHeader(title: title),
      );
}

class _ColorGrid extends StatelessWidget {
  const _ColorGrid({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final swatches = <String, (Color, Color)>{
      'surface': (colors.surface, colors.onSurface),
      'surfaceVariant': (colors.surfaceVariant, colors.onSurfaceVariant),
      'primary': (colors.primary, colors.onPrimary),
      'primaryContainer': (colors.primaryContainer, colors.onPrimaryContainer),
      'accent': (colors.accent, colors.onAccent),
      'accentContainer': (colors.accentContainer, colors.onAccentContainer),
      'error': (colors.error, colors.onError),
    };

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final entry in swatches.entries)
          Container(
            width: 104,
            height: 64,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: entry.value.$1,
              borderRadius: AppRadii.radiusSm,
              border: Border.all(color: colors.outline.withValues(alpha: 0.4)),
            ),
            child: Text(
              entry.key,
              style: AppTypography.labelSmall.copyWith(color: entry.value.$2),
            ),
          ),
      ],
    );
  }
}
