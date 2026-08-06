import { test, describe } from 'node:test';
import assert from 'node:assert/strict';

import {
  ACCOUNT_LOCKOUT_MS,
  InMemoryThrottleStore,
  LoginThrottle,
  MAIL_THROTTLE_LIMITS,
  MAX_ACCOUNT_FAILURES,
  MAX_CLIENT_FAILURES,
} from '../dist/modules/identity/login_throttle.js';

const ACCOUNT = 'account-index';
const CLIENT = 'client-index';

/** A throttle on a clock the test controls. */
function makeThrottle(options = {}) {
  const clock = { at: new Date('2026-08-06T09:00:00Z') };
  const throttle = new LoginThrottle(new InMemoryThrottleStore(), options, () => clock.at);
  return {
    throttle,
    advance(ms) {
      clock.at = new Date(clock.at.getTime() + ms);
    },
  };
}

async function failTimes(throttle, count, accountKey = ACCOUNT, clientKey = CLIENT) {
  for (let i = 0; i < count; i += 1) {
    await throttle.recordFailure(accountKey, clientKey);
  }
}

/** Failures from a caller with no trustworthy client address. */
async function failAccountOnly(throttle, count, accountKey = ACCOUNT) {
  for (let i = 0; i < count; i += 1) {
    await throttle.recordFailure(accountKey);
  }
}

describe('US-011 AC3 — lockout after ten failed attempts', () => {
  test('the limit is ten', () => {
    assert.equal(MAX_ACCOUNT_FAILURES, 10);
  });

  test('nine failures still allow an attempt, ten lock the account', async () => {
    const { throttle } = makeThrottle();
    await failTimes(throttle, 9);
    assert.equal((await throttle.check(ACCOUNT, CLIENT)).allowed, true);

    await failTimes(throttle, 1);
    const decision = await throttle.check(ACCOUNT, CLIENT);
    assert.equal(decision.allowed, false);
    assert.equal(decision.scope, 'account');
    assert.equal(decision.retryAfterMs, ACCOUNT_LOCKOUT_MS);
  });

  test('the lock expires rather than needing an administrator', async () => {
    // Lockout is a denial-of-service primitive: anyone who knows an address can
    // trip it. A lock that only a human can lift turns that into an outage.
    const { throttle, advance } = makeThrottle();
    await failTimes(throttle, MAX_ACCOUNT_FAILURES);

    advance(ACCOUNT_LOCKOUT_MS - 1);
    assert.equal((await throttle.check(ACCOUNT)).allowed, false);

    advance(1);
    assert.equal((await throttle.check(ACCOUNT)).allowed, true);
  });

  test('a returning user gets a full allowance, not one attempt', async () => {
    const { throttle, advance } = makeThrottle();
    await failTimes(throttle, MAX_ACCOUNT_FAILURES);
    advance(ACCOUNT_LOCKOUT_MS);

    // Mistyping once after the lock expires must not re-lock immediately.
    await failTimes(throttle, MAX_ACCOUNT_FAILURES - 1);
    assert.equal((await throttle.check(ACCOUNT)).allowed, true);
  });

  test('a correct password clears the account counter', async () => {
    const { throttle } = makeThrottle();
    await failTimes(throttle, MAX_ACCOUNT_FAILURES - 1);
    await throttle.recordSuccess(ACCOUNT);

    await failTimes(throttle, MAX_ACCOUNT_FAILURES - 1);
    assert.equal((await throttle.check(ACCOUNT)).allowed, true);
  });

  test('failures age out of the window', async () => {
    const { throttle, advance } = makeThrottle();
    await failTimes(throttle, 9);
    advance(15 * 60 * 1000);
    await failTimes(throttle, 9);
    assert.equal((await throttle.check(ACCOUNT)).allowed, true);
  });

  test('clear lifts a lock outright', async () => {
    const { throttle } = makeThrottle();
    await failTimes(throttle, MAX_ACCOUNT_FAILURES);
    assert.equal((await throttle.check(ACCOUNT)).allowed, false);

    await throttle.clear(ACCOUNT);
    assert.equal((await throttle.check(ACCOUNT)).allowed, true);
  });
});

describe('the per-client budget', () => {
  test('is much larger than the per-account one', () => {
    // Carrier-grade NAT puts thousands of unrelated people behind one address.
    assert.ok(MAX_CLIENT_FAILURES > MAX_ACCOUNT_FAILURES);
  });

  test('catches credential stuffing spread across many addresses', async () => {
    // One password against many accounts never trips a per-account counter.
    const { throttle } = makeThrottle();
    for (let i = 0; i < MAX_CLIENT_FAILURES; i += 1) {
      await throttle.recordFailure(`account-${i}`, CLIENT);
    }
    const decision = await throttle.check('account-fresh', CLIENT);
    assert.equal(decision.allowed, false);
    assert.equal(decision.scope, 'client');
  });

  test('is not cleared by a successful login', async () => {
    // Otherwise an attacker with one account of their own resets their own
    // budget between batches and stuffs indefinitely.
    const { throttle } = makeThrottle();
    for (let i = 0; i < MAX_CLIENT_FAILURES; i += 1) {
      await throttle.recordFailure(`account-${i}`, CLIENT);
    }
    await throttle.recordSuccess('account-0');
    assert.equal((await throttle.check('account-0', CLIENT)).allowed, false);
  });

  test('is checked before the account limit', async () => {
    const { throttle } = makeThrottle();
    for (let i = 0; i < MAX_CLIENT_FAILURES; i += 1) {
      await throttle.recordFailure(`account-${i}`, CLIENT);
    }
    await failAccountOnly(throttle, MAX_ACCOUNT_FAILURES);
    assert.equal((await throttle.check(ACCOUNT, CLIENT)).scope, 'client');
  });

  test('degrades to per-account only when no client key is supplied', async () => {
    const { throttle } = makeThrottle();
    for (let i = 0; i < MAX_CLIENT_FAILURES; i += 1) {
      await throttle.recordFailure(`account-${i}`, CLIENT);
    }
    // A caller with no trustworthy client address must not be limited against
    // everyone else's shared key.
    assert.equal((await throttle.check('account-fresh')).allowed, true);
  });
});

describe('keys are opaque', () => {
  test('two accounts do not share a counter', async () => {
    const { throttle } = makeThrottle();
    await failAccountOnly(throttle, MAX_ACCOUNT_FAILURES, 'account-a');
    assert.equal((await throttle.check('account-a')).allowed, false);
    assert.equal((await throttle.check('account-b')).allowed, true);
  });

  test('an address with no account is counted the same way', async () => {
    // If only real accounts were counted, watching which addresses eventually
    // lock would be an enumeration oracle.
    const { throttle } = makeThrottle();
    await failAccountOnly(throttle, MAX_ACCOUNT_FAILURES, 'index-of-nonexistent');
    assert.equal((await throttle.check('index-of-nonexistent')).allowed, false);
  });
});

describe('the mail budget', () => {
  test('is tighter and measured over an hour', () => {
    assert.equal(MAIL_THROTTLE_LIMITS.account.maxFailures, 5);
    assert.equal(MAIL_THROTTLE_LIMITS.account.windowMs, 60 * 60 * 1000);
  });

  test('allows five messages to one address per hour, then stops', async () => {
    const { throttle, advance } = makeThrottle(MAIL_THROTTLE_LIMITS);
    for (let i = 0; i < 5; i += 1) {
      assert.equal((await throttle.check(ACCOUNT, CLIENT)).allowed, true, `send ${i + 1}`);
      await throttle.consumeAllowance(ACCOUNT, CLIENT);
    }
    assert.equal((await throttle.check(ACCOUNT, CLIENT)).allowed, false);

    advance(60 * 60 * 1000);
    assert.equal((await throttle.check(ACCOUNT, CLIENT)).allowed, true);
  });
});
