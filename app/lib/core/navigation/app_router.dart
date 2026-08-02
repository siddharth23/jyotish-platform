import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/career/presentation/career_screen.dart';
import '../../features/chart/presentation/chart_screen.dart';
import '../../features/evaluation/presentation/evaluation_detail_screen.dart';
import '../../features/evaluation/presentation/evaluation_screen.dart';
import '../../features/home/presentation/home_screen.dart';
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
GoRouter createRouter({String initialLocation = AppRoutes.home}) {
  return GoRouter(
    initialLocation: initialLocation,
    redirect: _normaliseCustomScheme,
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
              ),
            ],
          ),
        ],
      ),
      // Outside the shell: full screen, with its own back affordance.
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

String? _normaliseCustomScheme(BuildContext context, GoRouterState state) =>
    normaliseDeepLink(state.uri);

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
