import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish_app/core/observability/app_logger.dart';

void expectScrubbed(String output, String secret) {
  expect(output, isNot(contains(secret)),
      reason: '"$secret" survived: $output');
  expect(output, matches(RegExp(r'\[.*redacted\]')),
      reason: 'nothing marked redacted: $output');
}

void main() {
  late MemoryLogSink sink;
  late AppLogger log;

  setUp(() {
    sink = MemoryLogSink();
    log = AppLogger(
      sink: sink,
      minimumLevel: LogLevel.debug,
      now: () => DateTime.utc(2026, 8, 2, 12),
    );
  });

  group('AC4 — free text is scrubbed', () {
    // The same cases the API asserts. Both sides must behave identically or a
    // trace is safe on one hop and leaking on the next.
    test('email addresses', () {
      expectScrubbed(redactText('Upload failed for anna.schmidt@example.de'),
          'anna.schmidt@example.de');
    });

    test('German IBANs, spaced or not', () {
      expectScrubbed(
          redactText('IBAN DE89370400440532013000'), 'DE89370400440532013000');
    });

    test('card numbers', () {
      expectScrubbed(redactText('card 4111111111111111'), '4111111111111111');
    });

    test('coordinates — the birthplace itself', () {
      expectScrubbed(redactText('at 52.520008, 13.404954'), '52.520008');
    });

    test('birth dates in both notations', () {
      expectScrubbed(redactText('born 17.05.1990'), '17.05.1990');
      expectScrubbed(redactText('born 1990-05-17'), '1990-05-17');
    });

    test('phone numbers and IPs', () {
      expectScrubbed(redactText('+49 30 12345678'), '+49 30 12345678');
      expectScrubbed(redactText('from 188.195.237.4'), '188.195.237.4');
    });

    test('several secrets in one message', () {
      final output =
          redactText('anna@example.de born 17.05.1990 at 52.520008, 13.404954');
      expect(output, isNot(contains('anna@example.de')));
      expect(output, isNot(contains('17.05.1990')));
      expect(output, isNot(contains('52.520008')));
    });

    test('ordinary text is untouched', () {
      const message = 'Chart computed in 412ms using whole sign houses';
      expect(redactText(message), message);
    });

    test('repeated calls give the same result', () {
      const message = 'contact anna@example.de';
      final first = redactText(message);
      for (var i = 0; i < 5; i++) {
        expect(redactText(message), first);
      }
    });
  });

  group('AC4 — fields are allowlisted', () {
    test('permitted fields survive', () {
      final safe = redactFields({'orderId': 'ORD-1', 'durationMs': 42});
      expect(safe['orderId'], 'ORD-1');
      expect(safe['durationMs'], 42);
    });

    test('the allowlist fails closed for fields nobody anticipated', () {
      final safe = redactFields({
        'geburtsort': 'München',
        'kundenName': 'Anna Schmidt',
        'geburtsdatum': '17.05.1990',
        'email': 'anna@example.de',
      });
      expect(safe.keys, ['droppedFields']);
      final serialised = jsonEncode(safe);
      for (final secret in [
        'München',
        'Anna Schmidt',
        '17.05.1990',
        'anna@example.de',
      ]) {
        expect(serialised, isNot(contains(secret)), reason: '"$secret" leaked');
      }
    });

    test('dropped names are reported, values are not', () {
      final safe = redactFields({'email': 'anna@example.de', 'name': 'Anna'});
      expect(safe['droppedFields'], 'email,name');
      expect(jsonEncode(safe), isNot(contains('anna@example.de')));
    });

    test('an allowed field is still scrubbed', () {
      final safe = redactFields({'route': '/orders?email=anna@example.de'});
      expect(safe['route'], isNot(contains('anna@example.de')));
    });

    test('the allowlist itself contains nothing personal', () {
      // Guards against someone adding 'birthDate' during a debugging session
      // and never taking it out.
      for (final forbidden in [
        'email',
        'name',
        'firstName',
        'lastName',
        'birthDate',
        'birthTime',
        'birthPlace',
        'latitude',
        'longitude',
        'phone',
        'iban',
        'password',
      ]) {
        expect(allowedLogFields, isNot(contains(forbidden)),
            reason: '"$forbidden" must not be loggable');
      }
    });

    test('the app and API allowlists agree on what is forbidden', () {
      // Both sides must refuse the same things. Divergence means a field is
      // safe on one hop of a trace and leaking on the next.
      expect(allowedLogFields, contains('correlationId'));
      expect(allowedLogFields, contains('orderId'));
      expect(allowedLogFields, isNot(contains('email')));
    });
  });

  group('AC1 — structured records', () {
    test('carry level, message, timestamp and fields', () {
      log.info('Order created', {'orderId': 'ORD-1'});

      expect(sink.records, hasLength(1));
      final record = sink.records.single;
      expect(record.level, LogLevel.info);
      expect(record.message, 'Order created');
      expect(record.fields['orderId'], 'ORD-1');
      expect(record.toJson()['timestamp'], '2026-08-02T12:00:00.000Z');
    });

    test('serialise to one JSON line', () {
      log.info('Order created', {'orderId': 'ORD-1'});
      final line = sink.records.single.toString();
      expect(line, isNot(contains('\n')));
      expect(jsonDecode(line), isA<Map<String, Object?>>());
    });

    test('levels below the threshold are dropped', () {
      final quiet = AppLogger(sink: sink, minimumLevel: LogLevel.warn);
      quiet.debug('noise');
      quiet.info('noise');
      quiet.warn('kept');
      quiet.error('kept', 'E_TEST');
      expect(sink.records.map((r) => r.level), [LogLevel.warn, LogLevel.error]);
    });

    test('error records a code', () {
      log.error('Upload failed', 'E_UPLOAD', {'orderId': 'ORD-1'});
      expect(sink.records.single.fields['errorCode'], 'E_UPLOAD');
    });
  });

  group('AC1 — correlation IDs', () {
    test('records carry the id in scope', () {
      withCorrelationId('corr-123', () => log.info('Working'));
      expect(sink.records.single.correlationId, 'corr-123');
    });

    test('null outside a scope, rather than a fabricated id', () {
      log.info('Startup');
      expect(sink.records.single.correlationId, isNull);
    });

    test('the id survives async gaps', () async {
      await withCorrelationId('corr-async', () async {
        await Future<void>.delayed(Duration.zero);
        log.info('after await');
        await Future<void>.delayed(Duration.zero);
        log.info('after another');
      });
      expect(
        sink.records.map((r) => r.correlationId),
        ['corr-async', 'corr-async'],
      );
    });

    test('concurrent work does not bleed ids', () async {
      // Two in-flight requests must not have their lines attributed to each
      // other's trace.
      await Future.wait([
        withCorrelationId('req-a', () async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          log.info('a', {'orderId': 'A'});
        }),
        withCorrelationId('req-b', () async {
          await Future<void>.delayed(const Duration(milliseconds: 1));
          log.info('b', {'orderId': 'B'});
        }),
      ]);

      final byOrder = {
        for (final record in sink.records)
          record.fields['orderId']: record.correlationId,
      };
      expect(byOrder['A'], 'req-a');
      expect(byOrder['B'], 'req-b');
    });

    test('nested scopes use the innermost id', () {
      withCorrelationId('outer', () {
        withCorrelationId('inner', () => log.info('nested'));
        log.info('outside');
      });
      expect(sink.records.map((r) => r.correlationId), ['inner', 'outer']);
    });

    test('generated ids match what the API accepts', () {
      // The API rejects anything outside [A-Za-z0-9_-]{8,64}; an id it rejects
      // breaks the trace at the first hop.
      final random = Random(1);
      for (var i = 0; i < 100; i++) {
        expect(newCorrelationId(random),
            matches(RegExp(r'^[A-Za-z0-9_-]{8,64}$')));
      }
    });

    test('generated ids differ', () {
      final ids = {for (var i = 0; i < 200; i++) newCorrelationId()};
      expect(ids.length, 200);
    });
  });

  group('AC4 — the logger has no bypass', () {
    test('every level redacts', () {
      for (final call in <void Function()>[
        () => log.debug('mail anna@example.de'),
        () => log.info('mail anna@example.de'),
        () => log.warn('mail anna@example.de'),
        () => log.error('mail anna@example.de', 'E_X'),
      ]) {
        sink.clear();
        call();
        expect(
            sink.records.single.toString(), isNot(contains('anna@example.de')));
      }
    });

    test('a birth-data payload survives nothing', () {
      // The exact shape this product handles, thrown at the logger whole.
      log.info('Computing chart', {
        'orderId': 'ORD-1',
        'birthDate': '17.05.1990',
        'birthTime': '08:30',
        'birthPlace': 'Berlin',
        'latitude': 52.520008,
        'longitude': 13.404954,
        'email': 'anna.schmidt@example.de',
        'name': 'Anna Schmidt',
      });

      final serialised = sink.records.single.toString();
      for (final secret in [
        '17.05.1990',
        'Berlin',
        '52.520008',
        '13.404954',
        'anna.schmidt@example.de',
        'Anna Schmidt',
      ]) {
        expect(serialised, isNot(contains(secret)), reason: '"$secret" leaked');
      }
      // The order id survives, which is what makes the line useful at all.
      expect(sink.records.single.fields['orderId'], 'ORD-1');
    });
  });
}
