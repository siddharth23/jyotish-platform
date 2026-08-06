import { test, describe } from 'node:test';
import assert from 'node:assert/strict';

import {
  EmailAddressError,
  isValidEmail,
  localPartOf,
  normaliseEmail,
} from '../dist/modules/identity/email_address.js';

/** The code of the EmailAddressError thrown by `normaliseEmail(raw)`. */
function rejectionFor(raw) {
  try {
    normaliseEmail(raw);
    return null;
  } catch (error) {
    assert.ok(error instanceof EmailAddressError);
    return error.code;
  }
}

describe('normalising an address', () => {
  test('lowercases and trims', () => {
    assert.equal(normaliseEmail('  Anna.Beispiel@Example.DE  '), 'anna.beispiel@example.de');
  });

  test('accepts the forms real German addresses take', () => {
    for (const address of [
      'anna@gmx.de',
      'anna.beispiel@web.de',
      'anna+bestellung@example.de',
      'a_b-c@mail.example.co.uk',
      "o'neill@example.ie",
      'anna@münchen.de',
    ]) {
      assert.equal(isValidEmail(address), true, address);
    }
  });

  test('collapses compatibility forms so one mailbox is one account', () => {
    // NFKC folds the fullwidth characters an IME can produce.
    assert.equal(normaliseEmail('ａnna@example.de'), 'anna@example.de');
  });

  test('does not apply Gmail aliasing rules', () => {
    // Dots and +tags are Gmail's convention, not the internet's. Collapsing
    // them would let someone register the punctuation variant of another
    // person's address at a provider that treats them as distinct mailboxes.
    assert.notEqual(normaliseEmail('a.b@gmx.de'), normaliseEmail('ab@gmx.de'));
    assert.notEqual(normaliseEmail('a+x@gmx.de'), normaliseEmail('a@gmx.de'));
  });
});

describe('rejecting an address', () => {
  test('requires a local part and a domain', () => {
    assert.equal(rejectionFor('anna'), 'MALFORMED');
    assert.equal(rejectionFor('@example.de'), 'MALFORMED');
    assert.equal(rejectionFor('anna@'), 'MALFORMED');
  });

  test('rejects control characters and internal whitespace', () => {
    // A CR or LF reaching an SMTP client is header injection.
    assert.equal(rejectionFor('anna\r\nBcc: victim@example.de@example.de'), 'MALFORMED');
    assert.equal(rejectionFor('anna beispiel@example.de'), 'MALFORMED');
    assert.equal(rejectionFor('anna @example.de'), 'MALFORMED');
    assert.equal(rejectionFor('anna\u0000@example.de'), 'MALFORMED');
  });

  test('rejects a domain that is not a hostname', () => {
    assert.equal(rejectionFor('anna@localhost'), 'DOMAIN_INVALID');
    assert.equal(rejectionFor('anna@example..de'), 'DOMAIN_INVALID');
    assert.equal(rejectionFor('anna@-example.de'), 'DOMAIN_INVALID');
    assert.equal(rejectionFor('anna@example.123'), 'DOMAIN_INVALID');
    // An address literal is valid SMTP and a near-certain probe in a sign-up form.
    assert.equal(rejectionFor('anna@[192.0.2.1]'), 'DOMAIN_INVALID');
  });

  test('rejects quoted and dot-edged local parts', () => {
    assert.equal(rejectionFor('"anna beispiel"@example.de'), 'MALFORMED');
    assert.equal(rejectionFor('.anna@example.de'), 'MALFORMED');
    assert.equal(rejectionFor('anna.@example.de'), 'MALFORMED');
    assert.equal(rejectionFor('an..na@example.de'), 'MALFORMED');
  });

  test('enforces the RFC 5321 lengths', () => {
    assert.equal(rejectionFor(''), 'EMPTY');
    assert.equal(rejectionFor('   '), 'EMPTY');
    assert.equal(rejectionFor(`${'a'.repeat(65)}@example.de`), 'LOCAL_PART_TOO_LONG');
    assert.equal(rejectionFor(`${'a'.repeat(250)}@${'b'.repeat(250)}.de`), 'TOO_LONG');
  });
});

describe('localPartOf', () => {
  test('returns everything before the last @', () => {
    assert.equal(localPartOf('anna.beispiel@example.de'), 'anna.beispiel');
  });
});
