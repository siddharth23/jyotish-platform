import { test, describe, beforeEach } from 'node:test';
import assert from 'node:assert/strict';

import {
  Logger,
  MemorySink,
  withCorrelationId,
  currentCorrelationId,
  acceptCorrelationId,
} from '../dist/observability/logger.js';

let sink;
let log;

beforeEach(() => {
  sink = new MemorySink();
  log = new Logger(sink, 'debug', () => new Date('2026-08-02T12:00:00Z'));
});

describe('US-007 AC1 — structured records', () => {
  test('one record per call, with level and timestamp', () => {
    log.info('Order created', { orderId: 'ORD-1' });

    assert.equal(sink.records.length, 1);
    const [record] = sink.records;
    assert.equal(record.level, 'info');
    assert.equal(record.message, 'Order created');
    assert.equal(record.timestamp, '2026-08-02T12:00:00.000Z');
    assert.equal(record.fields.orderId, 'ORD-1');
  });

  test('records serialise to a single JSON line', () => {
    // A log aggregator indexes fields; a multi-line record breaks line-based
    // ingestion and turns one event into several.
    log.info('Order created', { orderId: 'ORD-1' });
    const line = JSON.stringify(sink.records[0]);
    assert.ok(!line.includes('\n'));
    assert.deepEqual(JSON.parse(line).fields.orderId, 'ORD-1');
  });

  test('levels below the threshold are dropped', () => {
    const quiet = new Logger(sink, 'warn');
    quiet.debug('noise');
    quiet.info('noise');
    quiet.warn('kept');
    quiet.error('kept', 'E_TEST');
    assert.deepEqual(sink.records.map((r) => r.level), ['warn', 'error']);
  });

  test('error takes a code, not an Error object', () => {
    // A stack trace or exception message routinely contains the value that
    // caused it — the email that failed validation, the row that failed to
    // parse. Passing one to a sink is how personal data escapes.
    log.error('Payment failed', 'E_PAYMENT_DECLINED', { orderId: 'ORD-1' });
    assert.equal(sink.records[0].fields.errorCode, 'E_PAYMENT_DECLINED');
  });
});

describe('US-007 AC1 — correlation IDs', () => {
  test('records carry the id in scope', () => {
    withCorrelationId('corr-123', () => log.info('Handling request'));
    assert.equal(sink.records[0].correlationId, 'corr-123');
  });

  test('null outside any scope, rather than a fake id', () => {
    log.info('Startup');
    assert.equal(sink.records[0].correlationId, null);
  });

  test('the id survives await boundaries', async () => {
    // The reason for AsyncLocalStorage: threading the id through every
    // signature means the one path that forgets is the one that breaks an
    // incident investigation, and it is always a path added later.
    await withCorrelationId('corr-async', async () => {
      await new Promise((resolve) => setTimeout(resolve, 1));
      log.info('after await');
      await Promise.resolve();
      log.info('after another await');
    });
    assert.deepEqual(
      sink.records.map((r) => r.correlationId),
      ['corr-async', 'corr-async'],
    );
  });

  test('concurrent requests do not bleed into each other', async () => {
    // The failure this guards is subtle and awful: two requests interleaving
    // and one's log lines being attributed to the other's correlation id.
    await Promise.all([
      withCorrelationId('req-a', async () => {
        await new Promise((resolve) => setTimeout(resolve, 5));
        log.info('a', { orderId: 'A' });
      }),
      withCorrelationId('req-b', async () => {
        await new Promise((resolve) => setTimeout(resolve, 1));
        log.info('b', { orderId: 'B' });
      }),
    ]);

    const byOrder = Object.fromEntries(
      sink.records.map((r) => [r.fields.orderId, r.correlationId]),
    );
    assert.equal(byOrder.A, 'req-a');
    assert.equal(byOrder.B, 'req-b');
  });

  test('nested scopes use the innermost id', () => {
    withCorrelationId('outer', () => {
      withCorrelationId('inner', () => log.info('nested'));
      log.info('back outside');
    });
    assert.deepEqual(
      sink.records.map((r) => r.correlationId),
      ['inner', 'outer'],
    );
  });

  test('currentCorrelationId reports the scope', () => {
    assert.equal(currentCorrelationId(), null);
    withCorrelationId('x-1', () => assert.equal(currentCorrelationId(), 'x-1'));
  });
});

describe('An inbound correlation id is untrusted input', () => {
  test('a well-formed id is kept, so a trace spans app and API', () => {
    assert.equal(acceptCorrelationId('abc123-XYZ_456'), 'abc123-XYZ_456');
  });

  test('a missing id is minted', () => {
    const generated = acceptCorrelationId(null);
    assert.match(generated, /^[0-9a-f-]{36}$/);
    assert.notEqual(generated, acceptCorrelationId(undefined));
  });

  test('an id that could break a log line is replaced', () => {
    // It lands in logs and every downstream system; newlines would forge a
    // second record, angle brackets could be read as markup.
    for (const hostile of [
      'abc\ndef-injected-line',
      '<script>alertalertalert</script>',
      'a'.repeat(200),
      'short',
      '',
      '   ',
    ]) {
      const accepted = acceptCorrelationId(hostile);
      assert.match(accepted, /^[A-Za-z0-9_-]{8,64}$/, `rejected badly: ${accepted}`);
      assert.notEqual(accepted, hostile);
    }
  });
});

describe('US-007 AC4 — the logger cannot be talked into leaking', () => {
  test('a message containing an email is scrubbed', () => {
    log.info('Could not deliver to anna@example.de');
    assert.ok(!sink.records[0].message.includes('anna@example.de'));
  });

  test('personal fields never reach the sink', () => {
    log.info('Order created', {
      orderId: 'ORD-1',
      email: 'anna@example.de',
      birthDate: '17.05.1990',
      birthPlace: 'München',
    });

    const serialised = JSON.stringify(sink.records[0]);
    for (const secret of ['anna@example.de', '17.05.1990', 'München']) {
      assert.ok(!serialised.includes(secret), `"${secret}" reached the sink`);
    }
    assert.equal(sink.records[0].fields.orderId, 'ORD-1');
  });

  test('there is no bypass', () => {
    // Every level goes through redaction. A logger with an "unsafe" escape
    // hatch grows callers, and the hatch is what gets used at 2am.
    for (const call of [
      () => log.debug('mail anna@example.de'),
      () => log.info('mail anna@example.de'),
      () => log.warn('mail anna@example.de'),
      () => log.error('mail anna@example.de', 'E_X'),
    ]) {
      sink.clear();
      call();
      assert.ok(!JSON.stringify(sink.records[0]).includes('anna@example.de'));
    }
  });
});
