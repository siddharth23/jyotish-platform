/// Structured logging for the app, with the same redaction guarantees as the
/// API (US-007 AC1 and AC4).
///
/// The client is where personal data actually lives — birth date, time and
/// place are typed in here, held in memory here, and rendered here. A crash
/// reporter or log shipper that picks up an unredacted line takes it straight
/// off the device. `CLAUDE.md`: never log birth data, names, emails or payment
/// details.
///
/// Deliberately mirrors `api/src/observability/` rather than sharing code:
/// `shared/` is server-consumed and must stay AGPL-free, and a Dart package
/// there would be neither. The duplication is small and the tests on both sides
/// assert the same behaviour.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// Fields the app is permitted to log.
///
/// An allowlist, for the same reason as the API's: a denylist fails open the
/// moment someone adds a field it does not know about.
const Set<String> allowedLogFields = {
  'correlationId',
  'requestId',
  'sessionId',
  'orderId',
  'userId',
  'chartId',
  'evaluationId',
  'route',
  'statusCode',
  'durationMs',
  'attempt',
  'screen',
  'action',
  'orderState',
  'flagKey',
  'flagValue',
  'ruleSetVersion',
  'engineVersion',
  'locale',
  'platform',
  'appVersion',
  'errorCode',
  'errorType',
  'component',
  'operation',
  'networkStatus',
};

/// Patterns scrubbed from message text.
///
/// Kept in step with `api/src/observability/redaction.ts`; the API's test suite
/// and this one assert the same cases.
final List<({String name, RegExp pattern})> _textPatterns = [
  (
    name: 'email',
    pattern: RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+', caseSensitive: false)
  ),
  (name: 'iban', pattern: RegExp(r'\b[A-Z]{2}\d{2}(?:[ ]?[A-Z0-9]){10,30}\b')),
  (name: 'card', pattern: RegExp(r'\b(?:\d[ -]?){13,19}\b')),
  (
    name: 'coordinates',
    pattern: RegExp(r'\b-?\d{1,3}\.\d{4,}\s*,\s*-?\d{1,3}\.\d{4,}\b')
  ),
  (
    name: 'date',
    pattern: RegExp(r'\b\d{1,2}\.\d{1,2}\.\d{4}\b|\b\d{4}-\d{2}-\d{2}\b')
  ),
  (name: 'phone', pattern: RegExp(r'\b\+?\d[\d\s/-]{7,}\d\b')),
  (name: 'token', pattern: RegExp(r'\b(?:Bearer\s+)?[A-Za-z0-9_-]{32,}\b')),
  (name: 'ipv4', pattern: RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b')),
];

/// Removes anything matching [_textPatterns] from [input].
String redactText(String input) {
  var output = input;
  for (final entry in _textPatterns) {
    output = output.replaceAll(entry.pattern, '[${entry.name} redacted]');
  }
  return output;
}

/// Drops fields not on the allowlist and scrubs the values that remain.
Map<String, Object?> redactFields(Map<String, Object?> fields) {
  final safe = <String, Object?>{};
  final dropped = <String>[];

  for (final entry in fields.entries) {
    if (!allowedLogFields.contains(entry.key)) {
      dropped.add(entry.key);
      continue;
    }
    final value = entry.value;
    if (value == null) {
      safe[entry.key] = null;
    } else if (value is num || value is bool) {
      safe[entry.key] = value;
    } else {
      safe[entry.key] = redactText(value.toString());
    }
  }

  // Names, never values — enough for a developer to see which field to add to
  // the allowlist, without putting its contents in the log to find out.
  if (dropped.isNotEmpty) {
    dropped.sort();
    safe['droppedFields'] = dropped.join(',');
  }
  return safe;
}

enum LogLevel { debug, info, warn, error }

@immutable
class LogRecord {
  const LogRecord({
    required this.timestamp,
    required this.level,
    required this.message,
    required this.correlationId,
    required this.fields,
  });

  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? correlationId;
  final Map<String, Object?> fields;

  Map<String, Object?> toJson() => {
        'timestamp': timestamp.toUtc().toIso8601String(),
        'level': level.name,
        'message': message,
        'correlationId': correlationId,
        'fields': fields,
      };

  @override
  String toString() => jsonEncode(toJson());
}

/// Where records go.
abstract interface class LogSink {
  void write(LogRecord record);
}

/// Prints in debug builds and discards in release.
///
/// Release builds must not print to the device log, which is readable by other
/// tooling on the device. A crash reporter is wired in here later, and it
/// receives records that are already redacted.
class ConsoleLogSink implements LogSink {
  const ConsoleLogSink();

  @override
  void write(LogRecord record) {
    if (kDebugMode) debugPrint(record.toString());
  }
}

/// Keeps records in memory, for tests.
class MemoryLogSink implements LogSink {
  final List<LogRecord> records = [];

  @override
  void write(LogRecord record) => records.add(record);

  void clear() => records.clear();
}

/// Carries the correlation id across async gaps within a request.
final _correlationKey = Object();

/// Runs [body] with [correlationId] attached to every record logged inside it.
///
/// Uses a Zone rather than threading the id through call signatures, so a path
/// added later cannot forget to pass it — that path is invariably the one being
/// investigated during an incident.
T withCorrelationId<T>(String correlationId, T Function() body) {
  return runZoned(body, zoneValues: {_correlationKey: correlationId});
}

/// The correlation id in scope, if any.
String? currentCorrelationId() => Zone.current[_correlationKey] as String?;

/// Generates a correlation id for an outbound request.
///
/// Sent to the API as `X-Correlation-ID` so one identifier ties a user's tap to
/// the server work it caused. Format matches what the API accepts.
String newCorrelationId([Random? random]) {
  const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rng = random ?? Random();
  return List.generate(24, (_) => alphabet[rng.nextInt(alphabet.length)])
      .join();
}

/// The app's logger. Every message and field is redacted; there is no bypass.
class AppLogger {
  const AppLogger({
    LogSink sink = const ConsoleLogSink(),
    LogLevel minimumLevel = LogLevel.info,
    DateTime Function()? now,
  })  : _sink = sink,
        _minimumLevel = minimumLevel,
        _now = now;

  final LogSink _sink;
  final LogLevel _minimumLevel;
  final DateTime Function()? _now;

  void debug(String message, [Map<String, Object?> fields = const {}]) =>
      _log(LogLevel.debug, message, fields);

  void info(String message, [Map<String, Object?> fields = const {}]) =>
      _log(LogLevel.info, message, fields);

  void warn(String message, [Map<String, Object?> fields = const {}]) =>
      _log(LogLevel.warn, message, fields);

  /// Logs an error by code.
  ///
  /// Takes a code rather than an exception: a Dart exception's `toString()`
  /// routinely contains the value that caused it, which for this product means
  /// a birth date or an email.
  void error(
    String message,
    String errorCode, [
    Map<String, Object?> fields = const {},
  ]) =>
      _log(LogLevel.error, message, {...fields, 'errorCode': errorCode});

  void _log(LogLevel level, String message, Map<String, Object?> fields) {
    if (level.index < _minimumLevel.index) return;
    _sink.write(
      LogRecord(
        timestamp: _now?.call() ?? DateTime.now(),
        level: level,
        message: redactText(message),
        correlationId: currentCorrelationId(),
        fields: redactFields(fields),
      ),
    );
  }
}
