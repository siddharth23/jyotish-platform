import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish_app/core/design/design_system.dart';
import 'package:jyotish_app/core/l10n/generated/app_l10n.dart';
import 'package:jyotish_app/core/l10n/locale_controller.dart';
import 'package:jyotish_app/features/auth/account_linking.dart';
import 'package:jyotish_app/features/auth/apple_authorisation_store.dart';
import 'package:jyotish_app/features/auth/auth_controller.dart';
import 'package:jyotish_app/features/auth/auth_gateway.dart';
import 'package:jyotish_app/features/auth/presentation/sign_in_screen.dart';
import 'package:jyotish_app/features/auth/social_credential.dart';
import 'package:jyotish_app/features/auth/social_provider.dart';
import 'package:jyotish_app/features/auth/social_sign_in.dart';

class StubGateway implements AuthGateway {
  StubGateway({required this.result});

  SocialExchangeResult result;

  @override
  Future<SocialExchangeResult> exchangeSocialCredential(
    SocialCredential credential,
  ) async =>
      result;

  @override
  Future<SocialExchangeResult> confirmLink(SocialCredential credential) async =>
      result;
}

SocialCredential credential({String? email = 'anna@example.de'}) =>
    SocialCredential(
      provider: SocialProvider.apple,
      subjectId: 'subject-1',
      identityToken: 'token.for.tests',
      email: email,
      providerAssertsEmailVerified: true,
    );

Widget screen({
  required SignInPlatform platform,
  Set<SocialProvider> available = const {
    SocialProvider.apple,
    SocialProvider.google,
  },
  SocialAuthorisation? appleResponse,
  SocialAuthorisation? googleResponse,
  SocialExchangeResult result = const SocialExchangeSignedIn(
    accountId: 'account-1',
    isNewAccount: true,
    emailVerified: true,
  ),
  VoidCallback? onContinueWithEmail,
}) {
  final signIn = FakeSocialSignIn(available: available);
  if (appleResponse != null) {
    signIn.respondWith(SocialProvider.apple, appleResponse);
  }
  if (googleResponse != null) {
    signIn.respondWith(SocialProvider.google, googleResponse);
  }

  return ProviderScope(
    overrides: [
      socialSignInProvider.overrideWithValue(signIn),
      authGatewayProvider.overrideWithValue(StubGateway(result: result)),
      appleAuthorisationStoreProvider
          .overrideWithValue(InMemoryAppleAuthorisationStore()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('de', 'DE'),
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: SignInScreen(
        platform: platform,
        onContinueWithEmail: onContinueWithEmail,
      ),
    ),
  );
}

/// Vertical position of the button carrying [label].
double buttonTop(WidgetTester tester, String label) =>
    tester.getTopLeft(find.widgetWithText(AppButton, label)).dy;

void main() {
  group('US-012 AC1 — what an iPhone is allowed to show', () {
    testWidgets('offers Apple and Google, Apple first', (tester) async {
      await tester.pumpWidget(screen(platform: SignInPlatform.ios));
      await tester.pumpAndSettle();

      expect(find.text('Mit Apple anmelden'), findsOneWidget);
      expect(find.text('Mit Google anmelden'), findsOneWidget);
      // The HIG requires Sign in with Apple to be no less prominent.
      expect(
        buttonTop(tester, 'Mit Apple anmelden'),
        lessThan(buttonTop(tester, 'Mit Google anmelden')),
      );
    });

    testWidgets('shows no social buttons at all when Apple is unavailable',
        (tester) async {
      // Guideline 4.8: Google alone on an iPhone is a rejection. The screen
      // does not re-derive this rule, which is the point of testing it here.
      await tester.pumpWidget(screen(
        platform: SignInPlatform.ios,
        available: const {SocialProvider.google},
      ));
      await tester.pumpAndSettle();

      expect(find.text('Mit Google anmelden'), findsNothing);
      expect(find.text('Mit Apple anmelden'), findsNothing);
      // The email flow is still there, and is said to be.
      expect(find.text('Mit E-Mail-Adresse fortfahren'), findsOneWidget);
      expect(find.byType(AppBanner), findsOneWidget);
    });
  });

  group('US-012 AC2 — what an Android phone shows', () {
    testWidgets('offers Google and not Apple', (tester) async {
      await tester.pumpWidget(screen(platform: SignInPlatform.android));
      await tester.pumpAndSettle();

      expect(find.text('Mit Google anmelden'), findsOneWidget);
      expect(find.text('Mit Apple anmelden'), findsNothing);
    });

    testWidgets('falls back to email when Google is unavailable',
        (tester) async {
      await tester.pumpWidget(screen(
        platform: SignInPlatform.android,
        available: const {},
      ));
      await tester.pumpAndSettle();

      expect(find.text('Mit Google anmelden'), findsNothing);
      expect(find.text('Mit E-Mail-Adresse fortfahren'), findsOneWidget);
    });
  });

  group('signing in from the screen', () {
    testWidgets('a tap runs the provider and lands signed in', (tester) async {
      await tester.pumpWidget(screen(
        platform: SignInPlatform.ios,
        appleResponse: SocialAuthorisationGranted(credential()),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mit Apple anmelden'));
      await tester.pumpAndSettle();

      // No error banner: the flow completed.
      expect(find.byType(AppBanner), findsNothing);
    });

    testWidgets('a cancelled sheet shows no error', (tester) async {
      await tester.pumpWidget(screen(
        platform: SignInPlatform.ios,
        appleResponse: const SocialAuthorisationCancelled(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mit Apple anmelden'));
      await tester.pumpAndSettle();

      expect(find.byType(AppBanner), findsNothing);
      expect(find.text('Mit Apple anmelden'), findsOneWidget);
    });

    testWidgets('a failure shows a dismissible banner', (tester) async {
      await tester.pumpWidget(screen(
        platform: SignInPlatform.ios,
        appleResponse: const SocialAuthorisationFailed(
          SocialAuthorisationFailureReason.network,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mit Apple anmelden'));
      await tester.pumpAndSettle();

      expect(find.text('Keine Verbindung. Bitte versuche es erneut.'),
          findsOneWidget);
    });
  });

  group('US-012 AC4 — telling the user their address is hidden', () {
    testWidgets('the relay notice appears after a hidden-email sign-in',
        (tester) async {
      await tester.pumpWidget(screen(
        platform: SignInPlatform.ios,
        appleResponse: SocialAuthorisationGranted(
          credential(email: 'xyz@privaterelay.appleid.com'),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mit Apple anmelden'));
      await tester.pumpAndSettle();

      expect(find.text('Deine Adresse bleibt verborgen'), findsOneWidget);
      // The consequence, not just the mechanism: the report is delivered by
      // email and forwarding can be switched off.
      expect(
        find.textContaining('erreicht sie dich nicht mehr'),
        findsOneWidget,
      );
    });

    testWidgets('it does not appear for a real address', (tester) async {
      await tester.pumpWidget(screen(
        platform: SignInPlatform.ios,
        appleResponse: SocialAuthorisationGranted(credential()),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mit Apple anmelden'));
      await tester.pumpAndSettle();

      expect(find.text('Deine Adresse bleibt verborgen'), findsNothing);
    });
  });

  group('US-012 AC3 — the linking prompt', () {
    const match = ExistingAccountMatch(
      method: ExistingSignInMethod.password,
      maskedEmail: 'a***a@example.de',
    );

    testWidgets('replaces the provider buttons so nothing races it',
        (tester) async {
      await tester.pumpWidget(screen(
        platform: SignInPlatform.ios,
        appleResponse: SocialAuthorisationGranted(credential()),
        result: const SocialExchangeNeedsLinking(
          decision: LinkToExistingAccount(match: match),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mit Apple anmelden'));
      await tester.pumpAndSettle();

      expect(find.text('Konto verknüpfen?'), findsOneWidget);
      expect(find.text('Verknüpfen'), findsOneWidget);
      expect(find.text('Mit Apple anmelden'), findsNothing);
    });

    testWidgets('names the account by its masked address', (tester) async {
      await tester.pumpWidget(screen(
        platform: SignInPlatform.ios,
        appleResponse: SocialAuthorisationGranted(credential()),
        result: const SocialExchangeNeedsLinking(
          decision: LinkToExistingAccount(match: match),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mit Apple anmelden'));
      await tester.pumpAndSettle();

      expect(find.textContaining('a***a@example.de'), findsOneWidget);
      // Never the full address: that would be the enumeration hole US-011 spent
      // its effort closing.
      expect(find.textContaining('anna@example.de'), findsNothing);
    });

    testWidgets('offers no link button when the address is unverified',
        (tester) async {
      // The one control that must never be tappable. Drawing it and relying on
      // the API to refuse it puts an account takeover one bug away.
      await tester.pumpWidget(screen(
        platform: SignInPlatform.ios,
        appleResponse: SocialAuthorisationGranted(credential()),
        result: const SocialExchangeNeedsLinking(
          decision: ProofOfControlRequired(match: match),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mit Apple anmelden'));
      await tester.pumpAndSettle();

      expect(find.text('Bitte zuerst anmelden'), findsOneWidget);
      expect(find.text('Verknüpfen'), findsNothing);
    });

    testWidgets('proof of control sends the user to the email flow',
        (tester) async {
      var continued = false;
      await tester.pumpWidget(screen(
        platform: SignInPlatform.ios,
        appleResponse: SocialAuthorisationGranted(credential()),
        result: const SocialExchangeNeedsLinking(
          decision: ProofOfControlRequired(match: match),
        ),
        onContinueWithEmail: () => continued = true,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mit Apple anmelden'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mit E-Mail-Adresse fortfahren'));
      await tester.pumpAndSettle();

      expect(continued, isTrue);
    });

    testWidgets('cancelling returns to the provider buttons', (tester) async {
      await tester.pumpWidget(screen(
        platform: SignInPlatform.ios,
        appleResponse: SocialAuthorisationGranted(credential()),
        result: const SocialExchangeNeedsLinking(
          decision: LinkToExistingAccount(match: match),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mit Apple anmelden'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      expect(find.text('Konto verknüpfen?'), findsNothing);
      expect(find.text('Mit Apple anmelden'), findsOneWidget);
    });
  });

  group('platform resolution', () {
    test('maps Flutter target platforms onto the sign-in rules', () {
      expect(signInPlatformFor(TargetPlatform.iOS), SignInPlatform.ios);
      expect(signInPlatformFor(TargetPlatform.android), SignInPlatform.android);
      for (final other in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      ]) {
        expect(signInPlatformFor(other), SignInPlatform.other, reason: '$other');
      }
    });
  });
}
