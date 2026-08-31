import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish_app/core/connectivity/connectivity_controller.dart';
import 'package:jyotish_app/core/design/design_system.dart';
import 'package:jyotish_app/core/flags/flag_providers.dart';
import 'package:jyotish_app/core/flags/flag_rule_set.dart';
import 'package:jyotish_app/core/l10n/generated/app_l10n.dart';
import 'package:jyotish_app/core/l10n/locale_controller.dart';
import 'package:jyotish_app/core/navigation/app_router.dart';
import 'package:jyotish_app/core/navigation/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Boots the real app at [location] with [ruleSet] already in force.
Widget app({
  required FlagRuleSet ruleSet,
  String location = AppRoutes.evaluation,
}) {
  return ProviderScope(
    overrides: [
      connectivityControllerProvider.overrideWith(
        () => ConnectivityController.fixed(NetworkStatus.online),
      ),
      // Seed the controller directly rather than going through storage, so the
      // test asserts on evaluation rather than on the cache.
      flagRuleSetProvider.overrideWith(
        () => _SeededRuleSet(ruleSet),
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

class _SeededRuleSet extends FlagRuleSetController {
  _SeededRuleSet(this._seed);

  final FlagRuleSet _seed;

  /// Seeds through `build` rather than assigning `state` in the constructor.
  /// A Riverpod 3 Notifier has no element yet at construction time, and this
  /// also skips the disk restore, which is what the test wants: it asserts on
  /// evaluation, not on the cache.
  @override
  FlagRuleSet build() => _seed;
}

FlagRuleSet withPaidEvaluation({required bool enabled}) => FlagRuleSet(
      version: 1,
      rules: {
        'paid_evaluation': FlagRule(key: 'paid_evaluation', enabled: enabled),
      },
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AC2 — the kill switch is visible in the app', () {
    testWidgets('the paid flow is reachable while the flag is on',
        (tester) async {
      await tester.pumpWidget(app(ruleSet: withPaidEvaluation(enabled: true)));
      await tester.pumpAndSettle();

      expect(find.text('Auswertung'), findsWidgets);
      expect(
          find.textContaining('Vorübergehend nicht verfügbar'), findsNothing);
    });

    testWidgets('turning it off replaces the flow with an explanation',
        (tester) async {
      await tester.pumpWidget(app(ruleSet: withPaidEvaluation(enabled: false)));
      await tester.pumpAndSettle();

      expect(find.text('Vorübergehend nicht verfügbar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the message gives no technical reason', (tester) async {
      // The customer does not need to know whether it is a fulfilment problem
      // or an outage, and saying so invites support contacts we cannot action.
      await tester.pumpWidget(app(ruleSet: withPaidEvaluation(enabled: false)));
      await tester.pumpAndSettle();

      for (final leak in ['Flag', 'flag', 'Fehler', 'Server', 'API']) {
        expect(find.textContaining(leak), findsNothing,
            reason: 'leaked "$leak"');
      }
    });

    testWidgets('the rest of the app still works while the switch is off',
        (tester) async {
      // A kill switch on one flow must not take the whole app down with it.
      await tester.pumpWidget(app(ruleSet: withPaidEvaluation(enabled: false)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kundali'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty rule set leaves the paid flow available',
        (tester) async {
      // The compiled-in default. A first run whose fetch failed must not look
      // like the product has been withdrawn.
      await tester.pumpWidget(app(ruleSet: FlagRuleSet.empty));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('Vorübergehend nicht verfügbar'), findsNothing);
    });
  });

  group('A second flag consumer', () {
    testWidgets('the gallery entry disappears when its flag is off',
        (tester) async {
      await tester.pumpWidget(app(
        location: AppRoutes.profile,
        ruleSet: const FlagRuleSet(
          version: 1,
          rules: {
            'design_gallery': FlagRule(key: 'design_gallery', enabled: false),
          },
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Design System'), findsNothing);
    });

    testWidgets('and is present when it is on', (tester) async {
      await tester.pumpWidget(app(
        location: AppRoutes.profile,
        ruleSet: const FlagRuleSet(
          version: 1,
          rules: {
            'design_gallery': FlagRule(key: 'design_gallery', enabled: true),
          },
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Design System'), findsOneWidget);
    });
  });
}
