import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish_app/core/design/design_system.dart';
import 'package:jyotish_app/core/l10n/generated/app_l10n.dart';
import 'package:jyotish_app/core/l10n/locale_controller.dart';

/// Mirrors the real app: components resolve their accessibility strings from
/// context, so the localisation delegates are not optional here.
Widget host(
  Widget child, {
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('de', 'DE'),
}) =>
    MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
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

void main() {
  group('AppButton', () {
    testWidgets('fires onPressed when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(AppButton(label: 'Weiter', onPressed: () => taps++)),
      );
      await tester.tap(find.byType(AppButton));
      expect(taps, 1);
    });

    testWidgets('does nothing when disabled', (tester) async {
      await tester
          .pumpWidget(host(const AppButton(label: 'Weiter', onPressed: null)));
      await tester.tap(find.byType(AppButton), warnIfMissed: false);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ignores taps while loading', (tester) async {
      // Otherwise a double-tap submits a paid order twice.
      var taps = 0;
      await tester.pumpWidget(
        host(AppButton(
            label: 'Bestellen', isLoading: true, onPressed: () => taps++)),
      );
      await tester.tap(find.byType(AppButton), warnIfMissed: false);
      expect(taps, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('hides its label while loading', (tester) async {
      await tester.pumpWidget(
        host(AppButton(label: 'Bestellen', isLoading: true, onPressed: () {})),
      );
      expect(find.text('Bestellen'), findsNothing);
    });

    testWidgets('wraps a long German label instead of truncating it',
        (tester) async {
      // 'Auswertung kostenpflichtig bestellen' must not become 'Auswertung k…'
      const label = 'Auswertung kostenpflichtig bestellen';
      await tester.pumpWidget(
        host(SizedBox(
            width: 200, child: AppButton(label: label, onPressed: () {}))),
      );
      final text = tester.widget<Text>(find.text(label));
      expect(text.maxLines, 2);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in both themes without error', (tester) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          host(AppButton(label: 'Weiter', onPressed: () {}),
              brightness: brightness),
        );
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('AppTextField', () {
    testWidgets('a long required label does not overflow at 2x text',
        (tester) async {
      // The label Row holds the label and the required marker. Without a
      // Flexible around the label, a long German label at a large text scale
      // pushes the marker off the right edge and throws. Found by US-020's
      // "Geburtsdatum" field on a 320pt screen.
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: host(const AppTextField(
            label: 'Geburtsdatum der zu bewertenden Person',
            isRequired: true,
          )),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows helper text when there is no error', (tester) async {
      await tester.pumpWidget(
        host(const AppTextField(
            label: 'Geburtsort', helperText: 'Stadt eingeben')),
      );
      expect(find.text('Stadt eingeben'), findsOneWidget);
    });

    testWidgets('error text replaces helper text', (tester) async {
      await tester.pumpWidget(
        host(const AppTextField(
          label: 'Geburtsort',
          helperText: 'Stadt eingeben',
          errorText: 'Ort nicht gefunden',
        )),
      );
      expect(find.text('Ort nicht gefunden'), findsOneWidget);
      expect(find.text('Stadt eingeben'), findsNothing);
    });

    testWidgets('the error is a live region so it is announced',
        (tester) async {
      await tester.pumpWidget(
        host(const AppTextField(
            label: 'Geburtsort', errorText: 'Ort nicht gefunden')),
      );
      final semantics = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.text('Ort nicht gefunden'),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(semantics.properties.liveRegion, isTrue);
    });

    testWidgets('reports typing', (tester) async {
      String? seen;
      await tester.pumpWidget(
        host(AppTextField(label: 'Geburtsort', onChanged: (v) => seen = v)),
      );
      await tester.enterText(find.byType(TextField), 'München');
      expect(seen, 'München');
    });
  });

  group('AppAvatar', () {
    test('derives initials from first and last name', () {
      expect(AppAvatar.initialsOf('Siddharth Kala'), 'SK');
      expect(AppAvatar.initialsOf('Anna Maria Schmidt'), 'AS');
      expect(AppAvatar.initialsOf('Prince'), 'P');
    });

    test('handles messy input rather than crashing', () {
      expect(AppAvatar.initialsOf('   '), '?');
      expect(AppAvatar.initialsOf(''), '?');
      expect(AppAvatar.initialsOf('  Ravi   Shankar  '), 'RS');
    });

    test('handles non-ASCII names', () {
      expect(AppAvatar.initialsOf('Ömer Çelik'), 'ÖÇ');
    });

    testWidgets('announces the full name, not the initials', (tester) async {
      await tester.pumpWidget(host(const AppAvatar(name: 'Siddharth Kala')));
      final semantics = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byType(Container).first,
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(semantics.properties.label, 'Siddharth Kala');
    });
  });

  group('AppChip', () {
    testWidgets('selected state is not carried by colour alone',
        (tester) async {
      // A check glyph appears as well, for greyscale and colour-blind users.
      await tester.pumpWidget(
          host(AppChip(label: 'D9', isSelected: true, onTap: () {})));
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.pumpWidget(host(AppChip(label: 'D9', onTap: () {})));
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('a deletable chip must supply a tooltip', (tester) async {
      await tester.pumpWidget(
        host(
            AppChip(label: 'D9', onDeleted: () {}, deleteTooltip: 'Entfernen')),
      );
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });

  group('AppProgressBar', () {
    testWidgets('announces its percentage', (tester) async {
      await tester.pumpWidget(host(const AppProgressBar(value: 0.42)));
      final semantics = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(AppProgressBar),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(semantics.properties.label, contains('42'));
    });

    testWidgets('clamps values outside 0 to 1', (tester) async {
      for (final value in [-1.0, 2.0]) {
        await tester.pumpWidget(host(AppProgressBar(value: value)));
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('AppStepper', () {
    testWidgets('states the position as text, not just as bars',
        (tester) async {
      await tester.pumpWidget(
        host(const AppStepper(
            currentStep: 2, totalSteps: 4, stepLabel: 'Geburtsort')),
      );
      expect(find.textContaining('Schritt 2 von 4'), findsOneWidget);
    });
  });

  group('AppBanner', () {
    testWidgets('pairs an icon with every tone', (tester) async {
      for (final tone in AppBannerTone.values) {
        await tester
            .pumpWidget(host(AppBanner(message: 'Hinweis', tone: tone)));
        expect(find.byType(Icon), findsWidgets, reason: tone.name);
      }
    });

    testWidgets('danger is a live region', (tester) async {
      await tester.pumpWidget(
        host(const AppBanner(message: 'Fehler', tone: AppBannerTone.danger)),
      );
      final semantics = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(AppBanner),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(semantics.properties.liveRegion, isTrue);
    });
  });

  group('AppEmptyState and AppErrorState', () {
    testWidgets('empty state offers a way forward when given one',
        (tester) async {
      var acted = 0;
      await tester.pumpWidget(
        host(AppEmptyState(
          title: 'Keine Kundalis',
          message: 'Lege deine erste Kundali an.',
          actionLabel: 'Anlegen',
          onAction: () => acted++,
        )),
      );
      await tester.tap(find.byType(AppButton));
      expect(acted, 1);
    });

    testWidgets('error state retries', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        host(AppErrorState(
          title: 'Fehler',
          message: 'Netzwerkfehler.',
          retryLabel: 'Erneut versuchen',
          onRetry: () => retried++,
        )),
      );
      await tester.tap(find.byType(AppButton));
      expect(retried, 1);
    });
  });

  group('Selection controls', () {
    testWidgets('AppSwitch toggles from the label, not just the thumb',
        (tester) async {
      bool? next;
      await tester.pumpWidget(
        host(AppSwitch(
          label: 'Tägliches Panchang',
          value: false,
          onChanged: (v) => next = v,
        )),
      );
      await tester.tap(find.text('Tägliches Panchang'));
      expect(next, isTrue);
    });

    testWidgets('AppCheckbox toggles from its label', (tester) async {
      bool? next;
      await tester.pumpWidget(
        host(AppCheckbox(
          label: 'Ich stimme den AGB zu',
          value: false,
          onChanged: (v) => next = v,
        )),
      );
      await tester.tap(find.text('Ich stimme den AGB zu'));
      expect(next, isTrue);
    });

    testWidgets('AppRadioGroup reports the chosen option', (tester) async {
      String? chosen;
      await tester.pumpWidget(
        host(AppRadioGroup<String>(
          options: const [
            AppRadioOption(value: 'lahiri', label: 'Lahiri'),
            AppRadioOption(value: 'raman', label: 'Raman'),
          ],
          value: 'lahiri',
          onChanged: (v) => chosen = v,
        )),
      );
      await tester.tap(find.text('Raman'));
      expect(chosen, 'raman');
    });

    testWidgets('a disabled AppRadioGroup ignores taps', (tester) async {
      await tester.pumpWidget(
        host(const AppRadioGroup<String>(
          options: [AppRadioOption(value: 'lahiri', label: 'Lahiri')],
          value: 'lahiri',
          onChanged: null,
        )),
      );
      await tester.tap(find.text('Lahiri'), warnIfMissed: false);
      expect(tester.takeException(), isNull);
    });
  });

  group('Every component renders in both themes', () {
    final samples = <String, Widget>{
      'AppBadge': const AppBadge(label: 'BEZAHLT', tone: AppBadgeTone.success),
      'AppCard': const AppCard(child: Text('x')),
      'AppDivider': const AppDivider(),
      'AppKeyValueRow':
          const AppKeyValueRow(label: 'Aszendent', value: '5°12′ Löwe'),
      'AppListTile':
          const AppListTile(title: 'Geburtsdatum', subtitle: '17.05.1990'),
      'AppSectionHeader': const AppSectionHeader(title: 'Grahas'),
      'AppSkeletonText': const AppSkeletonText(),
      'AppProgressIndicator': const AppProgressIndicator(),
      'AppAvatar': const AppAvatar(name: 'Anna Schmidt'),
      'AppStepper': const AppStepper(currentStep: 1, totalSteps: 3),
      'AppBanner': const AppBanner(message: 'Hinweis'),
    };

    for (final entry in samples.entries) {
      for (final brightness in Brightness.values) {
        testWidgets('${entry.key} in ${brightness.name}', (tester) async {
          await tester.pumpWidget(host(entry.value, brightness: brightness));
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
