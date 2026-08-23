import { test, describe } from 'node:test';
import assert from 'node:assert/strict';

import { Logger, MemorySink } from '../dist/observability/logger.js';
import { InMemoryAccountRepository } from '../dist/modules/identity/account.js';
import { EmailIndexer } from '../dist/modules/identity/email_index.js';
import { IdentityService } from '../dist/modules/identity/identity_service.js';
import {
  InMemoryThrottleStore,
  LoginThrottle,
  MAIL_THROTTLE_LIMITS,
} from '../dist/modules/identity/login_throttle.js';
import {
  InMemoryBreachList,
  PasswordPolicy,
} from '../dist/modules/identity/password_policy.js';
import { InMemoryTokenRepository } from '../dist/modules/identity/secret_token.js';
import {
  ACCESS_TOKEN_TTL_MS,
  AccessTokenIssuer,
  hashRefreshToken,
  InMemorySessionRepository,
  REFRESH_TOKEN_TTL_MS,
  SESSION_ABSOLUTE_TTL_MS,
  SessionStore,
} from '../dist/modules/identity/session.js';

/** Synthetic throughout: CLAUDE.md forbids real personal data in fixtures. */
const SIGNING_KEY = 'test-signing-key-not-a-real-secret-0123456789';
const PEPPER = 'test-pepper-not-a-real-secret-0123456789';
const EMAIL = 'anna.beispiel@example.de';
const PASSWORD = 'graureiherfeder-77';
const NEW_PASSWORD = 'zwölf-blaue-koffer';
const ACCOUNT = 'account-1';
const OTHER_ACCOUNT = 'account-2';
const DEVICE = "Anna's iPhone";
const NOW = new Date('2026-08-06T09:00:00Z');

function makeStore({ resolvePrincipal } = {}) {
  const clock = { at: NOW };
  const now = () => clock.at;
  const sessions = new InMemorySessionRepository();
  const sink = new MemorySink();

  let counter = 0;
  const store = new SessionStore({
    sessions,
    issuer: new AccessTokenIssuer(SIGNING_KEY),
    ...(resolvePrincipal === undefined ? {} : { resolvePrincipal }),
    logger: new Logger(sink, 'debug', now),
    now,
    newId: () => `id-${(counter += 1)}`,
  });

  return {
    store,
    sessions,
    sink,
    now,
    advance(ms) {
      clock.at = new Date(clock.at.getTime() + ms);
    },
  };
}

function principal(emailVerified = true) {
  return { accountId: ACCOUNT, emailVerified };
}

/**
 * A registered account with a live [SessionStore] wired into [IdentityService].
 *
 * Deliberately the real store rather than the `RecordingRevoker` fake used in
 * `identity_service.test.js`: the point of AC4 is that the two halves meet.
 */
async function resetHarness() {
  const clock = { at: NOW };
  const now = () => clock.at;

  const accounts = new InMemoryAccountRepository();
  const throttles = new InMemoryThrottleStore();
  const mailer = new RecordingMailer();
  const sessions = new InMemorySessionRepository();

  let counter = 0;
  const store = new SessionStore({
    sessions,
    issuer: new AccessTokenIssuer(SIGNING_KEY),
    now,
    newId: () => `session-${(counter += 1)}`,
  });

  const service = new IdentityService({
    accounts,
    tokens: new InMemoryTokenRepository(),
    hasher: new FakeHasher(),
    policy: new PasswordPolicy(InMemoryBreachList.fromPasswords([])),
    indexer: new EmailIndexer(PEPPER),
    loginThrottle: new LoginThrottle(throttles, {}, now),
    mailThrottle: new LoginThrottle(throttles, MAIL_THROTTLE_LIMITS, now),
    mailer,
    sessions: store,
    now,
    newId: () => ACCOUNT,
  });

  await service.signUp({ email: EMAIL, password: PASSWORD, locale: 'de-DE' });
  return { service, mailer, store, sessions, accountId: ACCOUNT };
}

/** A stand-in for scrypt, as in `identity_service.test.js`. */
class FakeHasher {
  constructor() {
    this.version = 'v1';
  }
  async hash(password) {
    return `${this.version}:${password}`;
  }
  async verify(password, encoded) {
    return encoded.slice(encoded.indexOf(':') + 1) === password;
  }
  async spendVerificationTime() {}
  needsRehash(encoded) {
    return !encoded.startsWith(`${this.version}:`);
  }
}

class RecordingMailer {
  constructor() {
    this.resets = [];
  }
  async sendVerificationLink() {}
  async sendPasswordResetLink(to, secret) {
    this.resets.push(secret);
  }
  async sendPasswordChangedNotice() {}
  async sendAccountAlreadyExistsNotice() {}
  get lastResetSecret() {
    return this.resets.at(-1);
  }
}

describe('US-016 AC1 — short-lived access token', () => {
  test('the lifetime is fifteen minutes', () => {
    assert.equal(ACCESS_TOKEN_TTL_MS, 15 * 60 * 1000);
  });

  test('expiry is set fifteen minutes after issue', async () => {
    const harness = makeStore();
    const issued = await harness.store.start(principal(), DEVICE);
    assert.equal(issued.accessTokenExpiresAt.toISOString(), '2026-08-06T09:15:00.000Z');
  });

  test('valid one millisecond before the boundary, expired on it', async () => {
    const harness = makeStore();
    const issued = await harness.store.start(principal(), DEVICE);

    harness.advance(ACCESS_TOKEN_TTL_MS - 1);
    assert.equal(harness.store.verifyAccessToken(issued.accessToken).valid, true);

    harness.advance(1);
    const verdict = harness.store.verifyAccessToken(issued.accessToken);
    assert.equal(verdict.valid, false);
    assert.equal(verdict.reason, 'EXPIRED');
  });

  test('carries the account, the session and the verification flag', async () => {
    const harness = makeStore();
    const issued = await harness.store.start(principal(true), DEVICE);
    const verdict = harness.store.verifyAccessToken(issued.accessToken);

    assert.equal(verdict.valid, true);
    assert.equal(verdict.claims.accountId, ACCOUNT);
    assert.equal(verdict.claims.sessionId, issued.sessionId);
    assert.equal(verdict.claims.emailVerified, true);
  });
});

describe('US-016 AC1 — the access token cannot be forged', () => {
  test('a tampered payload is rejected', async () => {
    const harness = makeStore();
    const issued = await harness.store.start(principal(), DEVICE);
    const [payload, signature] = issued.accessToken.split('.');

    const forged = Buffer.from(
      JSON.stringify({
        sub: OTHER_ACCOUNT,
        sid: 'id-1',
        ver: true,
        exp: NOW.getTime() + ACCESS_TOKEN_TTL_MS,
      }),
      'utf8',
    ).toString('base64url');
    assert.notEqual(forged, payload);

    const verdict = harness.store.verifyAccessToken(`${forged}.${signature}`);
    assert.equal(verdict.valid, false);
    assert.equal(verdict.reason, 'BAD_SIGNATURE');
  });

  test('a tampered signature is rejected', async () => {
    const harness = makeStore();
    const issued = await harness.store.start(principal(), DEVICE);
    const [payload, signature] = issued.accessToken.split('.');
    const flipped = `${signature.slice(0, -1)}${signature.at(-1) === 'A' ? 'B' : 'A'}`;

    const verdict = harness.store.verifyAccessToken(`${payload}.${flipped}`);
    assert.equal(verdict.valid, false);
    assert.equal(verdict.reason, 'BAD_SIGNATURE');
  });

  test('a token signed with another key is rejected', async () => {
    const issued = await makeStore().store.start(principal(), DEVICE);
    const other = new SessionStore({
      sessions: new InMemorySessionRepository(),
      issuer: new AccessTokenIssuer('a-completely-different-key-0123456789012345'),
      now: () => NOW,
    });

    const verdict = other.verifyAccessToken(issued.accessToken);
    assert.equal(verdict.valid, false);
    assert.equal(verdict.reason, 'BAD_SIGNATURE');
  });

  test('the signature is checked before the payload is parsed', async () => {
    // Unsigned garbage must not reach JSON.parse. If this ever reports
    // MALFORMED, the parser has become reachable by anyone with a URL.
    const harness = makeStore();
    const verdict = harness.store.verifyAccessToken('bm90LWpzb24.bm90LWEtc2ln');
    assert.equal(verdict.valid, false);
    assert.equal(verdict.reason, 'BAD_SIGNATURE');
  });

  test('a token with no separator is malformed', async () => {
    const harness = makeStore();
    assert.equal(harness.store.verifyAccessToken('no-dot-here').reason, 'MALFORMED');
    assert.equal(harness.store.verifyAccessToken('.leading').reason, 'MALFORMED');
    assert.equal(harness.store.verifyAccessToken('trailing.').reason, 'MALFORMED');
  });

  test('a signing key under 32 bytes is refused outright', () => {
    assert.throws(() => new AccessTokenIssuer('too-short'), /at least 32 bytes/);
  });
});

describe('US-016 AC1 — the refresh token rotates', () => {
  test('refreshing yields a different refresh token', async () => {
    const harness = makeStore();
    const first = await harness.store.start(principal(), DEVICE);

    harness.advance(60_000);
    const result = await harness.store.refresh(first.refreshToken);

    assert.equal(result.outcome, 'refreshed');
    assert.notEqual(result.session.refreshToken, first.refreshToken);
    assert.notEqual(result.session.accessToken, first.accessToken);
  });

  test('the refresh token is stored hashed, never in the clear', async () => {
    const harness = makeStore();
    const issued = await harness.store.start(principal(), DEVICE);

    const stored = await harness.sessions.findById(issued.sessionId);
    assert.equal(stored.refreshTokenHash, hashRefreshToken(issued.refreshToken));
    assert.doesNotMatch(JSON.stringify(stored), new RegExp(issued.refreshToken.slice(0, 16)));
  });

  test('an unknown refresh token is rejected', async () => {
    const harness = makeStore();
    const result = await harness.store.refresh('never-issued');
    assert.equal(result.outcome, 'rejected');
    assert.equal(result.reason, 'UNKNOWN');
  });

  test('rotation keeps the device label and the family', async () => {
    const harness = makeStore();
    const first = await harness.store.start(principal(), DEVICE);
    const second = await harness.store.refresh(first.refreshToken);

    const before = await harness.sessions.findById(first.sessionId);
    const after = await harness.sessions.findById(second.session.sessionId);
    assert.equal(after.deviceLabel, DEVICE);
    assert.equal(after.familyId, before.familyId);
  });
});

describe('US-016 AC1 — a replayed refresh token is treated as theft', () => {
  test('presenting a rotated token twice revokes the whole family', async () => {
    const harness = makeStore();
    const first = await harness.store.start(principal(), DEVICE);
    const second = await harness.store.refresh(first.refreshToken);
    assert.equal(second.outcome, 'refreshed');

    // The thief replays the token the real device already rotated away.
    const replay = await harness.store.refresh(first.refreshToken);
    assert.equal(replay.outcome, 'rejected');
    assert.equal(replay.reason, 'REUSED');

    // And the legitimate device is signed out too: there is no way to tell
    // which of the two holders is the user, so neither keeps access.
    const legitimate = await harness.store.refresh(second.session.refreshToken);
    assert.equal(legitimate.outcome, 'rejected');
    assert.equal(legitimate.reason, 'REVOKED');
  });

  test('the whole chain dies, not just the two tokens involved', async () => {
    const harness = makeStore();
    const first = await harness.store.start(principal(), DEVICE);
    const second = await harness.store.refresh(first.refreshToken);
    const third = await harness.store.refresh(second.session.refreshToken);

    await harness.store.refresh(first.refreshToken);

    const record = await harness.sessions.findById(third.session.sessionId);
    assert.notEqual(record.revokedAt, null);
    assert.equal(record.revokedReason, 'TOKEN_REUSE_DETECTED');
  });

  test('a reuse is logged as a warning, with no personal data', async () => {
    const harness = makeStore();
    const first = await harness.store.start(principal(), DEVICE);
    await harness.store.refresh(first.refreshToken);
    await harness.store.refresh(first.refreshToken);

    const warning = harness.sink.records.find((r) => r.level === 'warn');
    assert.ok(warning, 'expected a warning for detected reuse');
    assert.match(warning.message, /reuse/);
    assert.doesNotMatch(JSON.stringify(warning), /iPhone|@/);
  });

  test('a session revoked for reuse does not appear in the device list', async () => {
    const harness = makeStore();
    const first = await harness.store.start(principal(), DEVICE);
    await harness.store.refresh(first.refreshToken);
    await harness.store.refresh(first.refreshToken);

    assert.deepEqual(await harness.store.listDevices(ACCOUNT), []);
  });

  test('two refreshes racing on one token do not both succeed', async () => {
    const harness = makeStore();
    const first = await harness.store.start(principal(), DEVICE);

    const [a, b] = await Promise.all([
      harness.store.refresh(first.refreshToken),
      harness.store.refresh(first.refreshToken),
    ]);

    const outcomes = [a.outcome, b.outcome].sort();
    assert.deepEqual(outcomes, ['refreshed', 'rejected']);
  });
});

describe('US-016 AC3 — remote sign-out of all devices', () => {
  async function twoDevices() {
    const harness = makeStore();
    const phone = await harness.store.start(principal(), "Anna's iPhone");
    harness.advance(1000);
    const tablet = await harness.store.start(principal(), "Anna's iPad");
    return { harness, phone, tablet };
  }

  test('the device list shows every live session, most recent first', async () => {
    const { harness } = await twoDevices();
    const devices = await harness.store.listDevices(ACCOUNT);

    assert.equal(devices.length, 2);
    assert.deepEqual(
      devices.map((d) => d.deviceLabel),
      ["Anna's iPad", "Anna's iPhone"],
    );
  });

  test('signing out everywhere stops every refresh token', async () => {
    const { harness, phone, tablet } = await twoDevices();
    await harness.store.revokeAllForAccount(ACCOUNT);

    for (const session of [phone, tablet]) {
      const result = await harness.store.refresh(session.refreshToken);
      assert.equal(result.outcome, 'rejected');
      assert.equal(result.reason, 'REVOKED');
    }
    assert.deepEqual(await harness.store.listDevices(ACCOUNT), []);
  });

  test('signing out one device leaves the others alone', async () => {
    const { harness, phone, tablet } = await twoDevices();
    await harness.store.revokeSession(phone.sessionId);

    assert.equal((await harness.store.refresh(phone.refreshToken)).reason, 'REVOKED');
    assert.equal((await harness.store.refresh(tablet.refreshToken)).outcome, 'refreshed');
  });

  test('another account is untouched', async () => {
    const { harness } = await twoDevices();
    const other = await harness.store.start(
      { accountId: OTHER_ACCOUNT, emailVerified: true },
      'Shared laptop',
    );

    await harness.store.revokeAllForAccount(ACCOUNT);
    assert.equal((await harness.store.refresh(other.refreshToken)).outcome, 'refreshed');
  });

  test('an already-issued access token still works until it expires', async () => {
    // The honest limit of a stateless access token, asserted so nobody
    // discovers it during an incident. This is why AC1 says short-lived.
    const { harness, phone } = await twoDevices();
    await harness.store.revokeAllForAccount(ACCOUNT);

    assert.equal(harness.store.verifyAccessToken(phone.accessToken).valid, true);

    harness.advance(ACCESS_TOKEN_TTL_MS);
    assert.equal(harness.store.verifyAccessToken(phone.accessToken).valid, false);
  });
});

describe('US-016 AC4 — sessions are invalidated on password change', () => {
  test('every session dies and the reason is recorded', async () => {
    const harness = makeStore();
    const session = await harness.store.start(principal(), DEVICE);

    await harness.store.revokeAllForAccount(ACCOUNT, 'PASSWORD_CHANGED');

    const result = await harness.store.refresh(session.refreshToken);
    assert.equal(result.reason, 'REVOKED');

    const record = await harness.sessions.findById(session.sessionId);
    assert.equal(record.revokedReason, 'PASSWORD_CHANGED');
  });

  test('a password reset is distinguishable from a voluntary sign-out', async () => {
    // Both tear down every session; only the reason separates a user tidying
    // up from the aftermath of a possible takeover.
    const harness = makeStore();
    const voluntary = await harness.store.start(principal(), DEVICE);
    await harness.store.revokeAllForAccount(ACCOUNT);
    assert.equal(
      (await harness.sessions.findById(voluntary.sessionId)).revokedReason,
      'SIGNED_OUT_EVERYWHERE',
    );
  });

  test('a completed password reset revokes real sessions end to end', async () => {
    // The seam US-011 left, now with a live SessionStore behind it rather than
    // a NoSessionRevoker. Exercised through IdentityService so the wiring —
    // not just the store — is covered.
    const { service, mailer, store, sessions, accountId } = await resetHarness();
    const session = await store.start({ accountId, emailVerified: true }, DEVICE);

    await service.requestPasswordReset(EMAIL);
    const outcome = await service.resetPassword({
      secret: mailer.lastResetSecret,
      password: NEW_PASSWORD,
    });
    assert.equal(outcome.outcome, 'reset');

    const refreshed = await store.refresh(session.refreshToken);
    assert.equal(refreshed.outcome, 'rejected');
    assert.equal(refreshed.reason, 'REVOKED');

    const record = await sessions.findById(session.sessionId);
    assert.equal(record.revokedReason, 'PASSWORD_CHANGED');
  });
});

describe('US-016 — sessions expire on their own', () => {
  test('the idle window is sixty days and the absolute cap is six months', () => {
    assert.equal(REFRESH_TOKEN_TTL_MS, 60 * 24 * 60 * 60 * 1000);
    assert.equal(SESSION_ABSOLUTE_TTL_MS, 180 * 24 * 60 * 60 * 1000);
  });

  test('an untouched session lapses at the idle boundary', async () => {
    const harness = makeStore();
    const session = await harness.store.start(principal(), DEVICE);

    harness.advance(REFRESH_TOKEN_TTL_MS - 1);
    const alive = await harness.store.refresh(session.refreshToken);
    assert.equal(alive.outcome, 'refreshed');

    harness.advance(REFRESH_TOKEN_TTL_MS);
    const dead = await harness.store.refresh(alive.session.refreshToken);
    assert.equal(dead.reason, 'EXPIRED');
  });

  test('regular use cannot outlive the absolute cap', async () => {
    const harness = makeStore();
    let session = await harness.store.start(principal(), DEVICE);

    // Refresh every thirty days: the idle clock never runs out.
    for (let elapsed = 0; elapsed < SESSION_ABSOLUTE_TTL_MS; elapsed += 30 * 86_400_000) {
      harness.advance(30 * 86_400_000);
      const result = await harness.store.refresh(session.refreshToken);
      if (result.outcome === 'rejected') {
        assert.equal(result.reason, 'EXPIRED');
        return;
      }
      session = result.session;
    }
    assert.fail('the session outlived the absolute cap');
  });

  test('the reported expiry is whichever deadline comes first', async () => {
    const harness = makeStore();
    const session = await harness.store.start(principal(), DEVICE);
    // At the start of a family the idle window is the shorter of the two.
    assert.equal(
      session.refreshTokenExpiresAt.getTime(),
      NOW.getTime() + REFRESH_TOKEN_TTL_MS,
    );
  });
});

describe('US-016 — the account gets a say at refresh time', () => {
  test('a deleted account cannot refresh', async () => {
    const harness = makeStore({ resolvePrincipal: async () => null });
    const session = await harness.store.start(principal(), DEVICE);

    const result = await harness.store.refresh(session.refreshToken);
    assert.equal(result.outcome, 'rejected');
    assert.equal(result.reason, 'REVOKED');
  });

  test('newly verified email reaches the access token without a re-login', async () => {
    const state = { emailVerified: false };
    const harness = makeStore({
      resolvePrincipal: async () => ({ accountId: ACCOUNT, ...state }),
    });
    const session = await harness.store.start(principal(false), DEVICE);
    assert.equal(harness.store.verifyAccessToken(session.accessToken).claims.emailVerified, false);

    state.emailVerified = true;
    const refreshed = await harness.store.refresh(session.refreshToken);

    const verdict = harness.store.verifyAccessToken(refreshed.session.accessToken);
    assert.equal(verdict.claims.emailVerified, true);
  });
});

describe('US-016 — housekeeping', () => {
  test('expired records are purged, live ones kept', async () => {
    const harness = makeStore();
    await harness.store.start(principal(), DEVICE);
    harness.advance(REFRESH_TOKEN_TTL_MS);
    await harness.store.start(principal(), 'Fresh device');

    const removed = await harness.sessions.deleteExpired(harness.now());
    assert.equal(removed, 1);
    assert.equal((await harness.store.listDevices(ACCOUNT)).length, 1);
  });
});
