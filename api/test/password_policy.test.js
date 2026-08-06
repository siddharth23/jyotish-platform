import { test, describe } from 'node:test';
import assert from 'node:assert/strict';

import {
  breachHash,
  InMemoryBreachList,
  MINIMUM_PASSWORD_LENGTH,
  MAXIMUM_PASSWORD_LENGTH,
  normalisePassword,
  passwordLength,
  PasswordPolicy,
} from '../dist/modules/identity/password_policy.js';

/** Synthetic, not drawn from any real breach corpus. */
const BREACHED = ['sonnenschein', 'lieblingsfarbe1', 'ichliebedich'];

function makePolicy(options = {}, breachList = InMemoryBreachList.fromPasswords(BREACHED)) {
  return new PasswordPolicy(breachList, options);
}

/** A breach list that always fails, standing in for an outage. */
const failingBreachList = {
  async suffixesFor() {
    throw new Error('breach list unreachable');
  },
};

describe('US-011 AC2 — minimum ten characters', () => {
  test('the minimum is ten', () => {
    assert.equal(MINIMUM_PASSWORD_LENGTH, 10);
  });

  test('rejects nine, accepts ten', async () => {
    const policy = makePolicy();
    assert.deepEqual((await policy.check('kurz-2718')).rejections, ['TOO_SHORT']);
    assert.equal((await policy.check('kurz-27182')).acceptable, true);
  });

  test('counts code points, not UTF-16 units', async () => {
    // Five astral characters are ten UTF-16 units. A String.length check would
    // wave this through as "ten characters".
    const fiveEmoji = '🌙🌞🪐🔭🧿';
    assert.equal(fiveEmoji.length, 10);
    assert.equal(passwordLength(fiveEmoji), 5);
    assert.deepEqual((await makePolicy().check(fiveEmoji)).rejections, ['TOO_SHORT']);
  });

  test('accepts long passphrases and caps only absurd input', async () => {
    const policy = makePolicy();
    assert.equal((await policy.check('a'.repeat(64) + 'b'.repeat(64))).acceptable, true);
    const tooLong = 'x'.repeat(MAXIMUM_PASSWORD_LENGTH + 1);
    assert.ok((await policy.check(tooLong)).rejections.includes('TOO_LONG'));
  });

  test('imposes no composition rules', async () => {
    // NIST SP 800-63B deprecates them: they produce Passwort1!, not entropy.
    const policy = makePolicy();
    assert.equal((await policy.check('graureiherfeder')).acceptable, true);
  });
});

describe('US-011 AC2 — breach-list check', () => {
  test('rejects a password on the list', async () => {
    const verdict = await makePolicy().check('sonnenschein');
    assert.equal(verdict.acceptable, false);
    assert.deepEqual(verdict.rejections, ['BREACHED']);
  });

  test('accepts one that is not', async () => {
    assert.equal((await makePolicy().check('graureiherfeder')).acceptable, true);
  });

  test('queries by five-character prefix and never sends the password', async () => {
    const seen = [];
    const spy = {
      async suffixesFor(prefix) {
        seen.push(prefix);
        return new Set();
      },
    };
    await makePolicy({}, spy).check('graureiherfeder');
    assert.equal(seen.length, 1);
    // k-anonymity: a five-hex-character prefix, which is all a remote list gets.
    assert.match(seen[0], /^[0-9A-F]{5}$/);
    assert.equal(seen[0], breachHash('graureiherfeder').slice(0, 5));
  });

  test('rejects by default when the list cannot answer', async () => {
    // The outage ends; a weak password chosen during it does not.
    const verdict = await makePolicy({}, failingBreachList).check('graureiherfeder');
    assert.equal(verdict.acceptable, false);
    assert.deepEqual(verdict.rejections, ['BREACH_CHECK_UNAVAILABLE']);
  });

  test('can be configured to accept during an outage', async () => {
    const policy = makePolicy({ whenBreachListUnavailable: 'accept' }, failingBreachList);
    assert.equal((await policy.check('graureiherfeder')).acceptable, true);
  });

  test('skips the lookup for a password already over the cap', async () => {
    let calls = 0;
    const spy = {
      async suffixesFor() {
        calls += 1;
        return new Set();
      },
    };
    await makePolicy({}, spy).check('x'.repeat(MAXIMUM_PASSWORD_LENGTH + 1));
    assert.equal(calls, 0);
  });
});

describe('blocklisted shapes', () => {
  test('rejects a single repeated character and a straight run', async () => {
    const policy = makePolicy();
    assert.ok((await policy.check('aaaaaaaaaa')).rejections.includes('REPETITIVE'));
    assert.ok((await policy.check('abcdefghij')).rejections.includes('REPETITIVE'));
    assert.ok((await policy.check('9876543210')).rejections.includes('REPETITIVE'));
  });

  test('does not reject a password that merely contains a run', async () => {
    assert.equal((await makePolicy().check('mein-abc-schlüssel')).acceptable, true);
  });

  test('rejects the service name and the word for password', async () => {
    const policy = makePolicy();
    assert.ok((await policy.check('jyotish-2026')).rejections.includes('CONTAINS_SERVICE_TERM'));
    assert.ok((await policy.check('meinPasswort99')).rejections.includes('CONTAINS_SERVICE_TERM'));
    assert.ok((await policy.check('kundali-fan-42')).rejections.includes('CONTAINS_SERVICE_TERM'));
  });

  test("rejects a password built from the account's own address", async () => {
    const policy = makePolicy();
    const context = { email: 'anna.beispiel@example.de' };
    assert.ok((await policy.check('anna.beispiel-77', context)).rejections.includes('CONTAINS_EMAIL'));
    assert.equal((await policy.check('graureiherfeder', context)).acceptable, true);
  });

  test('ignores a local part too short to be meaningful', async () => {
    // "ab" is a substring of half the passwords in the world.
    const verdict = await makePolicy().check('graureiherfeder', { email: 'ab@example.de' });
    assert.equal(verdict.acceptable, true);
  });
});

describe('normalisation', () => {
  test('folds Unicode so the same typed password matches across devices', () => {
    // The same password typed on a Mac and on Android: one composed umlaut,
    // one base letter plus a combining diaeresis. Different bytes, same word.
    const composed = 'gr\u00fcnesLicht';
    const decomposed = 'gru\u0308nesLicht';
    assert.notEqual(composed, decomposed);
    assert.equal(normalisePassword(composed), normalisePassword(decomposed));
  });

  test('does not trim: surrounding spaces are part of the password', () => {
    assert.equal(normalisePassword('  geheim  '), '  geheim  ');
  });
});

describe('collecting rejections', () => {
  test('reports every failed rule at once so a form can show them together', async () => {
    const verdict = await makePolicy().check('astro', { email: 'astro@example.de' });
    assert.equal(verdict.acceptable, false);
    assert.deepEqual([...verdict.rejections].sort(), [
      'CONTAINS_EMAIL',
      'CONTAINS_SERVICE_TERM',
      'TOO_SHORT',
    ]);
  });
});

describe('InMemoryBreachList', () => {
  test('accepts raw hashes in either case and ignores malformed entries', async () => {
    const hash = breachHash('sonnenschein');
    const list = new InMemoryBreachList([hash.toLowerCase(), 'not-a-hash', '']);
    const suffixes = await list.suffixesFor(hash.slice(0, 5));
    assert.ok(suffixes.has(hash.slice(5)));
  });

  test('returns an empty set for an unknown prefix', async () => {
    const list = InMemoryBreachList.fromPasswords(BREACHED);
    assert.equal((await list.suffixesFor('ZZZZZ')).size, 0);
  });
});
