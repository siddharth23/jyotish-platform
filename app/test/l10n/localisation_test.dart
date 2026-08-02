import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish_app/core/design/design_system.dart';
import 'package:jyotish_app/core/l10n/app_formats.dart';
import 'package:jyotish_app/core/l10n/generated/app_l10n.dart';
import 'package:jyotish_app/core/l10n/locale_controller.dart';

Widget host(Widget child, {Locale locale = const Locale('de', 'DE')}) =>
    MaterialApp(
      theme: AppTheme.light,
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: Center(child: SizedBox(width: 360, child: child))),
    );

Map<String, dynamic> _arb(String locale) => jsonDecode(
      File('lib/core/l10n/arb/app_$locale.arb').readAsStringSync(),
    ) as Map<String, dynamic>;

void main() {
  group('AC1 — no hardcoded strings', () {
    test('the design system contains no German literals', () {
      // Components must resolve their accessibility strings from context; a
      // literal here would be announced in German to an English user.
      final offenders = <String>[];
      final german = RegExp(
        r"'[^']*(Wird geladen|Pflichtfeld|Schritt \$|Schließen|Abbrechen|"
        r"Erneut versuchen|Entfernen)[^']*'",
      );
      for (final file in Directory('lib/core/design')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        // The gallery is a demo surface and resolves everything via AppL10n;
        // the ARB files are the strings themselves.
        if (file.path.contains('/arb/')) continue;
        final content = file.readAsStringSync();
        if (german.hasMatch(content)) offenders.add(file.path);
      }
      expect(offenders, isEmpty,
          reason: 'German literals found in: $offenders');
    });

    test('every German key has an English translation', () {
      final de = _arb('de').keys.where((k) => !k.startsWith('@')).toSet();
      final en = _arb('en').keys.where((k) => !k.startsWith('@')).toSet();
      expect(
        de.difference(en),
        isEmpty,
        reason: 'Untranslated keys — these would fall back to German',
      );
    });

    test('English adds no keys the template does not define', () {
      final de = _arb('de').keys.where((k) => !k.startsWith('@')).toSet();
      final en = _arb('en').keys.where((k) => !k.startsWith('@')).toSet();
      expect(
        en.difference(de),
        isEmpty,
        reason: 'Orphan English keys — German is the template',
      );
    });
  });

  group('AC1 — ICU plurals', () {
    testWidgets('German plural forms', (tester) async {
      late AppL10n l10n;
      await tester.pumpWidget(host(Builder(builder: (c) {
        l10n = AppL10n.of(c);
        return const SizedBox();
      })));
      expect(l10n.evaluationCount(0), 'Keine Auswertungen');
      expect(l10n.evaluationCount(1), 'Eine Auswertung');
      expect(l10n.evaluationCount(7), '7 Auswertungen');
    });

    testWidgets('English plural forms', (tester) async {
      late AppL10n l10n;
      await tester.pumpWidget(host(
        Builder(builder: (c) {
          l10n = AppL10n.of(c);
          return const SizedBox();
        }),
        locale: const Locale('en', 'GB'),
      ));
      expect(l10n.evaluationCount(0), 'No evaluations');
      expect(l10n.evaluationCount(1), 'One evaluation');
      expect(l10n.evaluationCount(7), '7 evaluations');
    });

    testWidgets('the SLA countdown pluralises in both locales', (tester) async {
      for (final (locale, zero, one) in [
        (const Locale('de', 'DE'), 'Heute fällig', 'Noch ein Tag'),
        (const Locale('en', 'GB'), 'Due today', 'One day left'),
      ]) {
        late AppL10n l10n;
        await tester.pumpWidget(host(
          Builder(builder: (c) {
            l10n = AppL10n.of(c);
            return const SizedBox();
          }),
          locale: locale,
        ));
        expect(l10n.daysRemaining(0), zero);
        expect(l10n.daysRemaining(1), one);
      }
    });
  });

  group('AC2 — German formatting conventions', () {
    /// Runs [body] inside a tree whose active locale is [locale].
    ///
    /// The assertions have to happen while that tree is mounted. Capturing a
    /// BuildContext and pumping a second locale leaves the first context
    /// defunct, and every lookup then silently answers for the newer tree.
    Future<void> inLocale(
      WidgetTester tester,
      Locale locale,
      void Function(BuildContext context) body,
    ) async {
      await tester.pumpWidget(host(
        Builder(builder: (context) {
          body(context);
          return const SizedBox();
        }),
        locale: locale,
      ));
    }

    testWidgets('dates are day-first in German, and differ from English',
        (tester) async {
      final date = DateTime(1990, 5, 17);
      await inLocale(tester, const Locale('de', 'DE'), (context) {
        // DD.MM.YYYY exactly, zero-padded — not intl's idiomatic short form,
        // which drops the leading zero and yields 17.5.1990.
        expect(AppFormats.date(context, date), '17.05.1990');
      });
      await inLocale(tester, const Locale('en', 'GB'), (context) {
        // en-GB is day-first too, but with slashes. Declaring the locale as a
        // bare 'en' silently yields US order — 'May 17, 1990' — so this pins
        // the region, not just the language.
        expect(AppFormats.date(context, date), '17/05/1990');
      });
    });

    testWidgets('long dates use the localised month name', (tester) async {
      final date = DateTime(1990, 5, 17);
      await inLocale(tester, const Locale('de', 'DE'), (context) {
        expect(AppFormats.longDate(context, date), contains('Mai'));
      });
      await inLocale(tester, const Locale('en', 'GB'), (context) {
        expect(AppFormats.longDate(context, date), contains('May'));
      });
    });

    testWidgets('times are 24-hour in both locales', (tester) async {
      // A birth time must never be am/pm ambiguous: twelve hours of error moves
      // the ascendant by about six signs.
      final evening = DateTime(1990, 5, 17, 20, 30);
      for (final locale in supportedLocales) {
        await inLocale(tester, locale, (context) {
          final formatted = AppFormats.time(context, evening);
          expect(formatted, contains('20'), reason: '$locale: $formatted');
          expect(formatted.toLowerCase(), isNot(contains('pm')));
        });
      }
    });

    testWidgets('German uses a comma decimal separator', (tester) async {
      await inLocale(tester, const Locale('de', 'DE'), (context) {
        expect(AppFormats.number(context, 3.5), '3,5');
      });
      await inLocale(tester, const Locale('en', 'GB'), (context) {
        expect(AppFormats.number(context, 3.5), '3.5');
      });
    });

    testWidgets('the euro price reads 11,00 € in German', (tester) async {
      await inLocale(tester, const Locale('de', 'DE'), (context) {
        final german = AppFormats.euro(context, 11);
        expect(german, contains('11,00'), reason: german);
        // Symbol trails the amount in German.
        expect(german.trim().endsWith('€'), isTrue, reason: german);
      });
      await inLocale(tester, const Locale('en', 'GB'), (context) {
        final english = AppFormats.euro(context, 11);
        expect(english, contains('11.00'), reason: english);
        expect(english.trim().startsWith('€'), isTrue, reason: english);
      });
    });

    test('arc notation is locale-independent and carries rounding', () {
      expect(AppFormats.arc(5.21), '5°12′36″');
      expect(AppFormats.arc(0), '0°00′00″');
      // 59′59.6″ must carry to the next degree rather than print 60″.
      expect(AppFormats.arc(5.999999), '6°00′00″');
      expect(AppFormats.arc(-5.21), startsWith('-'));
    });
  });

  group('AC3 — device locale with in-app override', () {
    test('system preference resolves to no forced locale', () {
      expect(LocalePreference.system.locale, isNull);
      expect(LocalePreference.german.locale, const Locale('de', 'DE'));
      expect(LocalePreference.english.locale, const Locale('en', 'GB'));
    });

    test('stored values round-trip', () {
      for (final preference in LocalePreference.values) {
        expect(
          LocalePreference.fromStorage(preference.storageValue),
          preference,
        );
      }
    });

    test('an unknown stored value falls back to following the device', () {
      expect(LocalePreference.fromStorage('fr'), LocalePreference.system);
      expect(LocalePreference.fromStorage(null), LocalePreference.system);
    });

    test('German is the first supported locale, so it is the fallback', () {
      // Flutter resolves an unmatched device locale to the first entry.
      expect(supportedLocales.first, const Locale('de', 'DE'));
    });

    testWidgets('switching locale re-renders every string', (tester) async {
      await tester
          .pumpWidget(host(const AppStepper(currentStep: 2, totalSteps: 4)));
      expect(find.textContaining('Schritt 2 von 4'), findsOneWidget);

      await tester.pumpWidget(host(
        const AppStepper(currentStep: 2, totalSteps: 4),
        locale: const Locale('en', 'GB'),
      ));
      expect(find.textContaining('Step 2 of 4'), findsOneWidget);
      expect(find.textContaining('Schritt'), findsNothing);
    });
  });

  group('AC4 — pseudo-localisation for overflow', () {
    // German runs about 30% longer than English. Rather than trust that, every
    // component is rendered with strings inflated well past that margin, in a
    // narrow viewport, and asserted not to overflow. A RenderFlex overflow
    // throws in tests, so takeException catches exactly the failure this guards.
    String pseudo(String base, double factor) {
      final target = (base.length * factor).ceil();
      final buffer = StringBuffer();
      while (buffer.length < target) {
        buffer.write(base);
        buffer.write(' ');
      }
      return buffer.toString().trim();
    }

    Future<void> expectNoOverflow(
      WidgetTester tester,
      String label,
      Widget widget,
    ) async {
      await tester.pumpWidget(host(widget));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull, reason: '$label overflowed');
    }

    for (final factor in [1.3, 2.0, 3.0]) {
      testWidgets('components survive ${factor}x string length',
          (tester) async {
        final long = pseudo('Widerrufsbelehrung', factor);

        await expectNoOverflow(
          tester,
          'AppButton',
          AppButton(label: long, onPressed: () {}),
        );
        await expectNoOverflow(
          tester,
          'AppButton full width',
          AppButton(label: long, isFullWidth: true, onPressed: () {}),
        );
        await expectNoOverflow(
          tester,
          'AppChip',
          Align(alignment: Alignment.centerLeft, child: AppChip(label: long)),
        );
        await expectNoOverflow(
          tester,
          'AppListTile',
          AppListTile(title: long, subtitle: long),
        );
        await expectNoOverflow(
          tester,
          'AppCheckbox',
          AppCheckbox(label: long, value: false, onChanged: (_) {}),
        );
        await expectNoOverflow(
          tester,
          'AppSwitch',
          AppSwitch(
              label: long, description: long, value: true, onChanged: (_) {}),
        );
        await expectNoOverflow(
          tester,
          'AppBanner',
          AppBanner(title: long, message: long),
        );
        await expectNoOverflow(
          tester,
          'AppKeyValueRow',
          AppKeyValueRow(label: long, value: long, isNumeric: false),
        );
        await expectNoOverflow(
          tester,
          'AppSectionHeader',
          AppSectionHeader(title: long, subtitle: long),
        );
        await expectNoOverflow(
          tester,
          'AppSegmentedControl',
          AppSegmentedControl<int>(
            segments: [
              AppSegment(value: 0, label: long),
              AppSegment(value: 1, label: long),
            ],
            value: 0,
            onChanged: (_) {},
          ),
        );
        await expectNoOverflow(
          tester,
          'AppBottomNav',
          AppBottomNav(
            destinations: [
              for (var i = 0; i < 4; i++)
                AppNavDestination(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: long,
                ),
            ],
            currentIndex: 0,
            onSelected: (_) {},
          ),
        );
        await expectNoOverflow(
          tester,
          'AppRadioGroup',
          AppRadioGroup<int>(
            groupLabel: long,
            options: [AppRadioOption(value: 0, label: long, description: long)],
            value: 0,
            onChanged: (_) {},
          ),
        );
      });
    }

    testWidgets('long strings survive 2x text scale as well', (tester) async {
      // Inflated copy and large-text accessibility settings compound.
      final long = pseudo('Widerrufsbelehrung', 2.0);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('de', 'DE'),
          supportedLocales: supportedLocales,
          localizationsDelegates: const [
            AppL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  child: AppButton(label: long, onPressed: () {}),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });
  });

  group('Design system components speak the active locale', () {
    testWidgets('required-field marker', (tester) async {
      await tester.pumpWidget(host(
        const AppTextField(label: 'Geburtsort', isRequired: true),
        locale: const Locale('en', 'GB'),
      ));
      final semantics = tester.widget<Semantics>(
        find
            .ancestor(of: find.text('*'), matching: find.byType(Semantics))
            .first,
      );
      expect(semantics.properties.label, 'Required field');
    });

    testWidgets('loading hint', (tester) async {
      for (final (locale, expected) in [
        (const Locale('de', 'DE'), 'Wird geladen'),
        (const Locale('en', 'GB'), 'Loading'),
      ]) {
        await tester.pumpWidget(host(
          AppButton(label: 'x', isLoading: true, onPressed: () {}),
          locale: locale,
        ));
        final semantics = tester.widget<Semantics>(
          find
              .descendant(
                of: find.byType(AppButton),
                matching: find.byType(Semantics),
              )
              .first,
        );
        expect(semantics.properties.hint, expected);
      }
    });
  });
}
