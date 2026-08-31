import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish_app/core/design/design_system.dart';
import 'package:jyotish_app/core/l10n/generated/app_l10n.dart';
import 'package:jyotish_app/core/l10n/locale_controller.dart';
import 'package:jyotish_app/features/birth_data/birth_details.dart';
import 'package:jyotish_app/features/birth_data/presentation/birth_data_screen.dart';

Widget host({
  ValueChanged<BirthDetails>? onSubmit,
  Locale locale = const Locale('de', 'DE'),
}) {
  return MaterialApp(
    theme: AppTheme.light,
    locale: locale,
    supportedLocales: supportedLocales,
    localizationsDelegates: const [
      AppL10n.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: BirthDataScreen(onSubmit: onSubmit),
  );
}

Finder fieldWithLabel(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(AppTextField),
    );

/// Scrolls the action into view before tapping it.
///
/// The screen is a ListView, so the target may be both below the fold and not
/// yet built — a lazy list only builds what is near the viewport, and
/// `find.text` cannot see an unbuilt widget. Scroll first, then tap.
Future<void> tapAction(WidgetTester tester, String label) async {
  final target = find.text(label);
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(target, 120,
        scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  group('US-020 AC1 — the German formats are what the screen asks for', () {
    testWidgets('the date hint is TT.MM.JJJJ', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(find.text('TT.MM.JJJJ'), findsOneWidget);
    });

    testWidgets(
        'the time helper names the 24-hour convention with an evening example',
        (tester) async {
      // "19:45" is the load-bearing part: someone who would have typed 7:45
      // for a quarter to eight in the evening sees the right form first.
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(find.textContaining('24-Stunden'), findsOneWidget);
      expect(find.textContaining('19:45'), findsOneWidget);
    });

    testWidgets('a valid entry submits the parsed details', (tester) async {
      BirthDetails? submitted;
      await tester.pumpWidget(host(onSubmit: (d) => submitted = d));
      await tester.pumpAndSettle();

      await tester.enterText(fieldWithLabel('Geburtsdatum'), '17.05.1990');
      await tester.enterText(fieldWithLabel('Geburtszeit'), '07:30');
      await tapAction(tester, 'Weiter');

      expect(submitted, isNotNull);
      expect(submitted!.date, const BirthDate(1990, 5, 17));
      expect(submitted!.time, const BirthTime(7, 30));
      expect(submitted!.precision, BirthTimePrecision.exact);
    });

    testWidgets('slashes cannot even be typed into the date field',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.enterText(fieldWithLabel('Geburtsdatum'), '17/05/1990');
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.descendant(
          of: fieldWithLabel('Geburtsdatum'),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, '17051990');
    });
  });

  group('US-020 AC3 — invalid dates are refused with a usable message', () {
    testWidgets('31 April is named as a date that does not exist',
        (tester) async {
      BirthDetails? submitted;
      await tester.pumpWidget(host(onSubmit: (d) => submitted = d));
      await tester.pumpAndSettle();

      await tester.enterText(fieldWithLabel('Geburtsdatum'), '31.04.2000');
      await tester.enterText(fieldWithLabel('Geburtszeit'), '07:30');
      await tapAction(tester, 'Weiter');

      expect(find.text('Dieses Datum gibt es nicht'), findsOneWidget);
      expect(submitted, isNull, reason: 'nothing may be submitted');
    });

    testWidgets('a future date is refused', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final nextYear = DateTime.now().year + 1;
      await tester.enterText(fieldWithLabel('Geburtsdatum'), '01.01.$nextYear');
      await tester.enterText(fieldWithLabel('Geburtszeit'), '07:30');
      await tapAction(tester, 'Weiter');

      expect(find.textContaining('Zukunft'), findsOneWidget);
    });

    testWidgets('a year before 1800 is refused', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.enterText(fieldWithLabel('Geburtsdatum'), '01.01.1799');
      await tester.enterText(fieldWithLabel('Geburtszeit'), '07:30');
      await tapAction(tester, 'Weiter');

      expect(find.textContaining('1800'), findsOneWidget);
    });

    testWidgets('both fields report at once, not one after the other',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.enterText(fieldWithLabel('Geburtsdatum'), '99.99.1990');
      await tester.enterText(fieldWithLabel('Geburtszeit'), '99:99');
      await tapAction(tester, 'Weiter');

      expect(find.text('Dieses Datum gibt es nicht'), findsOneWidget);
      expect(find.textContaining('00:00 und 23:59'), findsOneWidget);
    });

    testWidgets('the error clears as soon as the field changes',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.enterText(fieldWithLabel('Geburtsdatum'), '31.04.2000');
      await tapAction(tester, 'Weiter');
      expect(find.text('Dieses Datum gibt es nicht'), findsOneWidget);

      await tester.enterText(fieldWithLabel('Geburtsdatum'), '30.04.2000');
      await tester.pumpAndSettle();
      expect(find.text('Dieses Datum gibt es nicht'), findsNothing);
    });

    testWidgets('an empty form does not submit', (tester) async {
      BirthDetails? submitted;
      await tester.pumpWidget(host(onSubmit: (d) => submitted = d));
      await tester.pumpAndSettle();

      await tapAction(tester, 'Weiter');
      expect(submitted, isNull);
    });
  });

  group('US-020 AC2 — time unknown means a solar chart, and says so', () {
    testWidgets('the caveat replaces the time field', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(fieldWithLabel('Geburtszeit'), findsOneWidget);

      await tapAction(tester, 'Geburtszeit unbekannt');

      expect(fieldWithLabel('Geburtszeit'), findsNothing);
      expect(find.textContaining('Sonnenhoroskop'), findsWidgets);
    });

    testWidgets('the caveat says what is lost, not that it is less precise',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tapAction(tester, 'Geburtszeit unbekannt');

      final caveat = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.contains('Aszendenten') ?? false),
        ),
      );
      expect(caveat.data, contains('Häuser'));
    });

    testWidgets('submitting without a time yields unknown precision',
        (tester) async {
      BirthDetails? submitted;
      await tester.pumpWidget(host(onSubmit: (d) => submitted = d));
      await tester.pumpAndSettle();

      await tester.enterText(fieldWithLabel('Geburtsdatum'), '17.05.1990');
      await tapAction(tester, 'Geburtszeit unbekannt');
      await tapAction(tester, 'Weiter');

      expect(submitted, isNotNull);
      expect(submitted!.time, isNull);
      expect(submitted!.needsSolarChartFallback, isTrue);
    });

    testWidgets('a stale time error does not block submission once hidden',
        (tester) async {
      // Enter a bad time, fail, then say the time is unknown. The error is
      // now behind a hidden field; leaving it set would block the user with a
      // message they cannot see or fix.
      BirthDetails? submitted;
      await tester.pumpWidget(host(onSubmit: (d) => submitted = d));
      await tester.pumpAndSettle();

      await tester.enterText(fieldWithLabel('Geburtsdatum'), '17.05.1990');
      await tester.enterText(fieldWithLabel('Geburtszeit'), '99:99');
      await tapAction(tester, 'Weiter');
      expect(submitted, isNull);

      await tapAction(tester, 'Geburtszeit unbekannt');
      await tapAction(tester, 'Weiter');

      expect(submitted, isNotNull);
    });
  });

  group('US-020 AC4 — the explanation is inline', () {
    testWidgets('it is on the screen without opening anything', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(find.text('Warum die genaue Minute zählt'), findsOneWidget);
    });

    testWidgets('it gives the mechanism and a concrete next step',
        (tester) async {
      // "Precision is important" tells the user nothing they can act on.
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.contains('Aszendent') ?? false),
        ),
      );
      expect(text.data, contains('Häuser'));
      expect(text.data, contains('Geburtsurkunde'));
    });

    testWidgets('it is hidden when the time is unknown', (tester) async {
      // There is nothing to be precise about any more, and the caveat has
      // taken over the job of explaining the consequence.
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tapAction(tester, 'Geburtszeit unbekannt');

      expect(find.text('Warum die genaue Minute zählt'), findsNothing);
    });

    testWidgets('English says the same things', (tester) async {
      await tester.pumpWidget(host(locale: const Locale('en', 'GB')));
      await tester.pumpAndSettle();

      expect(find.text('Why the exact minute matters'), findsOneWidget);
      expect(find.text('DD.MM.YYYY'), findsOneWidget);
      expect(find.textContaining('24-hour'), findsOneWidget);
    });
  });

  group('US-020 — the screen survives long German at large text sizes', () {
    // German runs about 30% longer than English and this screen is mostly
    // prose. A RenderFlex overflow throws in tests, so takeException catches
    // exactly the failure this guards against.
    for (final scale in [1.0, 2.0]) {
      testWidgets('no overflow on a narrow screen at ${scale}x text',
          (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: host(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);

        // And with the caveat banner showing, which is the longest string.
        await tapAction(tester, 'Geburtszeit unbekannt');
        expect(tester.takeException(), isNull);
      });
    }
  });
}
