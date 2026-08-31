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
import 'package:jyotish_app/features/evaluation/presentation/evaluation_detail_screen.dart';
import 'package:jyotish_app/features/home/presentation/home_screen.dart';
import 'package:jyotish_app/features/onboarding/onboarding_controller.dart';
import 'package:jyotish_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Boots the real router with onboarding in a given [status].
Widget app({
  OnboardingStatus status = OnboardingStatus.notCompleted,
  String location = AppRoutes.home,
  Locale locale = const Locale('de', 'DE'),
  ValueNotifier<OnboardingStatus>? refresh,
}) {
  var current = status;
  return ProviderScope(
    overrides: [
      connectivityControllerProvider.overrideWith(
        () => ConnectivityController.fixed(NetworkStatus.online),
      ),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        // Keep the callback reading live state so completion is observed.
        ref.listen<OnboardingStatus>(
          onboardingControllerProvider,
          (_, next) => current = next,
        );
        return MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: createRouter(
            initialLocation: location,
            onboardingStatus: () => current,
            refreshListenable: refresh,
          ),
          locale: locale,
          supportedLocales: supportedLocales,
          localizationsDelegates: const [
            AppL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        );
      },
    ),
  );
}

/// Mounts an onboarding controller so it has a live provider element.
///
/// A Riverpod 3 Notifier draws `ref` and `state` from the element, so a
/// merely-constructed one throws "uninitialized state". Reading the provider
/// once runs `build`, which is also what starts the storage restore these
/// tests race against.
OnboardingController mountedOnboarding(OnboardingController c) {
  final container = ProviderContainer(
    overrides: [onboardingControllerProvider.overrideWith(() => c)],
  );
  addTearDown(container.dispose);
  container.read(onboardingControllerProvider);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AC1 — at most four screens, skippable', () {
    testWidgets('there are exactly four pages, never more', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      final pageView = tester.widget<PageView>(find.byType(PageView));
      final count = pageView.childrenDelegate.estimatedChildCount;
      expect(count, lessThanOrEqualTo(4), reason: 'AC1 caps this at four');
      expect(count, 4);
    });

    testWidgets('skip is available on the very first page', (tester) async {
      // The user most likely to skip is the one who already knows the app;
      // making them page to the end first defeats the point.
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Überspringen'), findsOneWidget);
    });

    testWidgets('skip is still available on the last page', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Weiter'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Los geht\'s'), findsOneWidget);
      expect(find.text('Überspringen'), findsOneWidget);
    });

    testWidgets('paging forward reaches the last page', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.text('Willkommen bei Jyotish'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Weiter'));
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('Expertenauswertung'), findsOneWidget);
    });

    testWidgets('the position is announced, not just shown as dots',
        (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      final semantics = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byType(AnimatedContainer).first,
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(semantics.properties.label, contains('Seite 1 von 4'));
    });
  });

  group('AC3 — what the pages explain', () {
    testWidgets('the free chart', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Kundali'), findsOneWidget);
      expect(find.textContaining('kostenlos'), findsWidgets);
    });

    testWidgets('the free career feature, framed as personal use',
        (tester) async {
      // docs/adr/0005: the personal-use framing keeps this out of EU AI Act
      // recruitment scope. Losing it from the intro is a compliance change,
      // not a copy change.
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Weiter'));
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('Berufliche'), findsOneWidget);
      expect(find.textContaining('nicht für Arbeitgeber'), findsOneWidget);
    });

    testWidgets('the paid report, with a locale-formatted price',
        (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Weiter'));
        await tester.pumpAndSettle();
      }
      // German: 11,00 € — comma decimal, symbol trailing.
      expect(find.textContaining('11,00'), findsOneWidget);
      expect(find.textContaining('72 Stunden'), findsOneWidget);
    });
  });

  group('AC2 — German by default on a German device', () {
    testWidgets('a de device sees German', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Willkommen bei Jyotish'), findsOneWidget);
      expect(find.text('Überspringen'), findsOneWidget);
    });

    testWidgets('an en-GB device sees English', (tester) async {
      await tester.pumpWidget(app(locale: const Locale('en', 'GB')));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to Jyotish'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('the English price uses English conventions', (tester) async {
      await tester.pumpWidget(app(locale: const Locale('en', 'GB')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('11.00'), findsOneWidget);
    });
  });

  group('AC4 — shown once', () {
    testWidgets('a first run is redirected to onboarding', (tester) async {
      await tester.pumpWidget(app(status: OnboardingStatus.notCompleted));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('a returning user goes straight to the app', (tester) async {
      await tester.pumpWidget(app(status: OnboardingStatus.completed));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('unknown status does not flash the carousel', (tester) async {
      // Storage has not answered yet. Treating that as "not completed" would
      // show the intro to a returning user on every cold start.
      await tester.pumpWidget(app(status: OnboardingStatus.unknown));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsNothing);
    });

    testWidgets('finishing records completion and leaves onboarding',
        (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Weiter'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Los geht\'s'));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('skipping also counts as done', (tester) async {
      // A skip that asks again next launch is not a skip.
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Überspringen'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    test('completion persists under the key AC4 names', () async {
      final controller = mountedOnboarding(OnboardingController(
        preferences: await SharedPreferences.getInstance(),
      ));
      await controller.complete();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(OnboardingController.storageKey), isTrue);
      expect(OnboardingController.storageKey, 'onboarding_completed');
    });

    test('completion survives a restart', () async {
      final first = mountedOnboarding(OnboardingController(
        preferences: await SharedPreferences.getInstance(),
      ));
      await first.complete();

      final second = mountedOnboarding(OnboardingController(
        preferences: await SharedPreferences.getInstance(),
      ));
      await Future<void>.delayed(Duration.zero);
      expect(second.state, OnboardingStatus.completed);
    });

    test('a completion during the storage read is not undone', () async {
      // The same restore race as US-006 and US-008: here it would send a user
      // who just finished the carousel back to the start of it.
      final controller = mountedOnboarding(OnboardingController(
        preferences: await SharedPreferences.getInstance(),
      ));
      await controller.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state, OnboardingStatus.completed);
    });

    test('reset shows it again, for support', () async {
      final controller = mountedOnboarding(OnboardingController(
        preferences: await SharedPreferences.getInstance(),
      ));
      await controller.complete();
      await controller.reset();
      expect(controller.state, OnboardingStatus.notCompleted);
    });
  });

  group('A deep link is not swallowed by onboarding', () {
    testWidgets('an evaluation link on a first run resumes after finishing',
        (tester) async {
      // Someone reinstalls, taps the link in their delivery email, and must
      // still reach the evaluation they paid for rather than being dumped on
      // Home.
      await tester.pumpWidget(app(
        status: OnboardingStatus.notCompleted,
        location: AppRoutes.evaluationFor('ORD-4711'),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);

      await tester.tap(find.text('Überspringen'));
      await tester.pumpAndSettle();

      expect(find.byType(EvaluationDetailScreen), findsOneWidget);
      expect(find.textContaining('ORD-4711'), findsWidgets);
    });

    testWidgets('a plain first run lands on Home', (tester) async {
      await tester.pumpWidget(app(status: OnboardingStatus.notCompleted));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Überspringen'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('The router re-evaluates when status resolves', () {
    testWidgets('a status arriving after the first frame still redirects',
        (tester) async {
      // Without a refresh signal the redirect runs once against "unknown",
      // passes through, and the carousel never appears for a genuine first run.
      final refresh = ValueNotifier(OnboardingStatus.unknown);
      addTearDown(refresh.dispose);

      var status = OnboardingStatus.unknown;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectivityControllerProvider.overrideWith(
              () => ConnectivityController.fixed(NetworkStatus.online),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: createRouter(
              onboardingStatus: () => status,
              refreshListenable: refresh,
            ),
            locale: const Locale('de', 'DE'),
            supportedLocales: supportedLocales,
            localizationsDelegates: const [
              AppL10n.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsNothing);

      // Storage answers.
      status = OnboardingStatus.notCompleted;
      refresh.value = OnboardingStatus.notCompleted;
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);
    });
  });
}
