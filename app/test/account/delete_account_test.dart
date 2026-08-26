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
import 'package:jyotish_app/features/account/account_deletion_controller.dart';
import 'package:jyotish_app/features/account/presentation/delete_account_screen.dart';
import 'package:jyotish_app/features/onboarding/onboarding_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A gateway whose behaviour each test dictates.
class FakeGateway implements AccountDeletionGateway {
  FakeGateway({this.purgeDueAt, this.throws = false});

  final DateTime? purgeDueAt;
  final bool throws;
  int calls = 0;

  @override
  Future<DateTime?> requestDeletion() async {
    calls += 1;
    if (throws) throw StateError('unreachable');
    return purgeDueAt;
  }
}

Widget app({
  AccountDeletionGateway? gateway,
  Locale locale = const Locale('de', 'DE'),
  String location = AppRoutes.profile,
}) {
  return ProviderScope(
    overrides: [
      connectivityControllerProvider.overrideWith(
        (ref) => ConnectivityController.fixed(NetworkStatus.online),
      ),
      if (gateway != null)
        accountDeletionGatewayProvider.overrideWithValue(gateway),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: createRouter(
        initialLocation: location,
        onboardingStatus: () => OnboardingStatus.completed,
      ),
      locale: locale,
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

  group('US-015 AC1 — reachable in three taps or fewer from Profile', () {
    testWidgets('Profile, the row, and confirm: three taps', (tester) async {
      // Apple 5.1.1(v) requires deletion to exist in the app at all; AC1 puts
      // a budget on how buried it may be. Counted explicitly so that adding a
      // "settings" level in between fails here rather than in review.
      final gateway = FakeGateway(purgeDueAt: DateTime.utc(2026, 8, 13));
      await tester.pumpWidget(app(gateway: gateway, location: AppRoutes.home));
      await tester.pumpAndSettle();

      var taps = 0;

      await tester.tap(find.text('Profil'));
      taps += 1;
      await tester.pumpAndSettle();

      await tester.tap(find.text('Konto löschen').first);
      taps += 1;
      await tester.pumpAndSettle();
      expect(find.byType(DeleteAccountScreen), findsOneWidget);

      await tester.tap(find.text('Konto endgültig löschen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ja, Konto löschen'));
      taps += 1;
      await tester.pumpAndSettle();

      expect(taps, lessThanOrEqualTo(3), reason: 'AC1 caps this at three');
      expect(gateway.calls, 1);
    });

    testWidgets('the entry point is on the Profile tab itself', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Konto löschen'), findsOneWidget);
    });
  });

  group('US-015 AC2 — what is deleted versus what is retained', () {
    testWidgets('both headings are shown before any confirmation',
        (tester) async {
      await tester.pumpWidget(app(location: AppRoutes.deleteAccount));
      await tester.pumpAndSettle();

      expect(find.text('Was gelöscht wird'), findsOneWidget);
      expect(find.text('Was wir behalten müssen'), findsOneWidget);
    });

    testWidgets('the retention explanation names the paragraph and the term',
        (tester) async {
      // A user who is told "some data is kept" cannot check that. § 147 AO and
      // "zehn Jahre" are both verifiable, which is the difference between an
      // explanation and a reassurance.
      await tester.pumpWidget(app(location: AppRoutes.deleteAccount));
      await tester.pumpAndSettle();

      final retained = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.contains('§ 147 AO') ?? false),
        ),
      );
      expect(retained.data, contains('zehn Jahre'));
      expect(retained.data, contains('Rechnungen'));
    });

    testWidgets('birth data is named among what is deleted', (tester) async {
      await tester.pumpWidget(app(location: AppRoutes.deleteAccount));
      await tester.pumpAndSettle();
      expect(find.textContaining('Geburtsdaten'), findsOneWidget);
    });

    testWidgets('the confirmation dialog repeats the retention point',
        (tester) async {
      // The last screen before an irreversible action must not be the one
      // place where the promise is simpler than the truth.
      await tester.pumpWidget(app(location: AppRoutes.deleteAccount));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Konto endgültig löschen'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Rechnungen'), findsWidgets);
    });

    testWidgets('English says the same things', (tester) async {
      await tester.pumpWidget(
        app(
            location: AppRoutes.deleteAccount,
            locale: const Locale('en', 'GB')),
      );
      await tester.pumpAndSettle();

      expect(find.text('What is deleted'), findsOneWidget);
      expect(find.text('What we are required to keep'), findsOneWidget);
      expect(find.textContaining('§ 147 AO'), findsOneWidget);
    });
  });

  group('US-015 — nothing is deleted without confirming', () {
    testWidgets('dismissing the dialog does not call the gateway',
        (tester) async {
      final gateway = FakeGateway(purgeDueAt: DateTime.utc(2026, 8, 13));
      await tester.pumpWidget(
        app(gateway: gateway, location: AppRoutes.deleteAccount),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Konto endgültig löschen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      expect(gateway.calls, 0);
    });

    testWidgets('opening the screen alone deletes nothing', (tester) async {
      final gateway = FakeGateway(purgeDueAt: DateTime.utc(2026, 8, 13));
      await tester.pumpWidget(
        app(gateway: gateway, location: AppRoutes.deleteAccount),
      );
      await tester.pumpAndSettle();
      expect(gateway.calls, 0);
    });
  });

  group('US-015 AC3 — the user is told when erasure happens', () {
    testWidgets('the concrete purge date is shown, formatted DD.MM.YYYY',
        (tester) async {
      // Not "in seven days": a date survives the screen being reopened later,
      // and yMd would render this as 13.8.2026.
      await tester.pumpWidget(
        app(
          gateway: FakeGateway(purgeDueAt: DateTime.utc(2026, 8, 13)),
          location: AppRoutes.deleteAccount,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Konto endgültig löschen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ja, Konto löschen'));
      await tester.pumpAndSettle();

      expect(find.textContaining('13.08.2026'), findsOneWidget);
    });

    testWidgets('English uses DD/MM/YYYY, never the US order', (tester) async {
      await tester.pumpWidget(
        app(
          gateway: FakeGateway(purgeDueAt: DateTime.utc(2026, 8, 13)),
          location: AppRoutes.deleteAccount,
          locale: const Locale('en', 'GB'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Permanently delete account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes, delete it'));
      await tester.pumpAndSettle();

      expect(find.textContaining('13/08/2026'), findsOneWidget);
    });

    testWidgets('the undo hint is shown alongside the date', (tester) async {
      await tester.pumpWidget(
        app(
          gateway: FakeGateway(purgeDueAt: DateTime.utc(2026, 8, 13)),
          location: AppRoutes.deleteAccount,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Konto endgültig löschen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ja, Konto löschen'));
      await tester.pumpAndSettle();

      expect(find.textContaining('rückgängig'), findsOneWidget);
    });
  });

  group('US-015 — a failed request is never reported as success', () {
    testWidgets('a refusal shows the error, not a deletion date',
        (tester) async {
      // The shipped gateway returns null, because the API has no HTTP layer.
      // Showing "scheduled" here would be the worst possible lie.
      await tester.pumpWidget(
        app(gateway: FakeGateway(), location: AppRoutes.deleteAccount),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Konto endgültig löschen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ja, Konto löschen'));
      await tester.pumpAndSettle();

      expect(find.textContaining('konnte nicht'), findsOneWidget);
      expect(find.textContaining('vorgemerkt'), findsNothing);
    });

    testWidgets('an unreachable server shows the error too', (tester) async {
      await tester.pumpWidget(
        app(
          gateway: FakeGateway(throws: true),
          location: AppRoutes.deleteAccount,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Konto endgültig löschen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ja, Konto löschen'));
      await tester.pumpAndSettle();

      expect(find.textContaining('konnte nicht'), findsOneWidget);
    });

    testWidgets('the default gateway refuses, since there is no API yet',
        (tester) async {
      await tester.pumpWidget(app(location: AppRoutes.deleteAccount));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Konto endgültig löschen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ja, Konto löschen'));
      await tester.pumpAndSettle();

      expect(find.textContaining('vorgemerkt'), findsNothing);
    });
  });
}
