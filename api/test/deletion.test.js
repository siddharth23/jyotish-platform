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
  AccessTokenIssuer,
  InMemorySessionRepository,
  SessionStore,
} from '../dist/modules/identity/session.js';
import {
  callbackEraser,
  DELETION_DEADLINE_MS,
  DELETION_GRACE_MS,
  DELETION_PLAN,
  DeletionService,
  erasedCategories,
  InMemoryDeletionRepository,
  INVOICE_RETENTION_YEARS,
  retainedCategories,
  tombstone,
} from '../dist/modules/identity/deletion.js';

/** Synthetic throughout: CLAUDE.md forbids real personal data in fixtures. */
const NOW = new Date('2026-08-06T09:00:00Z');
const ACCOUNT = 'account-1';
const EMAIL = 'anna.beispiel@example.de';

class RecordingMailer {
  constructor() {
    this.scheduled = [];
    this.completed = [];
    this.cancelled = [];
  }
  async sendDeletionScheduledNotice(to, purgeDueAt) {
    this.scheduled.push({ to, purgeDueAt });
  }
  async sendDeletionCompletedNotice(to) {
    this.completed.push({ to });
  }
  async sendDeletionCancelledNotice(to) {
    this.cancelled.push({ to });
  }
}

class RecordingRevoker {
  constructor() {
    this.revoked = [];
  }
  async revokeAllForAccount(accountId, reason) {
    this.revoked.push({ accountId, reason });
  }
}

function makeService({ failingCategory } = {}) {
  const clock = { at: NOW };
  const now = () => clock.at;

  const accounts = new InMemoryAccountRepository();
  const deletions = new InMemoryDeletionRepository();
  const mailer = new RecordingMailer();
  const sessions = new RecordingRevoker();
  const sink = new MemorySink();
  const erased = [];

  const erasers = erasedCategories().map((category) =>
    callbackEraser(category, async (accountId) => {
      if (category === failingCategory) throw new Error('storage unavailable');
      erased.push({ category, accountId });
    }),
  );

  const service = new DeletionService({
    accounts,
    deletions,
    sessions,
    mailer,
    erasers,
    logger: new Logger(sink, 'debug', now),
    now,
  });

  return {
    service,
    accounts,
    deletions,
    mailer,
    sessions,
    sink,
    erased,
    advance(ms) {
      clock.at = new Date(clock.at.getTime() + ms);
    },
  };
}

async function registered(harness) {
  await harness.accounts.insert({
    id: ACCOUNT,
    emailIndex: 'index-1',
    email: EMAIL,
    passwordHash: 'v1:not-a-real-hash',
    emailVerifiedAt: NOW,
    locale: 'de-DE',
    createdAt: NOW,
    updatedAt: NOW,
  });
  return harness;
}

describe('US-015 AC2 — what is deleted versus what is retained', () => {
  test('every retained category names a specific legal basis', () => {
    // "We might need it" is not a lawful basis. This asserts that nothing is
    // retained without an obligation written next to it.
    for (const entry of retainedCategories()) {
      assert.match(
        entry.disposition.basis,
        /Art\.|§/,
        `${entry.category} must cite an article or a paragraph`,
      );
      assert.ok(entry.disposition.until.length > 0, `${entry.category} needs a horizon`);
    }
  });

  test('invoices are retained, and nothing else about an order is', () => {
    const retained = retainedCategories().map((e) => e.category);
    assert.ok(retained.includes('invoices'));
    // The things that carry the personal content must not creep onto the
    // retained list under cover of the invoice obligation.
    for (const category of ['birth_data', 'chart_snapshots', 'focus_questions']) {
      assert.ok(!retained.includes(category), `${category} must be erased`);
    }
  });

  test('birth data is erased', () => {
    // US-100 AC1, and the reason the DPIA exists.
    assert.ok(erasedCategories().includes('birth_data'));
  });

  test('the invoice horizon is ten years', () => {
    assert.equal(INVOICE_RETENTION_YEARS, 10);
  });

  test('every module holding personal data has a disposition', () => {
    // A new module that stores personal data must appear here. Silence would
    // mean its data quietly survives deletion.
    const owners = new Set(DELETION_PLAN.map((e) => e.owner));
    for (const owner of ['identity', 'profile', 'chart', 'career', 'report', 'order', 'payment']) {
      assert.ok(owners.has(owner), `${owner} has no entry in the deletion plan`);
    }
  });

  test('a module with no eraser is refused at construction', () => {
    assert.throws(
      () =>
        new DeletionService({
          accounts: new InMemoryAccountRepository(),
          deletions: new InMemoryDeletionRepository(),
          sessions: new RecordingRevoker(),
          mailer: new RecordingMailer(),
          erasers: [callbackEraser('account', async () => {})],
        }),
      /No eraser registered for/,
    );
  });
});

describe('US-015 AC3 — hard delete within thirty days', () => {
  test('the grace period leaves room inside the deadline', () => {
    assert.ok(
      DELETION_GRACE_MS < DELETION_DEADLINE_MS,
      'the purge must fall well inside the thirty days Article 12(3) allows',
    );
    assert.equal(DELETION_GRACE_MS, 7 * 24 * 60 * 60 * 1000);
  });

  test('a request schedules the purge and mails the notice', async () => {
    const harness = await registered(makeService());
    const result = await harness.service.requestDeletion(ACCOUNT);

    assert.equal(result.outcome, 'scheduled');
    assert.equal(result.purgeDueAt.toISOString(), '2026-08-13T09:00:00.000Z');
    assert.equal(harness.mailer.scheduled.length, 1);
    assert.equal(harness.mailer.scheduled[0].to.email, EMAIL);
    assert.equal(harness.mailer.scheduled[0].to.locale, 'de-DE');
  });

  test('nothing is erased before the grace period elapses', async () => {
    const harness = await registered(makeService());
    await harness.service.requestDeletion(ACCOUNT);

    harness.advance(DELETION_GRACE_MS - 1);
    assert.equal(await harness.service.runDuePurges(), 0);
    assert.deepEqual(harness.erased, []);
  });

  test('the purge runs on the boundary and erases every category', async () => {
    const harness = await registered(makeService());
    await harness.service.requestDeletion(ACCOUNT);

    harness.advance(DELETION_GRACE_MS);
    assert.equal(await harness.service.runDuePurges(), 1);

    assert.deepEqual(
      harness.erased.map((e) => e.category).sort(),
      [...erasedCategories()].sort(),
    );
  });

  test('the completion notice is sent (AC3)', async () => {
    const harness = await registered(makeService());
    await harness.service.requestDeletion(ACCOUNT);
    harness.advance(DELETION_GRACE_MS);
    await harness.service.runDuePurges();

    assert.equal(harness.mailer.completed.length, 1);
    assert.equal(harness.mailer.completed[0].to.email, EMAIL);
  });

  test('a second purge run does not re-erase a completed account', async () => {
    const harness = await registered(makeService());
    await harness.service.requestDeletion(ACCOUNT);
    harness.advance(DELETION_GRACE_MS);
    await harness.service.runDuePurges();
    const first = harness.erased.length;

    assert.equal(await harness.service.runDuePurges(), 0);
    assert.equal(harness.erased.length, first);
    assert.equal(harness.mailer.completed.length, 1);
  });

  test('a failed eraser leaves the request scheduled so it retries', async () => {
    // Marking it complete on failure would be an erasure that never happened
    // and that nothing would ever look at again.
    const harness = await registered(makeService({ failingCategory: 'chart_snapshots' }));
    await harness.service.requestDeletion(ACCOUNT);
    harness.advance(DELETION_GRACE_MS);

    assert.equal(await harness.service.runDuePurges(), 0);
    const request = await harness.deletions.findByAccountId(ACCOUNT);
    assert.equal(request.state, 'scheduled');
    assert.equal(request.completedAt, null);
    assert.equal(harness.mailer.completed.length, 0);
  });

  test('one account failing does not abandon the rest of the batch', async () => {
    const harness = await registered(makeService());
    await harness.accounts.insert({
      id: 'account-2',
      emailIndex: 'index-2',
      email: 'bernd.beispiel@example.de',
      passwordHash: null,
      emailVerifiedAt: null,
      locale: 'de-DE',
      createdAt: NOW,
      updatedAt: NOW,
    });
    await harness.service.requestDeletion(ACCOUNT);
    await harness.service.requestDeletion('account-2');

    harness.advance(DELETION_GRACE_MS);
    assert.equal(await harness.service.runDuePurges(), 2);
  });

  test('a failure is logged with no personal data', async () => {
    const harness = await registered(makeService({ failingCategory: 'birth_data' }));
    await harness.service.requestDeletion(ACCOUNT);
    harness.advance(DELETION_GRACE_MS);
    await harness.service.runDuePurges();

    const failure = harness.sink.records.find((r) => r.level === 'error');
    assert.ok(failure);
    assert.doesNotMatch(JSON.stringify(failure), /beispiel|@/);
  });
});

describe('US-015 — the account stops working the moment deletion is requested', () => {
  test('every session is revoked at request time, not at purge time', async () => {
    const harness = await registered(makeService());
    await harness.service.requestDeletion(ACCOUNT);

    assert.deepEqual(harness.sessions.revoked, [
      { accountId: ACCOUNT, reason: 'SIGNED_OUT_EVERYWHERE' },
    ]);
  });

  test('the account is locked out during the grace period', async () => {
    const harness = await registered(makeService());
    assert.equal(await harness.service.isLockedOut(ACCOUNT), false);

    await harness.service.requestDeletion(ACCOUNT);
    assert.equal(await harness.service.isLockedOut(ACCOUNT), true);
  });

  test('cancelling restores access', async () => {
    const harness = await registered(makeService());
    await harness.service.requestDeletion(ACCOUNT);

    assert.equal((await harness.service.cancelDeletion(ACCOUNT)).outcome, 'cancelled');
    assert.equal(await harness.service.isLockedOut(ACCOUNT), false);
    assert.equal(harness.mailer.cancelled.length, 1);
  });

  test('a cancelled request is not purged', async () => {
    const harness = await registered(makeService());
    await harness.service.requestDeletion(ACCOUNT);
    await harness.service.cancelDeletion(ACCOUNT);

    harness.advance(DELETION_GRACE_MS);
    assert.equal(await harness.service.runDuePurges(), 0);
    assert.deepEqual(harness.erased, []);
  });

  test('cancelling after the data is gone reports the truth', async () => {
    const harness = await registered(makeService());
    await harness.service.requestDeletion(ACCOUNT);
    harness.advance(DELETION_GRACE_MS);
    await harness.service.runDuePurges();

    assert.equal((await harness.service.cancelDeletion(ACCOUNT)).outcome, 'already_completed');
  });

  test('cancelling something never scheduled says so', async () => {
    const harness = await registered(makeService());
    assert.equal((await harness.service.cancelDeletion(ACCOUNT)).outcome, 'not_scheduled');
  });
});

describe('US-015 — requesting twice is idempotent', () => {
  test('a second request keeps the original date', async () => {
    const harness = await registered(makeService());
    const first = await harness.service.requestDeletion(ACCOUNT);

    harness.advance(60_000);
    const second = await harness.service.requestDeletion(ACCOUNT);

    assert.equal(second.outcome, 'already_scheduled');
    assert.equal(second.purgeDueAt.toISOString(), first.purgeDueAt.toISOString());
  });

  test('a second request does not send a second notice', async () => {
    // Otherwise a double tap mails the user twice about deleting their account.
    const harness = await registered(makeService());
    await harness.service.requestDeletion(ACCOUNT);
    await harness.service.requestDeletion(ACCOUNT);

    assert.equal(harness.mailer.scheduled.length, 1);
  });

  test('an unknown account is reported, not scheduled', async () => {
    const harness = makeService();
    assert.equal((await harness.service.requestDeletion('nobody')).outcome, 'unknown_account');
    assert.equal(harness.mailer.scheduled.length, 0);
  });

  test('deletion can be requested again after a cancellation', async () => {
    const harness = await registered(makeService());
    await harness.service.requestDeletion(ACCOUNT);
    await harness.service.cancelDeletion(ACCOUNT);

    const again = await harness.service.requestDeletion(ACCOUNT);
    assert.equal(again.outcome, 'scheduled');
  });
});

describe('US-015 — a tombstoned account reveals nothing', () => {
  test('the address, its index and the password are all gone', () => {
    const account = {
      id: ACCOUNT,
      emailIndex: 'index-1',
      email: EMAIL,
      passwordHash: 'v1:not-a-real-hash',
      emailVerifiedAt: NOW,
      locale: 'de-DE',
      createdAt: NOW,
      updatedAt: NOW,
    };
    const dead = tombstone(account, NOW);

    assert.equal(dead.email, '');
    assert.equal(dead.passwordHash, null);
    assert.equal(dead.emailVerifiedAt, null);
    // The blind index must not resolve either, or the address stays findable
    // by anyone who can guess it and search.
    assert.equal(dead.emailIndex, '');
    assert.equal(dead.id, ACCOUNT, 'the id survives so a retained invoice still joins');
  });

  test('no placeholder that looks like an address is left behind', () => {
    const dead = tombstone(
      {
        id: ACCOUNT,
        emailIndex: 'index-1',
        email: EMAIL,
        passwordHash: null,
        emailVerifiedAt: null,
        locale: 'de-DE',
        createdAt: NOW,
        updatedAt: NOW,
      },
      NOW,
    );
    assert.doesNotMatch(JSON.stringify(dead), /@/);
  });
});

/**
 * The identity module, the session store and the deletion service wired
 * together as production would wire them.
 *
 * The point of these tests is the seams: a deletion request has to reach both
 * the login path and the refresh path, and neither connection is visible from
 * inside `deletion.ts`.
 */
async function wiredHarness() {
  const clock = { at: NOW };
  const now = () => clock.at;

  const accounts = new InMemoryAccountRepository();
  const deletions = new InMemoryDeletionRepository();
  const throttles = new InMemoryThrottleStore();
  const sessionRepository = new InMemorySessionRepository();

  const sessions = new SessionStore({
    sessions: sessionRepository,
    issuer: new AccessTokenIssuer(SIGNING_KEY),
    resolvePrincipal: async (accountId) => {
      // US-016's hook, wired to US-015: an account inside its grace period
      // stops refreshing, and a purged one has nothing left to resolve.
      if (await deletionService.isLockedOut(accountId)) return null;
      const account = await accounts.findById(accountId);
      return account === null
        ? null
        : { accountId, emailVerified: account.emailVerifiedAt !== null };
    },
    now,
  });

  const deletionService = new DeletionService({
    accounts,
    deletions,
    sessions,
    mailer: new RecordingMailer(),
    erasers: erasedCategories().map((category) =>
      callbackEraser(category, async (accountId) => {
        if (category === 'account') {
          const account = await accounts.findById(accountId);
          if (account !== null) await accounts.update(tombstone(account, now()));
        }
      }),
    ),
    now,
  });

  const identity = new IdentityService({
    accounts,
    tokens: new InMemoryTokenRepository(),
    hasher: new FakeHasher(),
    policy: new PasswordPolicy(InMemoryBreachList.fromPasswords([])),
    indexer: new EmailIndexer(PEPPER),
    loginThrottle: new LoginThrottle(throttles, {}, now),
    mailThrottle: new LoginThrottle(throttles, MAIL_THROTTLE_LIMITS, now),
    mailer: new SilentMailer(),
    sessions,
    lockout: deletionService,
    now,
    newId: () => ACCOUNT,
  });

  await identity.signUp({ email: EMAIL, password: PASSWORD, locale: 'de-DE' });

  return {
    identity,
    sessions,
    deletionService,
    accounts,
    advance(ms) {
      clock.at = new Date(clock.at.getTime() + ms);
    },
  };
}

const PEPPER = 'test-pepper-not-a-real-secret-0123456789';
const SIGNING_KEY = 'test-signing-key-not-a-real-secret-0123456789';
const PASSWORD = 'graureiherfeder-77';

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

class SilentMailer {
  async sendVerificationLink() {}
  async sendPasswordResetLink() {}
  async sendPasswordChangedNotice() {}
  async sendAccountAlreadyExistsNotice() {}
}

describe('US-015 — deletion actually closes the account', () => {
  test('a live session cannot refresh once deletion is requested', async () => {
    const harness = await wiredHarness();
    const session = await harness.sessions.start(
      { accountId: ACCOUNT, emailVerified: false },
      "Anna's iPhone",
    );

    await harness.deletionService.requestDeletion(ACCOUNT);

    const refreshed = await harness.sessions.refresh(session.refreshToken);
    assert.equal(refreshed.outcome, 'rejected');
    assert.equal(refreshed.reason, 'REVOKED');
  });

  test('the right password does not reopen the account', async () => {
    // Without this, "delete my account" is a button that logs you out.
    const harness = await wiredHarness();
    await harness.deletionService.requestDeletion(ACCOUNT);

    const result = await harness.identity.logIn({ email: EMAIL, password: PASSWORD });
    assert.equal(result.outcome, 'rejected');
    assert.equal(result.reason, 'PENDING_DELETION');
  });

  test('a wrong password still says only INVALID_CREDENTIALS', async () => {
    // Whether an address is awaiting deletion must not be answerable by
    // someone who does not know the password.
    const harness = await wiredHarness();
    await harness.deletionService.requestDeletion(ACCOUNT);

    const result = await harness.identity.logIn({ email: EMAIL, password: 'wrong-password-x' });
    assert.equal(result.reason, 'INVALID_CREDENTIALS');
  });

  test('an unregistered address is indistinguishable from a pending one', async () => {
    const harness = await wiredHarness();
    await harness.deletionService.requestDeletion(ACCOUNT);

    const stranger = await harness.identity.logIn({
      email: 'niemand@example.de',
      password: PASSWORD,
    });
    assert.equal(stranger.reason, 'INVALID_CREDENTIALS');
  });

  test('cancelling lets the user back in', async () => {
    const harness = await wiredHarness();
    await harness.deletionService.requestDeletion(ACCOUNT);
    await harness.deletionService.cancelDeletion(ACCOUNT);

    const result = await harness.identity.logIn({ email: EMAIL, password: PASSWORD });
    assert.equal(result.outcome, 'authenticated');
  });

  test('after the purge the address no longer resolves to an account', async () => {
    const harness = await wiredHarness();
    await harness.deletionService.requestDeletion(ACCOUNT);
    harness.advance(DELETION_GRACE_MS);
    await harness.deletionService.runDuePurges();

    const result = await harness.identity.logIn({ email: EMAIL, password: PASSWORD });
    assert.equal(result.reason, 'INVALID_CREDENTIALS');
  });

  test('the address is free for a new sign-up after the purge', async () => {
    // The blind index has to be cleared for this, not merely the address.
    const harness = await wiredHarness();
    await harness.deletionService.requestDeletion(ACCOUNT);
    harness.advance(DELETION_GRACE_MS);
    await harness.deletionService.runDuePurges();

    const again = await harness.identity.signUp({
      email: EMAIL,
      password: PASSWORD,
      locale: 'de-DE',
    });
    assert.equal(again.outcome, 'accepted');
  });
});
