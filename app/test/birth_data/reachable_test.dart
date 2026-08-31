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
import 'package:jyotish_app/features/birth_data/presentation/birth_data_screen.dart';
import 'package:jyotish_app/features/onboarding/onboarding_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The whole app, driven only by taps.
///
/// These tests exist because a screen can be fully built, fully routed and
/// fully tested while remaining impossible to reach by tapping. That happened
/// twice: `BirthPlaceField` was mounted on nothing, and the birth-data screen
/// was routed but nothing navigated to it — the Kundali tab's only button was
/// wired to null. Deep-linking straight to the route in a test hides exactly
/// this, so nothing here may navigate by URL.
Widget app() {
  return ProviderScope(
    overrides: [
      connectivityControllerProvider.overrideWith(
        () => ConnectivityController.fixed(NetworkStatus.online),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: createRouter(
        initialLocation: AppRoutes.home,
        onboardingStatus: () => OnboardingStatus.completed,
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
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('US-020 — the birth-data form is reachable by tapping', () {
    testWidgets('the Kundali tab leads to it', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kundali'));
      await tester.pumpAndSettle();
      expect(find.byType(BirthDataScreen), findsNothing,
          reason: 'the tab itself is still the chart placeholder');

      await tester.tap(find.text('Geburtsdaten eingeben'));
      await tester.pumpAndSettle();

      expect(find.byType(BirthDataScreen), findsOneWidget);
    });

    testWidgets('the empty-state action is enabled, not a dead button',
        (tester) async {
      // It shipped as `onAction: null`, which renders a button that looks
      // available and does nothing.
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kundali'));
      await tester.pumpAndSettle();

      final button = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Geburtsdaten eingeben'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('back from the form returns to the Kundali tab',
        (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kundali'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Geburtsdaten eingeben'));
      await tester.pumpAndSettle();

      // Not `pageBack()`: that looks for a stock Material or Cupertino back
      // button, and AppScaffold draws its own AppIconButton.
      await tester.tap(find.widgetWithIcon(AppIconButton, Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(BirthDataScreen), findsNothing);
      expect(find.text('Geburtsdaten eingeben'), findsOneWidget);
    });
  });
}
