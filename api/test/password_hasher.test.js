import { test, describe } from 'node:test';
import assert from 'node:assert/strict';

import {
  DEFAULT_SCRYPT_PARAMETERS,
  PasswordHashError,
  ScryptPasswordHasher,
} from '../dist/modules/identity/password_hasher.js';

/**
 * The floor of the accepted range, not the production parameters.
 *
 * The real settings cost 64 MiB and around a tenth of a second per hash, and
 * this file hashes dozens of times. The behaviour under test — encoding,
 * verification, parameter handling — does not depend on the cost.
 */
const FAST = { N: 4096, r: 8, p: 1 };

function fastHasher() {
  return new ScryptPasswordHasher(FAST);
}

describe('hashing and verifying', () => {
  test('verifies the correct password and rejects a wrong one', async () => {
    const hasher = fastHasher();
    const encoded = await hasher.hash('graureiherfeder');
    assert.equal(await hasher.verify('graureiherfeder', encoded), true);
    assert.equal(await hasher.verify('graureiherfedeR', encoded), false);
    assert.equal(await hasher.verify('', encoded), false);
  });

  test('salts, so the same password hashes differently every time', async () => {
    const hasher = fastHasher();
    const first = await hasher.hash('graureiherfeder');
    const second = await hasher.hash('graureiherfeder');
    assert.notEqual(first, second);
    assert.equal(await hasher.verify('graureiherfeder', second), true);
  });

  test('records the parameters in the encoded value', async () => {
    // This is what makes a future move to Argon2id a rehash-on-login rather
    // than a migration: every stored hash says how it was made.
    const encoded = await fastHasher().hash('graureiherfeder');
    assert.match(encoded, /^scrypt\$N=4096,r=8,p=1\$[\w-]+\$[\w-]+$/);
  });

  test('handles passwords with spaces and astral characters', async () => {
    const hasher = fastHasher();
    for (const password of ['  führende leerzeichen  ', '🌙🌞🪐🔭🧿🌊']) {
      const encoded = await hasher.hash(password);
      assert.equal(await hasher.verify(password, encoded), true);
    }
  });
});

describe('reading back a stored value', () => {
  test('fails the login rather than the request when a row is corrupt', async () => {
    const hasher = fastHasher();
    for (const corrupt of ['', 'not-a-hash', 'scrypt$N=4096,r=8,p=1$only-three', 'a$b$c$d']) {
      assert.equal(await hasher.verify('graureiherfeder', corrupt), false);
    }
  });

  test('refuses parameters outside the accepted range', async () => {
    const hasher = fastHasher();
    // N=2^30 in one row would turn a single login into an out-of-memory kill.
    assert.equal(await hasher.verify('graureiherfeder', 'scrypt$N=1073741824,r=8,p=1$AAAA$AAAA'), false);
    // A downgraded row must not become a cheap-to-crack hash.
    assert.equal(await hasher.verify('graureiherfeder', 'scrypt$N=2,r=8,p=1$AAAA$AAAA'), false);
    // N must be a power of two.
    assert.equal(await hasher.verify('graureiherfeder', 'scrypt$N=5000,r=8,p=1$AAAA$AAAA'), false);
  });

  test('refuses to construct with parameters outside the range', () => {
    assert.throws(() => new ScryptPasswordHasher({ N: 1024, r: 8, p: 1 }), PasswordHashError);
    assert.throws(() => new ScryptPasswordHasher({ N: 4096, r: 0, p: 1 }), PasswordHashError);
  });
});

describe('needsRehash', () => {
  test('is false for a hash made with the current parameters', async () => {
    const hasher = fastHasher();
    assert.equal(hasher.needsRehash(await hasher.hash('graureiherfeder')), false);
  });

  test('is true for a hash made with weaker parameters', async () => {
    const weak = await new ScryptPasswordHasher({ N: 4096, r: 8, p: 1 }).hash('graureiherfeder');
    const strong = new ScryptPasswordHasher({ N: 8192, r: 8, p: 1 });
    assert.equal(strong.needsRehash(weak), true);
  });

  test('is true for anything this build cannot parse or verify', () => {
    const hasher = fastHasher();
    assert.equal(hasher.needsRehash('argon2id$v=19$m=47104,t=1,p=1$abc$def'), true);
    assert.equal(hasher.needsRehash('nonsense'), true);
  });
});

describe('spendVerificationTime', () => {
  test('resolves without an account, so a missing one is not free to detect', async () => {
    const hasher = fastHasher();
    await hasher.spendVerificationTime();
    // Called repeatedly on a hot login path; the throwaway hash is reused.
    await hasher.spendVerificationTime();
  });
});

describe('the production parameters', () => {
  test('are one of the pairs OWASP lists for scrypt', () => {
    assert.deepEqual(DEFAULT_SCRYPT_PARAMETERS, { N: 65536, r: 8, p: 2 });
  });

  test('cost about 64 MiB per concurrent verification', () => {
    // 128 · N · r. Stated as a test because it is the number that decides how
    // many logins a host survives, and it is easy to raise N without doing the
    // arithmetic.
    const { N, r } = DEFAULT_SCRYPT_PARAMETERS;
    assert.equal((128 * N * r) / (1024 * 1024), 64);
  });

  test('work end to end at full cost', async () => {
    const hasher = new ScryptPasswordHasher();
    const encoded = await hasher.hash('graureiherfeder');
    assert.equal(await hasher.verify('graureiherfeder', encoded), true);
    assert.equal(await hasher.verify('falsch-geraten', encoded), false);
  });
});
