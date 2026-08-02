import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/design/theme/app_theme.dart';
import 'core/design/theme/theme_controller.dart';
import 'core/l10n/generated/app_l10n.dart';
import 'core/l10n/locale_controller.dart';
import 'core/navigation/app_router.dart';
import 'core/observability/observability_providers.dart';

void main() {
  // Required before anything touches a platform channel. The observability
  // start-up below reads SharedPreferences, which throws "Binding has not yet
  // been initialized" without this. Widget tests install their own binding, so
  // the whole suite passed while the app failed on a real device.
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();

  // Started, not awaited. Cold start is already near the 2.5s budget flagged in
  // US-005, and nothing here needs to finish before the first frame — an error
  // in the first moments is buffered by the crash reporter regardless, because
  // consent cannot have been granted yet.
  unawaited(initialiseObservability(container));

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const JyotishApp(),
    ),
  );
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
  late final GoRouter _router = createRouter();

  @override
  Widget build(BuildContext context) {
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
