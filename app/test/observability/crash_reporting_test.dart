import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish_app/core/observability/app_logger.dart';
import 'package:jyotish_app/core/observability/crash_reporter.dart';
import 'package:jyotish_app/core/observability/session_tracker.dart';
import 'package:jyotish_app/core/observability/telemetry_consent.dart';
import 'package:shared_preferences/shared_preferences.dart';

const granted = TelemetryConsent(
  crashReporting: ConsentState.granted,
  performance: ConsentState.granted,
);
const denied = TelemetryConsent(
  crashReporting: ConsentState.denied,
  performance: ConsentState.denied,
);

CrashReporter reporterWith(
  RecordingCrashTransport transport, {
  TelemetryConsent consent = TelemetryConsent.none,
  int bufferLimit = 20,
}) =>
    CrashReporter(
      transport: transport,
      appVersion: '1.0.0',
      consent: consent,
      bufferLimit: bufferLimit,
      now: () => DateTime.utc(2026, 8, 2, 12),
    );

/// Mounts a consent controller so it has a live provider element.
///
/// A Riverpod 3 Notifier takes `ref` and `state` from the element, so one that
/// is only constructed throws "uninitialized state" the first time anything
/// reads or writes its state. Reading the provider once runs `build`.
TelemetryConsentController mountedConsent(TelemetryConsentController c) {
  final container = ProviderContainer(
    overrides: [telemetryConsentProvider.overrideWith(() => c)],
  );
  addTearDown(container.dispose);
  container.read(telemetryConsentProvider);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AC4 — nothing leaves the device without consent', () {
    // COMPLIANCE.md: "CMP fires before any analytics or crash SDK."
    test('a crash before any decision is not sent', () async {
      final transport = RecordingCrashTransport();
      final reporter = reporterWith(transport);

      await reporter.recordCrash(StateError('boom'), StackTrace.current);

      expect(transport.sent, isEmpty);
      expect(reporter.pendingCount, 1);
    });

    test('a crash after refusal is not sent, and not buffered either',
        () async {
      // Nothing that happens later makes sending these lawful, so holding on to
      // them serves no purpose.
      final transport = RecordingCrashTransport();
      final reporter = reporterWith(transport, consent: denied);

      await reporter.recordCrash(StateError('boom'), StackTrace.current);

      expect(transport.sent, isEmpty);
      expect(reporter.pendingCount, 0);
    });

    test('a crash after consent is sent', () async {
      final transport = RecordingCrashTransport();
      final reporter = reporterWith(transport, consent: granted);

      await reporter.recordCrash(StateError('boom'), StackTrace.current);

      expect(transport.sent, hasLength(1));
      expect(transport.sent.single.isFatal, isTrue);
    });

    test('granting consent flushes what was buffered', () async {
      final transport = RecordingCrashTransport();
      final reporter = reporterWith(transport);

      await reporter.recordCrash(StateError('one'), StackTrace.current);
      await reporter.recordError(ArgumentError('two'), StackTrace.current);
      expect(transport.sent, isEmpty);

      await reporter.updateConsent(granted);

      expect(transport.sent, hasLength(2));
      expect(reporter.pendingCount, 0);
    });

    test('refusing discards the buffer instead of sending it', () async {
      // The failure this guards: a user taps "reject all" and their
      // pre-decision crashes are transmitted anyway.
      final transport = RecordingCrashTransport();
      final reporter = reporterWith(transport);

      await reporter.recordCrash(StateError('boom'), StackTrace.current);
      expect(reporter.pendingCount, 1);

      await reporter.updateConsent(denied);

      expect(transport.sent, isEmpty);
      expect(reporter.pendingCount, 0);
    });

    test('withdrawing consent stops sending immediately', () async {
      final transport = RecordingCrashTransport();
      final reporter = reporterWith(transport, consent: granted);

      await reporter.recordCrash(StateError('first'), StackTrace.current);
      expect(transport.sent, hasLength(1));

      await reporter.updateConsent(denied);
      await reporter.recordCrash(StateError('second'), StackTrace.current);

      expect(transport.sent, hasLength(1), reason: 'sent after withdrawal');
    });

    test('the buffer is capped, keeping the earliest crashes', () async {
      // A crash loop must not evict the first crash, which is the one that
      // explains the others.
      final transport = RecordingCrashTransport();
      final reporter = reporterWith(transport, bufferLimit: 3);

      for (var i = 0; i < 50; i++) {
        await reporter.recordCrash(StateError('crash $i'), StackTrace.current);
      }
      expect(reporter.pendingCount, 3);

      await reporter.updateConsent(granted);
      expect(transport.sent, hasLength(3));
    });

    test('performance consent alone does not permit crash reports', () async {
      // Categories are separate; consenting to one is not consenting to both.
      final transport = RecordingCrashTransport();
      final reporter = reporterWith(
        transport,
        consent: const TelemetryConsent(
          crashReporting: ConsentState.denied,
          performance: ConsentState.granted,
        ),
      );
      await reporter.recordCrash(StateError('boom'), StackTrace.current);
      expect(transport.sent, isEmpty);
    });
  });

  group('AC4 — reports carry no personal data', () {
    test('the exception message is never included, only its type', () async {
      // `FormatException: invalid date "17.05.1990"` is a stack frame with a
      // birth date in it.
      final transport = RecordingCrashTransport();
      final reporter = reporterWith(transport, consent: granted);

      await reporter.recordCrash(
        const FormatException('invalid date "17.05.1990" for anna@example.de'),
        StackTrace.current,
      );

      final serialised = transport.sent.single.toJson().toString();
      expect(serialised, isNot(contains('17.05.1990')));
      expect(serialised, isNot(contains('anna@example.de')));
      expect(transport.sent.single.errorType, 'FormatException');
    });

    test('context fields are allowlisted', () async {
      final transport = RecordingCrashTransport();
      final reporter = reporterWith(transport, consent: granted);

      await reporter.recordCrash(
        StateError('boom'),
        StackTrace.current,
        context: {
          'orderId': 'ORD-1',
          'email': 'anna@example.de',
          'birthPlace': 'München',
        },
      );

      final report = transport.sent.single;
      expect(report.context['orderId'], 'ORD-1');
      expect(report.context.containsKey('email'), isFalse);
      expect(report.toJson().toString(), isNot(contains('München')));
    });

    test('the stack trace is redacted', () async {
      final transport = RecordingCrashTransport();
      final reporter = reporterWith(transport, consent: granted);

      await reporter.recordCrash(
        StateError('boom'),
        StackTrace.fromString(
            '#0 parse (file.dart) anna@example.de 17.05.1990'),
      );

      final trace = transport.sent.single.stackTrace;
      expect(trace, isNot(contains('anna@example.de')));
      expect(trace, isNot(contains('17.05.1990')));
    });

    test('the correlation id ties a crash to its request', () async {
      final transport = RecordingCrashTransport();
      final reporter = reporterWith(transport, consent: granted);

      await withCorrelationId('corr-crash', () async {
        await reporter.recordCrash(StateError('boom'), StackTrace.current);
      });

      expect(transport.sent.single.correlationId, 'corr-crash');
    });
  });

  group('Consent state', () {
    test('only "granted" permits collection', () {
      // Written as a positive test against one value rather than != denied,
      // which would treat "not asked yet" as permission.
      expect(TelemetryConsent.none.allows(TelemetryCategory.crashReporting),
          isFalse);
      expect(denied.allows(TelemetryCategory.crashReporting), isFalse);
      expect(granted.allows(TelemetryCategory.crashReporting), isTrue);
    });

    test('unknown is distinct from denied', () {
      expect(TelemetryConsent.none.needsDecision, isTrue);
      expect(denied.needsDecision, isFalse);
      expect(granted.needsDecision, isFalse);
    });

    test('a partial decision still needs asking', () {
      const partial = TelemetryConsent(crashReporting: ConsentState.granted);
      expect(partial.needsDecision, isTrue);
    });

    test('a corrupted stored value reads as undecided, never granted', () {
      for (final corrupt in ['yes', 'true', '', 'GRANTED', null]) {
        final restored = TelemetryConsent.fromStorage({
          'crashReporting': corrupt,
          'performance': corrupt,
        });
        expect(
          restored.allows(TelemetryCategory.crashReporting),
          isFalse,
          reason: 'stored "$corrupt" was treated as consent',
        );
      }
    });

    test('a stored decision round-trips', () {
      final restored = TelemetryConsent.fromStorage(granted.toStorage());
      expect(restored, granted);
    });
  });

  group('Consent persistence', () {
    test('a decision survives a restart', () async {
      final first = mountedConsent(TelemetryConsentController(
        preferences: await SharedPreferences.getInstance(),
      ));
      await first.set(TelemetryCategory.crashReporting, ConsentState.granted);

      final second = mountedConsent(TelemetryConsentController(
        preferences: await SharedPreferences.getInstance(),
      ));
      await Future<void>.delayed(Duration.zero);
      expect(second.state.allows(TelemetryCategory.crashReporting), isTrue);
    });

    test('reject-all is exactly as available as accept-all', () async {
      // COMPLIANCE.md requires reject-all to be as prominent as accept-all;
      // that starts with both being one call.
      final controller = mountedConsent(TelemetryConsentController(
        preferences: await SharedPreferences.getInstance(),
      ));
      await controller.grantAll();
      expect(controller.state.needsDecision, isFalse);
      expect(controller.state.allows(TelemetryCategory.performance), isTrue);

      await controller.denyAll();
      expect(
          controller.state.allows(TelemetryCategory.crashReporting), isFalse);
      expect(controller.state.allows(TelemetryCategory.performance), isFalse);
    });

    test('withdrawal returns to undecided so the CMP asks again', () async {
      final controller = mountedConsent(TelemetryConsentController(
        preferences: await SharedPreferences.getInstance(),
      ));
      await controller.grantAll();
      await controller.reset();
      expect(controller.state, TelemetryConsent.none);
      expect(controller.state.needsDecision, isTrue);
    });

    test('a refusal is not undone by a slow disk read', () async {
      // The dangerous direction of the restore race: storage holds a previous
      // "granted", the user taps reject-all while the read is still in flight,
      // and the read resolves and silently re-grants. Crash reports would then
      // flow from someone who had just refused.
      SharedPreferences.setMockInitialValues({
        'consent_crash_reporting': 'granted',
        'consent_performance': 'granted',
      });
      final controller = mountedConsent(TelemetryConsentController(
        preferences: await SharedPreferences.getInstance(),
      ));

      // Decide immediately, before the restore future resolves.
      await controller.denyAll();
      // Let any in-flight restore complete.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.state.allows(TelemetryCategory.crashReporting),
        isFalse,
        reason: 'a stale read re-granted consent the user had refused',
      );
    });

    test('a fresh install consents to nothing', () async {
      final controller = mountedConsent(TelemetryConsentController(
        preferences: await SharedPreferences.getInstance(),
      ));
      await Future<void>.delayed(Duration.zero);
      for (final category in TelemetryCategory.values) {
        expect(controller.state.allows(category), isFalse);
      }
    });
  });

  group('AC1 — crash-free session rate', () {
    Future<SessionTracker> tracker([String version = '1.0.0']) async =>
        SessionTracker(
          appVersion: version,
          preferences: await SharedPreferences.getInstance(),
        );

    test('a clean session is not counted as a crash', () async {
      final sessions = await tracker();
      expect(await sessions.startSession(), isFalse);
      await sessions.endSession();
      expect(await sessions.startSession(), isFalse);

      final rate = await sessions.currentRate();
      expect(rate.totalSessions, 2);
      expect(rate.crashedSessions, 0);
      expect(rate.percentage, 100);
    });

    test('a session that never ended is counted as a crash on next launch',
        () async {
      // There is no "the process was killed" callback; an unclosed session on
      // the next start is the only available signal.
      final sessions = await tracker();
      await sessions.startSession();
      // No endSession — the app died.
      expect(await sessions.startSession(), isTrue);

      final rate = await sessions.currentRate();
      expect(rate.crashedSessions, 1);
      expect(rate.totalSessions, 2);
      expect(rate.percentage, 50);
    });

    test('a crash is attributed to the version that was running', () async {
      // Otherwise a release that fixes a crash inherits it from its
      // predecessor and looks worse than it is.
      final old = await tracker('1.0.0');
      await old.startSession();

      final updated = await tracker('1.1.0');
      expect(await updated.startSession(), isTrue);

      expect((await updated.rateFor('1.0.0')).crashedSessions, 1);
      expect((await updated.rateFor('1.1.0')).crashedSessions, 0);
    });

    test('rates are per release, not lifetime', () async {
      final old = await tracker('1.0.0');
      await old.startSession();
      await old.endSession();

      final updated = await tracker('2.0.0');
      await updated.startSession();
      await updated.endSession();

      expect((await updated.rateFor('1.0.0')).totalSessions, 1);
      expect((await updated.rateFor('2.0.0')).totalSessions, 1);
      expect((await updated.allRates()).length, 2);
    });

    test('old version counters can be pruned', () async {
      final old = await tracker('1.0.0');
      await old.startSession();
      await old.endSession();

      final updated = await tracker('2.0.0');
      await updated.startSession();
      await updated.pruneOtherVersions();

      final remaining = await updated.allRates();
      expect(remaining.map((r) => r.appVersion), ['2.0.0']);
    });
  });

  group('AC3 — the 99% threshold', () {
    test('a healthy release does not breach', () {
      const rate = CrashFreeRate(
        appVersion: '1.0.0',
        totalSessions: 1000,
        crashedSessions: 5,
      );
      expect(rate.percentage, 99.5);
      expect(rate.breaches(), isFalse);
    });

    test('an unhealthy release breaches', () {
      const rate = CrashFreeRate(
        appVersion: '1.0.0',
        totalSessions: 1000,
        crashedSessions: 20,
      );
      expect(rate.percentage, 98.0);
      expect(rate.breaches(), isTrue);
    });

    test('a tiny sample does not breach, however bad it looks', () {
      // One crash in the first three sessions of a release is 67% and means
      // nothing. Alerting on it would page someone on every release.
      const rate = CrashFreeRate(
        appVersion: '1.0.0',
        totalSessions: 3,
        crashedSessions: 1,
      );
      expect(rate.percentage, closeTo(66.7, 0.1));
      expect(rate.breaches(), isFalse);
    });

    test('a release nobody has run yet reports 100%, not 0%', () {
      // Zero would read as a total outage and page someone the moment a
      // release is cut.
      const rate = CrashFreeRate(
        appVersion: '9.9.9',
        totalSessions: 0,
        crashedSessions: 0,
      );
      expect(rate.percentage, 100);
      expect(rate.breaches(), isFalse);
    });

    test('exactly 99.0% does not breach; just under does', () {
      const atThreshold = CrashFreeRate(
        appVersion: '1.0.0',
        totalSessions: 1000,
        crashedSessions: 10,
      );
      expect(atThreshold.percentage, 99.0);
      expect(atThreshold.breaches(), isFalse);

      const under = CrashFreeRate(
        appVersion: '1.0.0',
        totalSessions: 1000,
        crashedSessions: 11,
      );
      expect(under.breaches(), isTrue);
    });
  });
}
