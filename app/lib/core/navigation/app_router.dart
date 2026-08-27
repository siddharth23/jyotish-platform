import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/delete_account_screen.dart';
import '../../features/birth_data/presentation/birth_data_screen.dart';
import '../../features/career/presentation/career_screen.dart';
import '../../features/chart/presentation/chart_screen.dart';
import '../../features/evaluation/presentation/evaluation_detail_screen.dart';
import '../../features/evaluation/presentation/evaluation_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/onboarding_controller.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../design/design_system.dart';
import '../design/gallery/design_gallery.dart';
import '../l10n/generated/app_l10n.dart';
import 'app_routes.dart';
import 'app_shell.dart';

/// Builds the app's router.
///
/// A function rather than a top-level constant so tests can construct an
/// isolated router with their own initial location. A shared instance would
/// leak navigation state between tests.
GoRouter createRouter({
  String initialLocation = AppRoutes.home,
  OnboardingStatus Function()? onboardingStatus,
  Listenable? refreshListenable,
}) {
  // Where the user was heading when onboarding interrupted them. A deep link
  // to a paid evaluation must survive a first run, not be swallowed by the
  // carousel.
  String? pendingDestination;

  return GoRouter(
    initialLocation: initialLocation,
    // Onboarding status starts unknown while storage is read. Without a
    // refresh signal the redirect below runs once, passes through, and the
    // carousel never appears for a genuine first run — the status arrives after
    // the only navigation that would have consulted it.
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final normalised = normaliseDeepLink(state.uri);
      if (normalised != null) return normalised;

      final status = onboardingStatus?.call() ?? OnboardingStatus.completed;
      final location = state.uri.toString();

      // Unknown means storage has not answered. Redirecting on it would flash
      // the carousel at a returning user on every cold start, so it waits.
      if (status != OnboardingStatus.notCompleted) return null;
      if (location == AppRoutes.onboarding) return null;

      pendingDestination = location == AppRoutes.home ? null : location;
      return AppRoutes.onboarding;
    },
    // Deep links that do not match anything must land somewhere explicable.
    // The default is a raw exception page, which is what a customer would see
    // after tapping a mistyped link in a delivery email.
    errorBuilder: (context, state) =>
        _RouteNotFound(location: state.uri.toString()),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.chart,
                builder: (context, state) => const ChartScreen(),
                routes: [
                  GoRoute(
                    path: 'geburtsdaten',
                    builder: (context, state) => const BirthDataScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.career,
                builder: (context, state) => const CareerScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.evaluation,
                builder: (context, state) => const EvaluationScreen(),
                routes: [
                  // Nested, so opening an evaluation from its email lands on
                  // the Auswertung tab with a working back button rather than
                  // on a detached screen with nowhere to go.
                  GoRoute(
                    path: ':orderId',
                    builder: (context, state) => EvaluationDetailScreen(
                      orderId: state.pathParameters['orderId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  // Nested, so the back control returns to Profile rather than
                  // stranding the user on a screen with nowhere to go.
                  GoRoute(
                    path: 'konto-loeschen',
                    builder: (context, state) => const DeleteAccountScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => OnboardingScreen(
          onFinished: () {
            // Resume the interrupted destination, or land on Home.
            final destination = pendingDestination ?? AppRoutes.home;
            pendingDestination = null;
            GoRouter.of(context).go(destination);
          },
        ),
      ),
      // Outside the shell: sign-in is a full-screen decision, not a tab.
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => SignInScreen(
          // Theme.of, not defaultTargetPlatform: it honours the override a
          // widget test sets, so the iOS rules can be driven from any machine.
          platform: signInPlatformFor(Theme.of(context).platform),
          onSignedIn: (_) => GoRouter.of(context).go(AppRoutes.home),
          // Null until the email and password screen exists. US-011 delivered
          // that flow's domain in the API and no UI, so there is nowhere to go
          // yet and the control is drawn disabled rather than dead.
          onContinueWithEmail: null,
        ),
      ),
      GoRoute(
        path: AppRoutes.designGallery,
        builder: (context, state) => const DesignGallery(),
      ),
    ],
  );
}

/// The custom URI scheme the app registers with the OS.
const String appUriScheme = 'jyotish';

/// Rewrites custom-scheme deep links into ordinary paths.
///
/// `jyotish://auswertung/ORD-1` parses with `auswertung` as the URI's **host**
/// and `/ORD-1` as its path, so the router would otherwise try to match
/// `/ORD-1` and fall through to the not-found screen. Only the two slashes
/// after the scheme separate this from a path, and nothing in a widget test
/// notices, because tests navigate by path directly. This was found by opening
/// a real link on a device.
///
/// https links are left alone: their host is a domain, not a route segment.
/// Returns the path [uri] should be routed as, or null to leave it alone.
///
/// Public and pure so it can be tested directly. Driving it through
/// `initialLocation` in a widget test exercises go_router's own parsing rather
/// than this rule, and the two do not agree for a scheme link with no path.
String? normaliseDeepLink(Uri uri) {
  if (uri.scheme != appUriScheme || uri.host.isEmpty) return null;
  return Uri(
    path: '/${uri.host}${uri.path}',
    queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
  ).toString();
}

/// Shown for a link that matches no route.
class _RouteNotFound extends StatelessWidget {
  const _RouteNotFound({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppScaffold(
      body: AppErrorState(
        title: l10n.routeNotFoundTitle,
        message: l10n.routeNotFoundMessage(location),
        retryLabel: l10n.routeNotFoundAction,
        onRetry: () => GoRouter.of(context).go(AppRoutes.home),
      ),
    );
  }
}
