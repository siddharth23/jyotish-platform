import 'package:flutter/foundation.dart';

import 'app_logger.dart';
import 'telemetry_consent.dart';

/// A crash or non-fatal error, already stripped of anything personal.
@immutable
class CrashReport {
  const CrashReport({
    required this.errorType,
    required this.stackTrace,
    required this.appVersion,
    required this.isFatal,
    required this.occurredAt,
    this.correlationId,
    this.context = const {},
  });

  /// The exception's runtime type — `FormatException`, not its message.
  final String errorType;

  /// The stack trace, redacted.
  final String stackTrace;

  final String appVersion;
  final bool isFatal;
  final DateTime occurredAt;
  final String? correlationId;

  /// Allowlisted diagnostic fields.
  final Map<String, Object?> context;

  Map<String, Object?> toJson() => {
        'errorType': errorType,
        'stackTrace': stackTrace,
        'appVersion': appVersion,
        'isFatal': isFatal,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'correlationId': correlationId,
        'context': context,
      };
}

/// Sends reports somewhere. Implemented by a Sentry client in production.
abstract interface class CrashTransport {
  Future<void> send(CrashReport report);
}

/// Collects reports in memory. For tests, and the default until a real
/// transport exists.
class RecordingCrashTransport implements CrashTransport {
  final List<CrashReport> sent = [];

  @override
  Future<void> send(CrashReport report) async => sent.add(report);

  void clear() => sent.clear();
}

/// Captures crashes, and refuses to send any of them without consent
/// (US-008 AC4).
///
/// ## What leaves the device, and when
///
/// Nothing, unless [TelemetryCategory.crashReporting] is granted. That is not a
/// configuration flag but the only path to [CrashTransport.send]: there is no
/// method that bypasses the check, because a bypass is what gets used during an
/// incident and then stays.
///
/// ## Crashes before the user has decided
///
/// Held in memory, capped, and never written to disk. If consent is granted
/// they are sent; if it is denied or the app exits first, they are discarded.
///
/// The reasoning: buffering locally is processing on the user's own device,
/// while transmission to a processor is what requires a basis. Dropping them
/// outright would lose exactly the first-run crashes that matter most, and
/// persisting them would create a store of diagnostic data with no basis behind
/// it. **This is a judgement call and wants confirming with the German lawyer
/// already engaged for AGB and Datenschutz (US-088).**
///
/// ## Redaction
///
/// Every report passes through the same redaction as logs. A Dart stack trace
/// carries the values that caused it, and in this product that means a birth
/// date, a place name or an email sitting in a frame.
class CrashReporter {
  CrashReporter({
    required CrashTransport transport,
    required String appVersion,
    TelemetryConsent consent = TelemetryConsent.none,
    int bufferLimit = 20,
    DateTime Function()? now,
  })  : _transport = transport,
        _appVersion = appVersion,
        _consent = consent,
        _bufferLimit = bufferLimit,
        _now = now ?? DateTime.now;

  final CrashTransport _transport;
  final String _appVersion;
  final int _bufferLimit;
  final DateTime Function() _now;

  TelemetryConsent _consent;
  final List<CrashReport> _pending = [];

  /// Reports captured but not sent, because consent has not been granted.
  @visibleForTesting
  int get pendingCount => _pending.length;

  bool get _allowed => _consent.allows(TelemetryCategory.crashReporting);

  /// Applies a consent change.
  ///
  /// Granting flushes anything buffered. Denying discards it — a user who
  /// refuses must not have their pre-decision crashes sent later, and must not
  /// leave them sitting in memory either.
  Future<void> updateConsent(TelemetryConsent consent) async {
    final wasAllowed = _allowed;
    _consent = consent;

    if (_allowed && !wasAllowed) {
      final flushing = List<CrashReport>.from(_pending);
      _pending.clear();
      for (final report in flushing) {
        await _transport.send(report);
      }
      return;
    }

    if (!_allowed) _pending.clear();
  }

  /// Records a fatal crash.
  Future<void> recordCrash(
    Object error,
    StackTrace stackTrace, {
    Map<String, Object?> context = const {},
  }) =>
      _record(error, stackTrace, isFatal: true, context: context);

  /// Records a handled error that did not kill the app.
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    Map<String, Object?> context = const {},
  }) =>
      _record(error, stackTrace, isFatal: false, context: context);

  Future<void> _record(
    Object error,
    StackTrace stackTrace, {
    required bool isFatal,
    required Map<String, Object?> context,
  }) async {
    final report = CrashReport(
      // The type, never the message. `FormatException: invalid date
      // "17.05.1990"` is a stack frame carrying a birth date.
      errorType: error.runtimeType.toString(),
      stackTrace: redactText(stackTrace.toString()),
      appVersion: _appVersion,
      isFatal: isFatal,
      occurredAt: _now(),
      correlationId: currentCorrelationId(),
      context: redactFields(context),
    );

    if (_allowed) {
      await _transport.send(report);
      return;
    }

    // Denied means discard, not buffer: there is no future event that would
    // make sending them lawful.
    if (_consent.stateOf(TelemetryCategory.crashReporting) ==
        ConsentState.denied) {
      return;
    }

    // Undecided. Hold the oldest, drop the newest once full — a crash loop
    // would otherwise evict the first crash, which is the one that explains
    // the rest.
    if (_pending.length < _bufferLimit) _pending.add(report);
  }
}
