import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish_app/core/design/design_system.dart';
import 'package:jyotish_app/core/l10n/generated/app_l10n.dart';
import 'package:jyotish_app/core/l10n/locale_controller.dart';
import 'package:jyotish_app/features/birth_data/gazetteer_loader.dart';
import 'package:jyotish_app/features/birth_data/place.dart';
import 'package:jyotish_app/features/birth_data/presentation/birth_place_field.dart';

/// The real gazetteer, read from disk.
///
/// The provider is overridden rather than letting the widget load the asset,
/// because `rootBundle` is not wired up in a plain widget test — but the data
/// is the shipped data, so these tests exercise real search results.
final gazetteer = Gazetteer.parse(
  utf8.decode(
      gzip.decode(File('assets/geo/gazetteer.tsv.gz').readAsBytesSync())),
);

Widget host({
  required ValueChanged<Place?> onSelected,
  Locale locale = const Locale('de', 'DE'),
}) {
  return ProviderScope(
    overrides: [gazetteerProvider.overrideWith((ref) async => gazetteer)],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: SingleChildScrollView(
          child: BirthPlaceField(onSelected: onSelected),
        ),
      ),
    ),
  );
}

Finder fieldWithLabel(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(AppTextField),
    );

void main() {
  group('US-021 AC1 — searching for a birthplace', () {
    testWidgets('typing a prefix offers matching places', (tester) async {
      await tester.pumpWidget(host(onSelected: (_) {}));
      await tester.pumpAndSettle();

      await tester.enterText(fieldWithLabel('Geburtsort'), 'Münc');
      await tester.pumpAndSettle();

      expect(find.text('München'), findsWidgets);
    });

    testWidgets('a German exonym finds the foreign city', (tester) async {
      await tester.pumpWidget(host(onSelected: (_) {}));
      await tester.pumpAndSettle();

      await tester.enterText(fieldWithLabel('Geburtsort'), 'Mailand');
      await tester.pumpAndSettle();

      expect(find.text('Mailand'), findsWidgets);
    });

    testWidgets('choosing a place reports it with coordinates and a zone',
        (tester) async {
      Place? chosen;
      await tester.pumpWidget(host(onSelected: (p) => chosen = p));
      await tester.pumpAndSettle();

      await tester.enterText(fieldWithLabel('Geburtsort'), 'München');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppListTile, 'München').first);
      await tester.pumpAndSettle();

      expect(chosen, isNotNull);
      expect(chosen!.countryCode, 'DE');
      expect(chosen!.latitude, closeTo(48.1374, 0.0001));
      expect(chosen!.timeZoneId, 'Europe/Berlin');
    });

    testWidgets('the country and timezone are shown before choosing',
        (tester) async {
      // Disambiguates the several Neustadts without making the user guess.
      await tester.pumpWidget(host(onSelected: (_) {}));
      await tester.pumpAndSettle();

      await tester.enterText(fieldWithLabel('Geburtsort'), 'München');
      await tester.pumpAndSettle();

      expect(find.textContaining('Europe/Berlin'), findsWidgets);
    });

    testWidgets('an unknown place says so rather than showing nothing',
        (tester) async {
      await tester.pumpWidget(host(onSelected: (_) {}));
      await tester.pumpAndSettle();

      await tester.enterText(fieldWithLabel('Geburtsort'), 'qqzzxxjj');
      await tester.pumpAndSettle();

      expect(find.text('Kein Ort gefunden'), findsOneWidget);
    });

    testWidgets('editing after a choice clears it', (tester) async {
      // Otherwise a stale selection outlives the text that produced it and the
      // chart is cast for wherever they first tapped.
      final reported = <Place?>[];
      await tester.pumpWidget(host(onSelected: reported.add));
      await tester.pumpAndSettle();

      await tester.enterText(fieldWithLabel('Geburtsort'), 'München');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppListTile, 'München').first);
      await tester.pumpAndSettle();
      expect(reported.last, isNotNull);

      await tester.enterText(fieldWithLabel('Geburtsort'), 'Berl');
      await tester.pumpAndSettle();
      expect(reported.last, isNull);
    });
  });

  group('US-021 AC4 — manual coordinates', () {
    Future<void> openManual(WidgetTester tester) async {
      await tester.tap(find.text('Ort nicht gefunden? Koordinaten eingeben'));
      await tester.pumpAndSettle();
    }

    testWidgets('the fallback is reachable from the search field',
        (tester) async {
      await tester.pumpWidget(host(onSelected: (_) {}));
      await tester.pumpAndSettle();
      await openManual(tester);

      expect(fieldWithLabel('Breite'), findsOneWidget);
      expect(fieldWithLabel('Länge'), findsOneWidget);
    });

    testWidgets('it explains where to find the numbers', (tester) async {
      // Asking for a latitude without saying how to get one is a refusal.
      await tester.pumpWidget(host(onSelected: (_) {}));
      await tester.pumpAndSettle();
      await openManual(tester);

      expect(find.textContaining('Karten-App'), findsOneWidget);
    });

    testWidgets('valid coordinates are reported', (tester) async {
      Place? chosen;
      await tester.pumpWidget(host(onSelected: (p) => chosen = p));
      await tester.pumpAndSettle();
      await openManual(tester);

      await tester.enterText(fieldWithLabel('Breite'), '48.1374');
      await tester.enterText(fieldWithLabel('Länge'), '11.5755');
      await tester.pumpAndSettle();

      expect(chosen, isNotNull);
      expect(chosen!.latitude, closeTo(48.1374, 1e-9));
      expect(chosen!.longitude, closeTo(11.5755, 1e-9));
    });

    testWidgets('a manual place carries no timezone, rather than a wrong one',
        (tester) async {
      // Defaulting to UTC would silently produce a chart an hour or more out.
      // US-022 resolves the zone; this field must not pretend to.
      Place? chosen;
      await tester.pumpWidget(host(onSelected: (p) => chosen = p));
      await tester.pumpAndSettle();
      await openManual(tester);

      await tester.enterText(fieldWithLabel('Breite'), '48.1374');
      await tester.enterText(fieldWithLabel('Länge'), '11.5755');
      await tester.pumpAndSettle();

      expect(chosen!.timeZoneId, isEmpty);
    });

    testWidgets('an out-of-range latitude is refused with its own message',
        (tester) async {
      Place? chosen;
      await tester.pumpWidget(host(onSelected: (p) => chosen = p));
      await tester.pumpAndSettle();
      await openManual(tester);

      await tester.enterText(fieldWithLabel('Breite'), '91');
      await tester.enterText(fieldWithLabel('Länge'), '11.5755');
      await tester.pumpAndSettle();

      expect(find.textContaining('-90 und 90'), findsOneWidget);
      expect(chosen, isNull);
    });

    testWidgets('a half-filled form is incomplete, not wrong', (tester) async {
      // No error while the second field is still empty.
      await tester.pumpWidget(host(onSelected: (_) {}));
      await tester.pumpAndSettle();
      await openManual(tester);

      await tester.enterText(fieldWithLabel('Breite'), '48.1374');
      await tester.pumpAndSettle();

      expect(find.textContaining('Bitte als Dezimalzahl'), findsNothing);
    });

    testWidgets('you can go back to searching', (tester) async {
      await tester.pumpWidget(host(onSelected: (_) {}));
      await tester.pumpAndSettle();
      await openManual(tester);

      await tester.tap(find.text('Stattdessen nach Ort suchen'));
      await tester.pumpAndSettle();

      expect(fieldWithLabel('Geburtsort'), findsOneWidget);
    });
  });

  group('US-021 — English', () {
    testWidgets('the field and the fallback are translated', (tester) async {
      await tester.pumpWidget(
        host(onSelected: (_) {}, locale: const Locale('en', 'GB')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Place of birth'), findsOneWidget);
      expect(find.text("Can't find it? Enter coordinates"), findsOneWidget);
    });
  });
}
