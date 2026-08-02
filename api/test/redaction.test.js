import { test, describe } from 'node:test';
import assert from 'node:assert/strict';

import {
  redactText,
  redactFields,
  ALLOWED_FIELDS,
  REDACTED,
} from '../dist/observability/redaction.js';

/** Asserts the raw value is gone and something was marked as removed. */
function assertScrubbed(output, secret) {
  assert.ok(!output.includes(secret), `"${secret}" survived redaction in: ${output}`);
  assert.match(output, /\[.*redacted\]/, `nothing was marked redacted in: ${output}`);
}

describe('US-007 AC4 — free text is scrubbed', () => {
  test('email addresses', () => {
    assertScrubbed(
      redactText('Order failed for anna.schmidt@example.de'),
      'anna.schmidt@example.de',
    );
  });

  test('German IBANs', () => {
    assertScrubbed(
      redactText('Refund to DE89370400440532013000 failed'),
      'DE89370400440532013000',
    );
  });

  test('card numbers, spaced or not', () => {
    assertScrubbed(redactText('card 4111111111111111 declined'), '4111111111111111');
    assertScrubbed(redactText('card 4111 1111 1111 1111 declined'), '4111 1111 1111 1111');
  });

  test('coordinates — a birthplace to within metres', () => {
    assertScrubbed(redactText('chart at 52.520008, 13.404954'), '52.520008');
  });

  test('birth dates, German and ISO', () => {
    assertScrubbed(redactText('born 17.05.1990'), '17.05.1990');
    assertScrubbed(redactText('born 1990-05-17'), '1990-05-17');
  });

  test('phone numbers', () => {
    assertScrubbed(redactText('called +49 30 12345678'), '+49 30 12345678');
  });

  test('bearer tokens', () => {
    const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9abcdefghij';
    assertScrubbed(redactText(`Authorization: Bearer ${token}`), token);
  });

  test('IP addresses — personal data under GDPR', () => {
    assertScrubbed(redactText('from 188.195.237.4'), '188.195.237.4');
  });

  test('several secrets in one line are all removed', () => {
    const output = redactText('anna@example.de born 17.05.1990 at 52.520008, 13.404954');
    assert.ok(!output.includes('anna@example.de'));
    assert.ok(!output.includes('17.05.1990'));
    assert.ok(!output.includes('52.520008'));
  });

  test('ordinary text is left alone', () => {
    const message = 'Order transitioned to IN_REVIEW after 3 attempts';
    assert.equal(redactText(message), message);
  });

  test('redaction is stable across calls', () => {
    // A shared /g regex carries lastIndex between calls and would skip matches
    // on the second message — the second user's data would leak.
    const message = 'contact anna@example.de';
    const first = redactText(message);
    for (let i = 0; i < 5; i++) {
      assert.equal(redactText(message), first, `call ${i + 2} differed`);
    }
  });
});

describe('US-007 AC4 — structured fields are allowlisted', () => {
  test('permitted fields survive', () => {
    const safe = redactFields({ orderId: 'ORD-1', statusCode: 200, durationMs: 42 });
    assert.equal(safe.orderId, 'ORD-1');
    assert.equal(safe.statusCode, 200);
    assert.equal(safe.durationMs, 42);
  });

  test('anything not on the list is dropped', () => {
    const safe = redactFields({
      email: 'anna@example.de',
      birthDate: '1990-05-17',
      name: 'Anna Schmidt',
      orderId: 'ORD-1',
    });
    assert.equal(safe.email, undefined);
    assert.equal(safe.birthDate, undefined);
    assert.equal(safe.name, undefined);
    assert.equal(safe.orderId, 'ORD-1');
  });

  test('the allowlist fails closed for a field nobody anticipated', () => {
    // The whole reason this is an allowlist. A denylist keyed on 'email' and
    // 'birthDate' would pass every one of these straight through.
    const safe = redactFields({
      geburtsort: 'München',
      customerMail: 'anna@example.de',
      kundenName: 'Anna Schmidt',
      geburtsdatum: '17.05.1990',
      zahlungsdetails: 'DE89370400440532013000',
    });
    assert.deepEqual(Object.keys(safe), ['droppedFields']);
    const serialised = JSON.stringify(safe);
    for (const secret of ['München', 'anna@example.de', 'Anna Schmidt', '17.05.1990']) {
      assert.ok(!serialised.includes(secret), `"${secret}" leaked`);
    }
  });

  test('dropped field names are reported, values never are', () => {
    // Otherwise a developer sees their field vanish and assumes the logger is
    // broken. The name is enough to know what to add to the allowlist.
    const safe = redactFields({ email: 'anna@example.de', name: 'Anna' });
    assert.equal(safe.droppedFields, 'email,name');
    assert.ok(!JSON.stringify(safe).includes('anna@example.de'));
    assert.ok(!JSON.stringify(safe).includes('Anna'));
  });

  test('an allowed field is still scrubbed', () => {
    // Being on the list permits the field, not whatever ended up inside it.
    const safe = redactFields({ route: '/orders?email=anna@example.de' });
    assert.ok(!String(safe.route).includes('anna@example.de'));
  });

  test('null and undefined become null rather than the string "undefined"', () => {
    const safe = redactFields({ orderId: null, userId: undefined });
    assert.equal(safe.orderId, null);
    assert.equal(safe.userId, null);
  });

  test('the allowlist contains no obviously personal field', () => {
    // A guard on the allowlist itself: the danger is someone adding 'email'
    // here during a debugging session and never taking it out.
    const forbidden = [
      'email', 'name', 'firstName', 'lastName', 'birthDate', 'birthTime',
      'birthPlace', 'latitude', 'longitude', 'phone', 'iban', 'card',
      'address', 'password', 'token',
    ];
    for (const field of forbidden) {
      assert.ok(!ALLOWED_FIELDS.has(field), `"${field}" must not be loggable`);
    }
  });

  test('REDACTED is exported for callers that need a placeholder', () => {
    assert.equal(typeof REDACTED, 'string');
  });
});
