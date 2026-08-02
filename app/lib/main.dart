import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/design/theme/app_theme.dart';
import 'core/design/theme/theme_controller.dart';
import 'core/l10n/generated/app_l10n.dart';
import 'core/l10n/locale_controller.dart';
import 'core/navigation/app_router.dart';
import 'features/onboarding/onboarding_controller.dart';

void main() {
  runApp(const ProviderScope(child: JyotishApp()));
}

/// Application root.
///
/// Owns the theme, the locale and the router. Design system components resolve
/// their accessibility strings from context, so `AppL10n.delegate` and
/// `supportedLocales` are load-bearing rather than optional — see
/// `core/design/design_system.dart`.
///
/// The router is built once and held, not rebuilt on every locale change: a new
/// [GoRouter] resets the navigation stack, so switching language would silently
/// throw the user back to the first tab.
class JyotishApp extends ConsumerStatefulWidget {
  const JyotishApp({super.key});

  @override
  ConsumerState<JyotishApp> createState() => _JyotishAppState();
}

class _JyotishAppState extends ConsumerState<JyotishApp> {
  /// Nudges the router when onboarding status resolves.
  ///
  /// The status is unknown for the first frames while storage is read, and the
  /// redirect that would send a new user to the carousel has already run by
  /// then. This tells go_router to evaluate again.
  final ValueNotifier<OnboardingStatus> _onboardingRefresh =
      ValueNotifier(OnboardingStatus.unknown);

  late final GoRouter _router = createRouter(
    refreshListenable: _onboardingRefresh,
    // Read, not watched: rebuilding the router would reset the navigation
    // stack. go_router re-runs redirect on every navigation, so reading the
    // current value each time is enough.
    onboardingStatus: () => ref.read(onboardingControllerProvider),
  );

  @override
  void dispose() {
    _onboardingRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<OnboardingStatus>(
      onboardingControllerProvider,
      (_, next) => _onboardingRefresh.value = next,
    );

    // Null means "follow the device", which is what MaterialApp does when the
    // property is omitted.
    final localePreference = ref.watch(localeControllerProvider);
    final themeMode = ref.watch(themeControllerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppL10n.of(context).appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: _router,
      locale: localePreference.locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
