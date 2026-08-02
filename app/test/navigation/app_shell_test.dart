import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish_app/core/connectivity/connectivity_controller.dart';
import 'package:jyotish_app/core/design/design_system.dart';
import 'package:jyotish_app/core/l10n/generated/app_l10n.dart';
import 'package:jyotish_app/core/l10n/locale_controller.dart';
import 'package:jyotish_app/core/navigation/app_router.dart';
import 'package:jyotish_app/core/navigation/app_routes.dart';
import 'package:jyotish_app/features/career/presentation/career_screen.dart';
import 'package:jyotish_app/features/chart/presentation/chart_screen.dart';
import 'package:jyotish_app/features/evaluation/presentation/evaluation_detail_screen.dart';
import 'package:jyotish_app/features/evaluation/presentation/evaluation_screen.dart';
import 'package:jyotish_app/features/home/presentation/home_screen.dart';
import 'package:jyotish_app/features/profile/presentation/profile_screen.dart';

/// Boots the real router at [location].
Widget app({
  String location = AppRoutes.home,
  NetworkStatus network = NetworkStatus.online,
}) {
  return ProviderScope(
    overrides: [
      // The real controller reaches for a platform channel that does not exist
      // in a widget test.
      connectivityControllerProvider.overrideWith(
        (ref) => ConnectivityController.fixed(network),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: createRouter(initialLocation: location),
      locale: const Locale('de', 'DE'),
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
}

void main() {
  group('AC1 — the five bottom tabs', () {
    testWidgets('all five are present, in order', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.byType(AppBottomNav), findsOneWidget);
      final nav = tester.widget<AppBottomNav>(find.byType(AppBottomNav));
      expect(
        nav.destinations.map((d) => d.label).toList(),
        ['Start', 'Kundali', 'Karriere', 'Auswertung', 'Profil'],
      );
    });

    testWidgets('each tab shows its own screen', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);

      for (final (label, matcher) in [
        ('Kundali', isA<ChartScreen>()),
        ('Karriere', isA<CareerScreen>()),
        ('Auswertung', isA<EvaluationScreen>()),
        ('Profil', isA<ProfileScreen>()),
      ]) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(
          tester.widgetList(
              find.byWidgetPredicate((w) => matcher.matches(w, {}))),
          isNotEmpty,
          reason: 'tapping $label did not show its screen',
        );
      }
    });

    testWidgets('tabs keep their own state across switches', (tester) async {
      // An indexed stack, so leaving a tab and returning must not rebuild it
      // from scratch. Otherwise a half-filled birth-data form is lost by a
      // stray tab tap.
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      // Still in the tree, just not visible: that is what preserves its state.
      expect(find.byType(ProfileScreen, skipOffstage: false), findsOneWidget);
    });
  });

  group('AC2 — deep links resolve', () {
    for (final (location, matcher) in [
      (AppRoutes.home, isA<HomeScreen>()),
      (AppRoutes.chart, isA<ChartScreen>()),
      (AppRoutes.career, isA<CareerScreen>()),
      (AppRoutes.evaluation, isA<EvaluationScreen>()),
      (AppRoutes.profile, isA<ProfileScreen>()),
    ]) {
      testWidgets('$location opens its screen', (tester) async {
        await tester.pumpWidget(app(location: location));
        await tester.pumpAndSettle();
        expect(
          tester.widgetList(
              find.byWidgetPredicate((w) => matcher.matches(w, {}))),
          isNotEmpty,
        );
      });
    }

    testWidgets('a link opens the right tab, not just the right screen',
        (tester) async {
      await tester.pumpWidget(app(location: AppRoutes.career));
      await tester.pumpAndSettle();
      final nav = tester.widget<AppBottomNav>(find.byType(AppBottomNav));
      expect(nav.currentIndex, AppRoutes.tabs.indexOf(AppRoutes.career));
    });

    testWidgets('an evaluation link carries its order id', (tester) async {
      await tester
          .pumpWidget(app(location: AppRoutes.evaluationFor('ORD-4711')));
      await tester.pumpAndSettle();

      final screen = tester.widget<EvaluationDetailScreen>(
        find.byType(EvaluationDetailScreen),
      );
      expect(screen.orderId, 'ORD-4711');
      expect(find.textContaining('ORD-4711'), findsWidgets);
    });

    testWidgets('an evaluation link lands inside the Auswertung tab',
        (tester) async {
      // Nested under the tab, so the delivery email's link has a back button
      // rather than stranding the customer on a detached screen.
      await tester.pumpWidget(app(location: AppRoutes.evaluationFor('ORD-1')));
      await tester.pumpAndSettle();
      final nav = tester.widget<AppBottomNav>(find.byType(AppBottomNav));
      expect(nav.currentIndex, AppRoutes.tabs.indexOf(AppRoutes.evaluation));
    });

    testWidgets('an unknown link shows a recoverable error, not a crash',
        (tester) async {
      await tester.pumpWidget(app(location: '/does-not-exist'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AppErrorState), findsOneWidget);
      expect(find.textContaining('/does-not-exist'), findsWidgets);

      // And it offers a way back rather than being a dead end.
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    // Regression: jyotish://auswertung/ORD-1 parses with 'auswertung' as the
    // URI *host*, not part of the path, so the router matched '/ORD-1' and
    // showed the not-found screen. Every widget test passed, because they all
    // navigate by path; only opening the link on a device exposed it.
    group('custom-scheme links normalise to paths', () {
      test('a scheme link with a path segment', () {
        expect(
          normaliseDeepLink(Uri.parse('jyotish://auswertung/ORD-4711')),
          '/auswertung/ORD-4711',
        );
      });

      test('a scheme link that is only a tab', () {
        expect(normaliseDeepLink(Uri.parse('jyotish://karriere')), '/karriere');
        expect(normaliseDeepLink(Uri.parse('jyotish://profil')), '/profil');
      });

      test('query parameters survive', () {
        expect(
          normaliseDeepLink(Uri.parse('jyotish://auswertung/ORD-1?from=email')),
          '/auswertung/ORD-1?from=email',
        );
      });

      test('https links are left alone — their host is a domain', () {
        // Rewriting one would produce '/jyotish.de/auswertung/ORD-1'.
        expect(
          normaliseDeepLink(Uri.parse('https://jyotish.de/auswertung/ORD-1')),
          isNull,
        );
      });

      test('an ordinary in-app path is left alone', () {
        expect(normaliseDeepLink(Uri.parse('/kundali')), isNull);
      });
    });

    test('route paths are stable public surface', () {
      // These appear in delivery emails and push payloads. Changing one breaks
      // every link already sent, so a change here should fail the build and be
      // a deliberate decision with a redirect.
      expect(AppRoutes.home, '/');
      expect(AppRoutes.chart, '/kundali');
      expect(AppRoutes.career, '/karriere');
      expect(AppRoutes.evaluation, '/auswertung');
      expect(AppRoutes.profile, '/profil');
      expect(AppRoutes.evaluationFor('ORD-9'), '/auswertung/ORD-9');
      expect(AppRoutes.tabs, hasLength(5));
    });
  });

  group('AC3 — offline banner', () {
    testWidgets('hidden while online', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byType(AppBanner), findsNothing);
    });

    testWidgets('shown while offline', (tester) async {
      await tester.pumpWidget(app(network: NetworkStatus.offline));
      await tester.pumpAndSettle();
      expect(find.byType(AppBanner), findsOneWidget);
      expect(find.textContaining('Keine Verbindung'), findsOneWidget);
    });

    testWidgets('says what still works, not only that something is broken',
        (tester) async {
      await tester.pumpWidget(app(network: NetworkStatus.offline));
      await tester.pumpAndSettle();
      expect(find.textContaining('Kundalis'), findsOneWidget);
    });

    testWidgets('navigation still works while offline', (tester) async {
      await tester.pumpWidget(app(network: NetworkStatus.offline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      // Banner persists across tabs; it belongs to the shell.
      expect(find.byType(AppBanner), findsOneWidget);
    });
  });

  group('Design gallery is reachable but not product surface', () {
    testWidgets('no tab points at it', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final nav = tester.widget<AppBottomNav>(find.byType(AppBottomNav));
      expect(
        nav.destinations.map((d) => d.label),
        isNot(contains('Design System')),
      );
    });

    testWidgets('reachable by URL', (tester) async {
      await tester.pumpWidget(app(location: AppRoutes.designGallery));
      await tester.pumpAndSettle();
      expect(find.text('Design System'), findsOneWidget);
    });
  });
}
