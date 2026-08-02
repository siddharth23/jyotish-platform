import 'package:flutter/material.dart';

import '../design_system.dart';

/// A live catalogue of every component, in both themes.
///
/// Not a product screen — it ships with the design system so a change to a token
/// can be seen everywhere at once, and so the components can be reviewed on a real
/// device rather than in a screenshot. Also the fastest way to spot a component
/// that only looks right in light mode.
class DesignGallery extends StatefulWidget {
  const DesignGallery({super.key});

  @override
  State<DesignGallery> createState() => _DesignGalleryState();
}

class _DesignGalleryState extends State<DesignGallery> {
  bool _dark = false;
  int _tab = 0;
  bool _switchOn = true;
  bool _checked = false;
  String _ayanamsa = 'lahiri';
  int _chartStyle = 0;
  final Set<String> _selectedVargas = {'D9'};

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      home: Builder(builder: _buildGallery),
    );
  }

  Widget _buildGallery(BuildContext context) {
    final colors = context.colors;

    return AppScaffold(
      title: 'Design System',
      actions: [
        AppIconButton(
          icon: _dark ? Icons.light_mode : Icons.dark_mode,
          onPressed: () => setState(() => _dark = !_dark),
          tooltip: _dark ? 'Helles Design' : 'Dunkles Design',
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          _section('Farben'),
          _ColorGrid(colors: colors),
          _section('Typografie'),
          Text('Display Large',
              style: Theme.of(context).textTheme.displayLarge),
          Text('Title Large', style: Theme.of(context).textTheme.titleLarge),
          Text('Body Large — Der Aszendent steht im Löwen.',
              style: Theme.of(context).textTheme.bodyLarge),
          Text('Body Small — sekundärer Text',
              style: Theme.of(context).textTheme.bodySmall),
          const AppKeyValueRow(label: 'Tabellenziffern', value: '12°34′56″'),
          _section('Buttons'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppButton(label: 'Primär', onPressed: () {}),
              AppButton(
                label: 'Sekundär',
                variant: AppButtonVariant.secondary,
                onPressed: () {},
              ),
              AppButton(
                label: 'Tertiär',
                variant: AppButtonVariant.tertiary,
                onPressed: () {},
              ),
              AppButton(
                label: 'Löschen',
                variant: AppButtonVariant.destructive,
                icon: Icons.delete_outline,
                onPressed: () {},
              ),
              const AppButton(label: 'Deaktiviert', onPressed: null),
              AppButton(label: 'Lädt', isLoading: true, onPressed: () {}),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Auswertung kostenpflichtig bestellen — 11,00 €',
            isFullWidth: true,
            size: AppButtonSize.large,
            onPressed: () => AppSnackBar.show(
              context,
              message: 'Nur eine Demo — es wurde nichts bestellt.',
              tone: AppSnackTone.success,
            ),
          ),
          _section('Eingaben'),
          const AppTextField(
            label: 'Geburtsort',
            hint: 'z. B. München',
            helperText: 'Stadt und Land',
            isRequired: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppTextField(
            label: 'Geburtszeit',
            hint: 'HH:MM',
            errorText: 'Bitte eine gültige Uhrzeit eingeben',
          ),
          _section('Auswahl'),
          AppSegmentedControl<int>(
            segments: const [
              AppSegment(value: 0, label: 'Nord'),
              AppSegment(value: 1, label: 'Süd'),
              AppSegment(value: 2, label: 'Westlich'),
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
            groupLabel: 'Ayanamsa',
            options: const [
              AppRadioOption(
                value: 'lahiri',
                label: 'Lahiri',
                description: 'Chitrapaksha — Standard',
              ),
              AppRadioOption(value: 'raman', label: 'Raman'),
              AppRadioOption(value: 'kp', label: 'Krishnamurti'),
            ],
            value: _ayanamsa,
            onChanged: (v) => setState(() => _ayanamsa = v),
          ),
          AppSwitch(
            label: 'Tägliches Panchang',
            description: 'Benachrichtigung jeden Morgen um 7 Uhr',
            value: _switchOn,
            onChanged: (v) => setState(() => _switchOn = v),
          ),
          AppCheckbox(
            label: 'Ich stimme zu, dass die Auswertung sofort beginnt und '
                'mein Widerrufsrecht damit erlischt.',
            value: _checked,
            isRequired: true,
            onChanged: (v) => setState(() => _checked = v),
          ),
          _section('Status'),
          const Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppBadge(label: 'ENTWURF'),
              AppBadge(label: 'BEZAHLT', tone: AppBadgeTone.success),
              AppBadge(label: 'IN ARBEIT', tone: AppBadgeTone.info),
              AppBadge(label: 'SLA-RISIKO', tone: AppBadgeTone.warning),
              AppBadge(label: 'STORNIERT', tone: AppBadgeTone.danger),
              AppBadge(label: 'EXPERTE', tone: AppBadgeTone.accent),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppBanner(
            title: 'Lieferfrist',
            message: 'Deine Auswertung wird in bis zu 72 Stunden geliefert.',
          ),
          const SizedBox(height: AppSpacing.sm),
          const AppBanner(
            message: 'Zahlung fehlgeschlagen. Bitte Zahlungsart prüfen.',
            tone: AppBannerTone.danger,
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppStepper(
            currentStep: 2,
            totalSteps: 4,
            stepLabel: 'Geburtsort',
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppProgressBar(value: 0.62, label: 'PDF wird erstellt'),
          _section('Inhalte'),
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
                          Text('Astrologin · 128 Auswertungen',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const AppBadge(label: 'AKTIV', tone: AppBadgeTone.success),
                  ],
                ),
                const AppDivider(),
                const AppKeyValueRow(label: 'Aszendent', value: '5°12′ Löwe'),
                const AppKeyValueRow(label: 'Mond', value: '18°44′ Stier'),
                const AppKeyValueRow(
                  label: 'Mahadasha',
                  value: 'Venus bis 2031',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppListTile(
            title: 'Geburtsdaten bearbeiten',
            subtitle: '17.05.1990, 08:30, Berlin',
            leading: Icon(Icons.event, color: colors.onSurfaceVariant),
            trailing: Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            onTap: () {},
          ),
          _section('Ladezustände'),
          const AppSkeletonText(),
          _section('Leerzustände'),
          SizedBox(
            height: 260,
            child: AppEmptyState(
              title: 'Noch keine Kundali',
              message: 'Lege deine Geburtsdaten an, um dein Chart zu sehen.',
              actionLabel: 'Geburtsdaten eingeben',
              onAction: () {},
            ),
          ),
          SizedBox(
            height: 260,
            child: AppErrorState(
              title: 'Etwas ist schiefgelaufen',
              message: 'Die Auswertung konnte nicht geladen werden.',
              retryLabel: 'Erneut versuchen',
              onRetry: () {},
            ),
          ),
          _section('Overlays'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppButton(
                label: 'Dialog',
                variant: AppButtonVariant.secondary,
                onPressed: () => AppDialog.confirm(
                  context: context,
                  title: 'Bestellung stornieren?',
                  message: 'Die Auswertung wird nicht erstellt und du erhältst '
                      'den Betrag zurück.',
                  confirmLabel: 'Ja, stornieren',
                  cancelLabel: 'Abbrechen',
                  isDestructive: true,
                ),
              ),
              AppButton(
                label: 'Bottom Sheet',
                variant: AppButtonVariant.secondary,
                onPressed: () => AppBottomSheet.show<void>(
                  context: context,
                  title: 'Haussystem',
                  child: const AppRadioGroup<String>(
                    options: [
                      AppRadioOption(value: 'w', label: 'Ganzzeichen'),
                      AppRadioOption(value: 'p', label: 'Placidus'),
                    ],
                    value: 'w',
                    onChanged: null,
                  ),
                ),
              ),
              AppButton(
                label: 'Snackbar',
                variant: AppButtonVariant.secondary,
                onPressed: () => AppSnackBar.show(
                  context,
                  message: 'Gespeichert.',
                  tone: AppSnackTone.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
      bottomBar: AppBottomNav(
        destinations: const [
          AppNavDestination(
            icon: Icons.auto_awesome_outlined,
            selectedIcon: Icons.auto_awesome,
            label: 'Kundali',
          ),
          AppNavDestination(
            icon: Icons.work_outline,
            selectedIcon: Icons.work,
            label: 'Karriere',
          ),
          AppNavDestination(
            icon: Icons.article_outlined,
            selectedIcon: Icons.article,
            label: 'Auswertung',
          ),
          AppNavDestination(
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            label: 'Profil',
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
