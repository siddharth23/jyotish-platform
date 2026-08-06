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
  MAX_ACCOUNT_FAILURES,
} from '../dist/modules/identity/login_throttle.js';
import {
  InMemoryBreachList,
  PasswordPolicy,
} from '../dist/modules/identity/password_policy.js';
import {
  EMAIL_VERIFICATION_TTL_MS,
  InMemoryTokenRepository,
  PASSWORD_RESET_TTL_MS,
} from '../dist/modules/identity/secret_token.js';

/** Synthetic throughout: CLAUDE.md forbids real personal data in fixtures. */
const PEPPER = 'test-pepper-not-a-real-secret-0123456789';
const EMAIL = 'anna.beispiel@example.de';
const PASSWORD = 'graureiherfeder-77';
const NEW_PASSWORD = 'zwölf-blaue-koffer';
const CLIENT = '203.0.113.7';

/**
 * A stand-in for scrypt.
 *
 * The real hasher costs 64 MiB and about a tenth of a second per call, and this
 * file logs in dozens of times. `password_hasher.test.js` covers the real one.
 */
class FakeHasher {
  constructor() {
    this.version = 'v1';
    this.spentVerificationTime = 0;
  }
  async hash(password) {
    return `${this.version}:${password}`;
  }
  async verify(password, encoded) {
    return encoded.slice(encoded.indexOf(':') + 1) === password;
  }
  async spendVerificationTime() {
    this.spentVerificationTime += 1;
  }
  needsRehash(encoded) {
    return !encoded.startsWith(`${this.version}:`);
  }
}

class RecordingMailer {
  constructor() {
    this.verifications = [];
    this.resets = [];
    this.changed = [];
    this.alreadyExists = [];
  }
  async sendVerificationLink(to, secret) {
    this.verifications.push({ to, secret });
  }
  async sendPasswordResetLink(to, secret) {
    this.resets.push({ to, secret });
  }
  async sendPasswordChangedNotice(to) {
    this.changed.push({ to });
  }
  async sendAccountAlreadyExistsNotice(to) {
    this.alreadyExists.push({ to });
  }
  get lastVerificationSecret() {
    return this.verifications[this.verifications.length - 1].secret;
  }
  get lastResetSecret() {
    return this.resets[this.resets.length - 1].secret;
  }
}

class RecordingRevoker {
  constructor() {
    this.revoked = [];
  }
  async revokeAllForAccount(accountId) {
    this.revoked.push(accountId);
  }
}

function makeService() {
  const clock = { at: new Date('2026-08-06T09:00:00Z') };
  const now = () => clock.at;

  const accounts = new InMemoryAccountRepository();
  const tokens = new InMemoryTokenRepository();
  const store = new InMemoryThrottleStore();
  const hasher = new FakeHasher();
  const mailer = new RecordingMailer();
  const sessions = new RecordingRevoker();
  const sink = new MemorySink();
  const indexer = new EmailIndexer(PEPPER);

  let counter = 0;
  const service = new IdentityService({
    accounts,
    tokens,
    hasher,
    policy: new PasswordPolicy(InMemoryBreachList.fromPasswords(['sonnenschein'])),
    indexer,
    loginThrottle: new LoginThrottle(store, {}, now),
    mailThrottle: new LoginThrottle(store, MAIL_THROTTLE_LIMITS, now),
    mailer,
    sessions,
    logger: new Logger(sink, 'debug', now),
    now,
    newId: () => `account-${(counter += 1)}`,
  });

  return {
    service,
    accounts,
    tokens,
    hasher,
    mailer,
    sessions,
    sink,
    indexer,
    advance(ms) {
      clock.at = new Date(clock.at.getTime() + ms);
    },
  };
}

/** A registered, unverified account. */
async function registered(harness = makeService()) {
  const result = await harness.service.signUp({
    email: EMAIL,
    password: PASSWORD,
    locale: 'de-DE',
    clientAddress: CLIENT,
  });
  assert.equal(result.outcome, 'accepted');
  return harness;
}

describe('US-011 AC1 — sign-up sends a verification link', () => {
  test('creates the account and mails a link', async () => {
    const { service, accounts, mailer } = await registered();

    assert.equal(accounts.size, 1);
    assert.equal(mailer.verifications.length, 1);
    assert.equal(mailer.verifications[0].to.email, EMAIL);
    assert.equal(mailer.verifications[0].to.locale, 'de-DE');
    assert.ok(mailer.lastVerificationSecret.length > 20);

    const login = await service.logIn({ email: EMAIL, password: PASSWORD });
    assert.equal(login.principal.emailVerified, false);
  });

  test('the link verifies the address', async () => {
    const { service, mailer } = await registered();

    const result = await service.verifyEmail(mailer.lastVerificationSecret);
    assert.equal(result.outcome, 'verified');

    const login = await service.logIn({ email: EMAIL, password: PASSWORD });
    assert.equal(login.principal.emailVerified, true);
  });

  test('the link works once', async () => {
    const { service, mailer } = await registered();
    const secret = mailer.lastVerificationSecret;

    assert.equal((await service.verifyEmail(secret)).outcome, 'verified');
    const second = await service.verifyEmail(secret);
    assert.equal(second.outcome, 'rejected');
    assert.equal(second.reason, 'ALREADY_USED');
  });

  test('the link expires after a day', async () => {
    const { service, mailer, advance } = await registered();
    advance(EMAIL_VERIFICATION_TTL_MS);

    const result = await service.verifyEmail(mailer.lastVerificationSecret);
    assert.equal(result.outcome, 'rejected');
    assert.equal(result.reason, 'EXPIRED');
  });

  test('an unknown link is rejected without saying why it is unknown', async () => {
    const { service } = await registered();
    const result = await service.verifyEmail('never-issued');
    assert.equal(result.outcome, 'rejected');
    assert.equal(result.reason, 'NOT_FOUND');
  });

  test('resending replaces the previous link', async () => {
    const { service, mailer } = await registered();
    const first = mailer.lastVerificationSecret;

    await service.resendVerification(EMAIL, CLIENT);
    assert.equal(mailer.verifications.length, 2);
    const second = mailer.lastVerificationSecret;
    assert.notEqual(first, second);

    assert.equal((await service.verifyEmail(first)).reason, 'ALREADY_USED');
    assert.equal((await service.verifyEmail(second)).outcome, 'verified');
  });

  test('resending for an unknown or already verified address sends nothing', async () => {
    const { service, mailer } = await registered();
    await service.verifyEmail(mailer.lastVerificationSecret);

    await service.resendVerification(EMAIL, CLIENT);
    await service.resendVerification('niemand@example.de', CLIENT);
    await service.resendVerification('kaputt', CLIENT);
    assert.equal(mailer.verifications.length, 1);
  });
});

describe('US-011 AC2 — the password policy applies at sign-up', () => {
  test('rejects a weak password and creates nothing', async () => {
    const { service, accounts, mailer } = makeService();
    const result = await service.signUp({ email: EMAIL, password: 'kurz', locale: 'de-DE' });

    assert.equal(result.outcome, 'weak_password');
    assert.ok(result.rejections.includes('TOO_SHORT'));
    assert.equal(accounts.size, 0);
    assert.equal(mailer.verifications.length, 0);
  });

  test('rejects a breached password', async () => {
    const { service } = makeService();
    const result = await service.signUp({ email: EMAIL, password: 'sonnenschein', locale: 'de-DE' });
    assert.equal(result.outcome, 'weak_password');
    assert.deepEqual(result.rejections, ['BREACHED']);
  });

  test('rejects a malformed address', async () => {
    const { service, accounts } = makeService();
    const result = await service.signUp({ email: 'anna@localhost', password: PASSWORD, locale: 'de-DE' });
    assert.equal(result.outcome, 'invalid_email');
    assert.equal(accounts.size, 0);
  });

  test('normalises the address, so case does not create a second account', async () => {
    const { service, accounts } = makeService();
    await service.signUp({ email: '  Anna.Beispiel@Example.DE ', password: PASSWORD, locale: 'de-DE' });
    assert.equal(accounts.size, 1);

    const login = await service.logIn({ email: EMAIL, password: PASSWORD });
    assert.equal(login.outcome, 'authenticated');
  });
});

describe('sign-up does not disclose who has an account', () => {
  test('a taken address answers exactly like a fresh one', async () => {
    const harness = await registered();
    const { service, accounts, mailer } = harness;

    const second = await service.signUp({
      email: EMAIL,
      password: 'ein-ganz-anderes-wort',
      locale: 'de-DE',
      clientAddress: CLIENT,
    });

    assert.equal(second.outcome, 'accepted');
    assert.equal(accounts.size, 1);
    // The real owner is told; the person at the keyboard learns nothing.
    assert.equal(mailer.alreadyExists.length, 1);
    assert.equal(mailer.alreadyExists[0].to.email, EMAIL);
    assert.equal(mailer.verifications.length, 1);
  });

  test('the second sign-up does not overwrite the first password', async () => {
    const { service } = await registered();
    await service.signUp({ email: EMAIL, password: 'ein-ganz-anderes-wort', locale: 'de-DE' });

    assert.equal((await service.logIn({ email: EMAIL, password: PASSWORD })).outcome, 'authenticated');
    const attacker = await service.logIn({ email: EMAIL, password: 'ein-ganz-anderes-wort' });
    assert.equal(attacker.outcome, 'rejected');
  });

  test('both branches cost a password hash, so a stopwatch cannot tell them apart', async () => {
    const { service, hasher } = await registered();
    let hashed = 0;
    const original = hasher.hash.bind(hasher);
    hasher.hash = async (password) => {
      hashed += 1;
      return original(password);
    };

    await service.signUp({ email: EMAIL, password: 'ein-ganz-anderes-wort', locale: 'de-DE' });
    assert.equal(hashed, 1);
  });

  test('the mail budget stops an address being used as a mail cannon', async () => {
    const { service, mailer } = await registered();
    for (let i = 0; i < 10; i += 1) {
      await service.signUp({ email: EMAIL, password: PASSWORD, locale: 'de-DE', clientAddress: CLIENT });
    }
    // One verification plus four notices: five messages an hour, then silence.
    assert.equal(mailer.verifications.length + mailer.alreadyExists.length, 5);
  });

  test('an exhausted mail budget does not stop that address registering', async () => {
    // Otherwise anyone could burn a stranger's allowance and lock them out of
    // signing up at all. The account is created; only the link is deferred.
    const { service, accounts, mailer } = makeService();
    for (let i = 0; i < 6; i += 1) {
      await service.requestPasswordReset(EMAIL, CLIENT);
    }

    const result = await service.signUp({
      email: EMAIL,
      password: PASSWORD,
      locale: 'de-DE',
      clientAddress: CLIENT,
    });
    assert.equal(result.outcome, 'accepted');
    assert.equal(accounts.size, 1);
    assert.equal(mailer.verifications.length, 0);
    assert.equal((await service.logIn({ email: EMAIL, password: PASSWORD })).outcome, 'authenticated');
  });

  test('asking about an unregistered address costs the same budget as a real one', async () => {
    // A free question is a question an attacker can ask all day; comparing
    // which addresses run out would sort the registered from the rest.
    const { service, mailer } = makeService();
    for (let i = 0; i < 5; i += 1) {
      await service.requestPasswordReset('niemand@example.de', CLIENT);
    }
    await service.signUp({ email: 'niemand@example.de', password: PASSWORD, locale: 'de-DE', clientAddress: CLIENT });
    assert.equal(mailer.verifications.length, 0);
  });
});

describe('logging in', () => {
  test('accepts the right password and returns a principal, not a session', async () => {
    const { service } = await registered();
    const result = await service.logIn({ email: EMAIL, password: PASSWORD, clientAddress: CLIENT });

    assert.equal(result.outcome, 'authenticated');
    assert.equal(result.principal.accountId, 'account-1');
    // Tokens are US-016. Nothing session-shaped is issued here.
    assert.deepEqual(Object.keys(result.principal).sort(), ['accountId', 'emailVerified']);
  });

  test('rejects the wrong password', async () => {
    const { service } = await registered();
    const result = await service.logIn({ email: EMAIL, password: 'falsch-geraten-99' });
    assert.equal(result.outcome, 'rejected');
    assert.equal(result.reason, 'INVALID_CREDENTIALS');
  });

  test('answers an unknown address identically, and pays the same cost', async () => {
    const { service, hasher } = await registered();
    const result = await service.logIn({ email: 'niemand@example.de', password: PASSWORD });

    assert.equal(result.reason, 'INVALID_CREDENTIALS');
    // Without this the response time classifies every address in a list.
    assert.equal(hasher.spentVerificationTime, 1);
  });

  test('rejects a password login against an account that has no password', async () => {
    // Sign in with Apple or Google (US-012) leaves the hash null. Null means
    // "no password login", never "any password will do".
    const { service, accounts, hasher } = await registered();
    const account = await accounts.findById('account-1');
    await accounts.update({ ...account, passwordHash: null });

    const result = await service.logIn({ email: EMAIL, password: PASSWORD });
    assert.equal(result.reason, 'INVALID_CREDENTIALS');
    assert.equal(hasher.spentVerificationTime, 1);
  });

  test('a malformed address is rejected without a lookup', async () => {
    const { service } = await registered();
    assert.equal((await service.logIn({ email: 'kaputt', password: PASSWORD })).reason, 'INVALID_CREDENTIALS');
  });

  test('re-hashes when the stored parameters fall behind', async () => {
    const { service, accounts, hasher } = await registered();
    assert.equal((await accounts.findById('account-1')).passwordHash, `v1:${PASSWORD}`);

    hasher.version = 'v2';
    assert.equal((await service.logIn({ email: EMAIL, password: PASSWORD })).outcome, 'authenticated');
    // The only moment the plaintext exists is the only moment this can happen.
    assert.equal((await accounts.findById('account-1')).passwordHash, `v2:${PASSWORD}`);
  });

  test('a failed re-hash does not fail the login', async () => {
    const { service, accounts, hasher } = await registered();
    hasher.version = 'v2';
    accounts.update = async () => {
      throw new Error('database unavailable');
    };
    assert.equal((await service.logIn({ email: EMAIL, password: PASSWORD })).outcome, 'authenticated');
  });
});

describe('US-011 AC3 — rate limiting and lockout', () => {
  test('ten wrong passwords lock the account', async () => {
    const { service } = await registered();
    for (let i = 0; i < MAX_ACCOUNT_FAILURES; i += 1) {
      const attempt = await service.logIn({ email: EMAIL, password: 'falsch-geraten-99' });
      assert.equal(attempt.reason, 'INVALID_CREDENTIALS', `attempt ${i + 1}`);
    }

    const locked = await service.logIn({ email: EMAIL, password: 'falsch-geraten-99' });
    assert.equal(locked.reason, 'TEMPORARILY_LOCKED');
    assert.equal(locked.retryAfterMs, 15 * 60 * 1000);
  });

  test('the lock holds even against the correct password', async () => {
    const { service } = await registered();
    for (let i = 0; i < MAX_ACCOUNT_FAILURES; i += 1) {
      await service.logIn({ email: EMAIL, password: 'falsch-geraten-99' });
    }
    assert.equal((await service.logIn({ email: EMAIL, password: PASSWORD })).reason, 'TEMPORARILY_LOCKED');
  });

  test('and lifts on its own after fifteen minutes', async () => {
    const { service, advance } = await registered();
    for (let i = 0; i < MAX_ACCOUNT_FAILURES; i += 1) {
      await service.logIn({ email: EMAIL, password: 'falsch-geraten-99' });
    }
    advance(15 * 60 * 1000);
    assert.equal((await service.logIn({ email: EMAIL, password: PASSWORD })).outcome, 'authenticated');
  });

  test('an address with no account locks the same way', async () => {
    // Otherwise watching which addresses lock is an enumeration oracle, and
    // every identical error message above it is wasted.
    const { service } = await registered();
    for (let i = 0; i < MAX_ACCOUNT_FAILURES; i += 1) {
      await service.logIn({ email: 'niemand@example.de', password: PASSWORD });
    }
    const locked = await service.logIn({ email: 'niemand@example.de', password: PASSWORD });
    assert.equal(locked.reason, 'TEMPORARILY_LOCKED');
  });

  test('a correct password clears the counter', async () => {
    const { service } = await registered();
    for (let i = 0; i < MAX_ACCOUNT_FAILURES - 1; i += 1) {
      await service.logIn({ email: EMAIL, password: 'falsch-geraten-99' });
    }
    await service.logIn({ email: EMAIL, password: PASSWORD });

    for (let i = 0; i < MAX_ACCOUNT_FAILURES - 1; i += 1) {
      await service.logIn({ email: EMAIL, password: 'falsch-geraten-99' });
    }
    assert.equal((await service.logIn({ email: EMAIL, password: PASSWORD })).outcome, 'authenticated');
  });

  test('the throttle is consulted before the password is verified', async () => {
    const { service, hasher } = await registered();
    for (let i = 0; i < MAX_ACCOUNT_FAILURES; i += 1) {
      await service.logIn({ email: EMAIL, password: 'falsch-geraten-99' });
    }
    let verifications = 0;
    hasher.verify = async () => {
      verifications += 1;
      return false;
    };
    await service.logIn({ email: EMAIL, password: PASSWORD });
    // Spending 64 MiB on an attempt that was going to be refused is the
    // resource the limiter exists to protect.
    assert.equal(verifications, 0);
  });
});

describe('US-011 AC4 — password reset', () => {
  test('mails a link valid for thirty minutes', async () => {
    const { service, mailer, tokens, advance } = await registered();
    await service.requestPasswordReset(EMAIL, CLIENT);

    assert.equal(mailer.resets.length, 1);
    assert.equal(mailer.resets[0].to.email, EMAIL);

    advance(PASSWORD_RESET_TTL_MS - 1);
    const inTime = await service.resetPassword({
      secret: mailer.lastResetSecret,
      password: NEW_PASSWORD,
    });
    assert.equal(inTime.outcome, 'reset');
    assert.ok(tokens);
  });

  test('a link older than thirty minutes is refused', async () => {
    const { service, mailer, advance } = await registered();
    await service.requestPasswordReset(EMAIL, CLIENT);
    advance(PASSWORD_RESET_TTL_MS);

    const result = await service.resetPassword({
      secret: mailer.lastResetSecret,
      password: NEW_PASSWORD,
    });
    assert.equal(result.outcome, 'rejected');
    assert.equal(result.reason, 'EXPIRED');
  });

  test('the new password replaces the old one', async () => {
    const { service, mailer } = await registered();
    await service.requestPasswordReset(EMAIL, CLIENT);
    await service.resetPassword({ secret: mailer.lastResetSecret, password: NEW_PASSWORD });

    assert.equal((await service.logIn({ email: EMAIL, password: PASSWORD })).outcome, 'rejected');
    assert.equal((await service.logIn({ email: EMAIL, password: NEW_PASSWORD })).outcome, 'authenticated');
  });

  test('the link works once', async () => {
    const { service, mailer } = await registered();
    await service.requestPasswordReset(EMAIL, CLIENT);
    const secret = mailer.lastResetSecret;

    await service.resetPassword({ secret, password: NEW_PASSWORD });
    const second = await service.resetPassword({ secret, password: 'noch-ein-anderes-wort' });
    assert.equal(second.outcome, 'rejected');
    assert.equal(second.reason, 'ALREADY_USED');
  });

  test('requesting a new link kills the previous one', async () => {
    // A link forwarded, screenshotted or sitting in a shared inbox must not
    // outlive the reset the user actually performed.
    const { service, mailer } = await registered();
    await service.requestPasswordReset(EMAIL, CLIENT);
    const first = mailer.lastResetSecret;
    await service.requestPasswordReset(EMAIL, CLIENT);
    const second = mailer.lastResetSecret;

    assert.notEqual(first, second);
    assert.equal((await service.resetPassword({ secret: first, password: NEW_PASSWORD })).reason, 'ALREADY_USED');
    assert.equal((await service.resetPassword({ secret: second, password: NEW_PASSWORD })).outcome, 'reset');
  });

  test('a weak new password is refused without burning the link', async () => {
    const { service, mailer } = await registered();
    await service.requestPasswordReset(EMAIL, CLIENT);
    const secret = mailer.lastResetSecret;

    const rejected = await service.resetPassword({ secret, password: 'kurz' });
    assert.equal(rejected.outcome, 'weak_password');
    assert.ok(rejected.rejections.includes('TOO_SHORT'));

    // Sending the user back for another email over a typo is not acceptable.
    assert.equal((await service.resetPassword({ secret, password: NEW_PASSWORD })).outcome, 'reset');
  });

  test('a verification link cannot be redeemed as a reset', async () => {
    const { service, mailer } = await registered();
    const result = await service.resetPassword({
      secret: mailer.lastVerificationSecret,
      password: NEW_PASSWORD,
    });
    assert.equal(result.outcome, 'rejected');
    assert.equal(result.reason, 'WRONG_PURPOSE');
  });

  test('the reset revokes every session', async () => {
    // US-016 AC4. A takeover that ends with the attacker still signed in is
    // not over.
    const { service, mailer, sessions } = await registered();
    await service.requestPasswordReset(EMAIL, CLIENT);
    await service.resetPassword({ secret: mailer.lastResetSecret, password: NEW_PASSWORD });

    assert.deepEqual(sessions.revoked, ['account-1']);
  });

  test('the reset lifts a lockout', async () => {
    // Someone locked out by an attacker's guesses must have a way back in, and
    // mailbox control outranks the failed attempts that caused the lock.
    const { service, mailer } = await registered();
    await service.requestPasswordReset(EMAIL, CLIENT);
    for (let i = 0; i < MAX_ACCOUNT_FAILURES; i += 1) {
      await service.logIn({ email: EMAIL, password: 'falsch-geraten-99' });
    }
    assert.equal((await service.logIn({ email: EMAIL, password: PASSWORD })).reason, 'TEMPORARILY_LOCKED');

    await service.resetPassword({ secret: mailer.lastResetSecret, password: NEW_PASSWORD });
    assert.equal((await service.logIn({ email: EMAIL, password: NEW_PASSWORD })).outcome, 'authenticated');
  });

  test('the reset also verifies the address', async () => {
    // Clicking the link proved the same thing the verification link proves.
    const { service, mailer, accounts } = await registered();
    await service.requestPasswordReset(EMAIL, CLIENT);
    await service.resetPassword({ secret: mailer.lastResetSecret, password: NEW_PASSWORD });

    assert.notEqual((await accounts.findById('account-1')).emailVerifiedAt, null);
  });

  test('the reset mails a notice the attacker cannot suppress', async () => {
    const { service, mailer } = await registered();
    await service.requestPasswordReset(EMAIL, CLIENT);
    await service.resetPassword({ secret: mailer.lastResetSecret, password: NEW_PASSWORD });

    assert.equal(mailer.changed.length, 1);
    assert.equal(mailer.changed[0].to.email, EMAIL);
  });

  test('a request for an unregistered or malformed address resolves silently', async () => {
    const { service, mailer } = await registered();
    await service.requestPasswordReset('niemand@example.de', CLIENT);
    await service.requestPasswordReset('kaputt', CLIENT);

    // No throw, no mail, no signal of any kind.
    assert.equal(mailer.resets.length, 0);
  });

  test('the request is rate limited', async () => {
    const { service, mailer } = await registered();
    for (let i = 0; i < 10; i += 1) {
      await service.requestPasswordReset(EMAIL, CLIENT);
    }
    // Sign-up already spent one of the five messages allowed this hour.
    assert.equal(mailer.resets.length, 4);
  });
});

describe('logging', () => {
  test('no log line carries the address or the password', async () => {
    const { service, mailer, sink } = await registered();
    await service.requestPasswordReset(EMAIL, CLIENT);
    await service.resetPassword({ secret: mailer.lastResetSecret, password: NEW_PASSWORD });
    await service.logIn({ email: EMAIL, password: 'falsch-geraten-99' });
    for (let i = 0; i < MAX_ACCOUNT_FAILURES; i += 1) {
      await service.logIn({ email: EMAIL, password: 'falsch-geraten-99' });
    }

    assert.ok(sink.records.length > 0);
    const written = JSON.stringify(sink.records);
    for (const secret of [EMAIL, 'anna.beispiel', PASSWORD, NEW_PASSWORD, CLIENT]) {
      assert.equal(written.includes(secret), false, secret);
    }
  });

  test('records the account id, which resolves to a person only via the database', async () => {
    const { sink } = await registered();
    const created = sink.records.find((record) => record.message === 'account created');
    assert.equal(created.fields.userId, 'account-1');
  });
});
