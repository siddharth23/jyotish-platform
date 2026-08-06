import { test, describe } from 'node:test';
import assert from 'node:assert/strict';

import {
  digestsEqual,
  EMAIL_VERIFICATION_TTL_MS,
  hashToken,
  InMemoryTokenRepository,
  issueToken,
  lookupToken,
  PASSWORD_RESET_TTL_MS,
} from '../dist/modules/identity/secret_token.js';

const NOW = new Date('2026-08-06T09:00:00Z');
const ACCOUNT = 'account-1';

function at(offsetMs) {
  return new Date(NOW.getTime() + offsetMs);
}

async function storedResetToken(repository, now = NOW) {
  const issued = issueToken(ACCOUNT, 'password_reset', PASSWORD_RESET_TTL_MS, now);
  await repository.insert(issued.record);
  return issued;
}

describe('US-011 AC4 — a reset token is valid for thirty minutes', () => {
  test('the lifetime is thirty minutes', () => {
    assert.equal(PASSWORD_RESET_TTL_MS, 30 * 60 * 1000);
  });

  test('expiry is set thirty minutes after issue', async () => {
    const issued = issueToken(ACCOUNT, 'password_reset', PASSWORD_RESET_TTL_MS, NOW);
    assert.equal(issued.record.expiresAt.toISOString(), '2026-08-06T09:30:00.000Z');
  });

  test('valid one millisecond before the boundary, expired on it', async () => {
    const repository = new InMemoryTokenRepository();
    const issued = await storedResetToken(repository);

    const justInside = await lookupToken(
      repository,
      issued.secret,
      'password_reset',
      at(PASSWORD_RESET_TTL_MS - 1),
    );
    assert.equal(justInside.valid, true);

    const onTheBoundary = await lookupToken(
      repository,
      issued.secret,
      'password_reset',
      at(PASSWORD_RESET_TTL_MS),
    );
    assert.equal(onTheBoundary.valid, false);
    assert.equal(onTheBoundary.reason, 'EXPIRED');
  });

  test('a verification link gets a day, which is longer on purpose', () => {
    assert.equal(EMAIL_VERIFICATION_TTL_MS, 24 * 60 * 60 * 1000);
    assert.ok(EMAIL_VERIFICATION_TTL_MS > PASSWORD_RESET_TTL_MS);
  });
});

describe('tokens are stored hashed', () => {
  test('the secret never reaches the record', async () => {
    const issued = issueToken(ACCOUNT, 'password_reset', PASSWORD_RESET_TTL_MS, NOW);
    // A live reset token is the account. A database dump must not contain one.
    assert.equal(JSON.stringify(issued.record).includes(issued.secret), false);
    assert.equal(issued.record.hash, hashToken(issued.secret));
    assert.match(issued.record.hash, /^[0-9a-f]{64}$/);
  });

  test('the secret carries 256 bits and survives a URL', () => {
    const issued = issueToken(ACCOUNT, 'password_reset', PASSWORD_RESET_TTL_MS, NOW);
    assert.match(issued.secret, /^[A-Za-z0-9_-]+$/);
    assert.equal(Buffer.from(issued.secret, 'base64url').length, 32);
  });

  test('two tokens issued in the same millisecond differ', () => {
    const first = issueToken(ACCOUNT, 'password_reset', PASSWORD_RESET_TTL_MS, NOW);
    const second = issueToken(ACCOUNT, 'password_reset', PASSWORD_RESET_TTL_MS, NOW);
    assert.notEqual(first.secret, second.secret);
  });
});

describe('single use', () => {
  test('a consumed token stops working', async () => {
    const repository = new InMemoryTokenRepository();
    const issued = await storedResetToken(repository);

    assert.equal(await repository.markConsumed(issued.record.hash, at(1000)), true);

    const second = await lookupToken(repository, issued.secret, 'password_reset', at(2000));
    assert.equal(second.valid, false);
    assert.equal(second.reason, 'ALREADY_USED');
  });

  test('consuming twice fails the second time', async () => {
    // Two clicks of one link, milliseconds apart, is what a stolen-link attack
    // races for. Exactly one must win.
    const repository = new InMemoryTokenRepository();
    const issued = await storedResetToken(repository);

    const [first, second] = await Promise.all([
      repository.markConsumed(issued.record.hash, at(1)),
      repository.markConsumed(issued.record.hash, at(1)),
    ]);
    assert.deepEqual([first, second].sort(), [false, true]);
  });

  test('an unknown secret is not found', async () => {
    const repository = new InMemoryTokenRepository();
    const lookup = await lookupToken(repository, 'never-issued', 'password_reset', NOW);
    assert.equal(lookup.valid, false);
    assert.equal(lookup.reason, 'NOT_FOUND');
  });
});

describe('purpose', () => {
  test('a verification token cannot be redeemed as a password reset', async () => {
    // Both are ours and both are random; only the recorded purpose keeps
    // "confirm your address" from becoming "change the password".
    const repository = new InMemoryTokenRepository();
    const issued = issueToken(ACCOUNT, 'email_verification', EMAIL_VERIFICATION_TTL_MS, NOW);
    await repository.insert(issued.record);

    const lookup = await lookupToken(repository, issued.secret, 'password_reset', at(1000));
    assert.equal(lookup.valid, false);
    assert.equal(lookup.reason, 'WRONG_PURPOSE');
  });
});

describe('invalidating outstanding tokens', () => {
  test('kills every unconsumed token of one purpose for one account', async () => {
    const repository = new InMemoryTokenRepository();
    const first = await storedResetToken(repository);
    const second = await storedResetToken(repository);
    const verification = issueToken(ACCOUNT, 'email_verification', EMAIL_VERIFICATION_TTL_MS, NOW);
    await repository.insert(verification.record);

    await repository.invalidateAllForAccount(ACCOUNT, 'password_reset', at(1000));

    for (const issued of [first, second]) {
      const lookup = await lookupToken(repository, issued.secret, 'password_reset', at(2000));
      assert.equal(lookup.valid, false);
      assert.equal(lookup.reason, 'ALREADY_USED');
    }
    // A different purpose is untouched.
    const untouched = await lookupToken(
      repository,
      verification.secret,
      'email_verification',
      at(2000),
    );
    assert.equal(untouched.valid, true);
  });

  test('leaves another account alone', async () => {
    const repository = new InMemoryTokenRepository();
    const mine = await storedResetToken(repository);
    const theirs = issueToken('account-2', 'password_reset', PASSWORD_RESET_TTL_MS, NOW);
    await repository.insert(theirs.record);

    await repository.invalidateAllForAccount('account-2', 'password_reset', at(1000));

    assert.equal((await lookupToken(repository, mine.secret, 'password_reset', at(2000))).valid, true);
  });
});

describe('housekeeping', () => {
  test('deleteExpired removes tokens past their expiry', async () => {
    const repository = new InMemoryTokenRepository();
    await storedResetToken(repository);
    assert.equal(await repository.deleteExpired(at(PASSWORD_RESET_TTL_MS - 1)), 0);
    assert.equal(await repository.deleteExpired(at(PASSWORD_RESET_TTL_MS)), 1);
  });
});

describe('digestsEqual', () => {
  test('compares equal-length digests and rejects different lengths', () => {
    const digest = hashToken('anything');
    assert.equal(digestsEqual(digest, digest), true);
    assert.equal(digestsEqual(digest, hashToken('anything else')), false);
    assert.equal(digestsEqual(digest, digest.slice(0, 10)), false);
  });
});
