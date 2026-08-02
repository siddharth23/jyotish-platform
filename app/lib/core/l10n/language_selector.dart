import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/design_system.dart';
import 'generated/app_l10n.dart';
import 'locale_controller.dart';

/// Lets the user override the device language.
///
/// Each language is written in its own name — `Deutsch`, `English` — rather than
/// translated into the active locale. Someone who has landed in a language they
/// cannot read needs to recognise their own, and `Deutsch` is not recognisable to
/// them as `German`.
class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final selected = ref.watch(localeControllerProvider);

    return AppRadioGroup<LocalePreference>(
      groupLabel: l10n.settingsLanguage,
      value: selected,
      onChanged: (preference) =>
          ref.read(localeControllerProvider.notifier).select(preference),
      options: [
        AppRadioOption(
          value: LocalePreference.system,
          label: l10n.settingsLanguageSystem,
        ),
        AppRadioOption(
          value: LocalePreference.german,
          label: l10n.settingsLanguageGerman,
        ),
        AppRadioOption(
          value: LocalePreference.english,
          label: l10n.settingsLanguageEnglish,
        ),
      ],
    );
  }
}

/// A compact language toggle for an app bar.
///
/// Announces the language it will switch *to*, not the one currently active — a
/// control labelled with the current state reads as a statement rather than an
/// action.
class LanguageToggleButton extends ConsumerWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final isGerman = Localizations.localeOf(context).languageCode == 'de';

    return AppIconButton(
      icon: Icons.translate,
      tooltip:
          isGerman ? l10n.settingsLanguageEnglish : l10n.settingsLanguageGerman,
      onPressed: () => ref.read(localeControllerProvider.notifier).select(
            isGerman ? LocalePreference.english : LocalePreference.german,
          ),
    );
  }
}
