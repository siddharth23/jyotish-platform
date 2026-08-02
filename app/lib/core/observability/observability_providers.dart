import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_logger.dart';
import 'crash_reporter.dart';
import 'session_tracker.dart';
import 'telemetry_consent.dart';

/// The running app version, as reported to crash reports and session counters.
///
/// Overridden at startup from package_info once that is wired; hardcoded until
/// then, which means every device currently attributes its sessions to 0.1.0.
final observedAppVersionProvider = Provider<String>((ref) => '0.1.0');

final appLoggerProvider = Provider<AppLogger>(
  (ref) => const AppLogger(
      minimumLevel: kDebugMode ? LogLevel.debug : LogLevel.info),
);

/// Where crash reports go.
///
/// A recording transport for now: there is no crash reporting account, so
/// nothing leaves the device regardless of consent. Replacing this with a
/// Sentry client is the only change needed to start reporting — the consent
/// gate and redaction sit in [CrashReporter], above whatever this is.
final crashTransportProvider = Provider<CrashTransport>(
  (ref) => RecordingCrashTransport(),
);

/// The crash reporter, kept in step with the user's consent.
///
/// Watching consent here is what makes withdrawal take effect immediately
/// rather than at next launch: a change flows straight into
/// [CrashReporter.updateConsent], which also discards anything buffered.
final crashReporterProvider = Provider<CrashReporter>((ref) {
  final reporter = CrashReporter(
    transport: ref.watch(crashTransportProvider),
    appVersion: ref.watch(observedAppVersionProvider),
    consent: ref.read(telemetryConsentProvider),
  );

  ref.listen<TelemetryConsent>(
    telemetryConsentProvider,
    (_, next) => unawaited(reporter.updateConsent(next)),
    fireImmediately: true,
  );

  return reporter;
});

final sessionTrackerProvider = Provider<SessionTracker>(
  (ref) => SessionTracker(appVersion: ref.watch(observedAppVersionProvider)),
);

/// Installs the global error handlers and opens a session.
///
/// **Deliberately not awaited during startup.** Cold start is already close to
/// the 2.5s budget in US-005, and none of this needs to finish before the first
/// frame: an error arriving in the first few hundred milliseconds is buffered by
/// the reporter anyway, since consent cannot have been granted yet.
///
/// Errors here are swallowed. Observability failing must never be the reason an
/// app fails to start.
Future<void> initialiseObservability(ProviderContainer container) async {
  final reporter = container.read(crashReporterProvider);
  final logger = container.read(appLoggerProvider);

  // Framework errors — a failed build, a layout overflow in release.
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    previousOnError?.call(details);
    unawaited(
      reporter.recordError(
        details.exception,
        details.stack ?? StackTrace.current,
        context: {'component': details.library ?? 'flutter'},
      ),
    );
  };

  // Errors that escaped the framework entirely, which are the fatal ones.
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(reporter.recordCrash(error, stack));
    // False means "not handled", so the platform still reports it. Claiming to
    // have handled a fatal error hides it from the OS-level reporter too.
    return false;
  };

  try {
    final sessions = container.read(sessionTrackerProvider);
    final previousCrashed = await sessions.startSession();
    if (previousCrashed) {
      logger.warn('Previous session ended without a clean exit');
    }
    await sessions.pruneOtherVersions();
  } on Object {
    // A failed session counter is not worth a failed launch.
  }
}
