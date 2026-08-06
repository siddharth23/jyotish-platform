/**
 * Sign-up, login, email verification and password reset (US-011).
 *
 * ## What this does not do
 *
 * It does not issue sessions. A successful login returns an
 * [AuthenticatedPrincipal] and stops. Access tokens, refresh rotation and
 * remote sign-out are US-016; putting a token format here would mean building
 * it twice. The seam is [SessionRevoker], which US-016 implements and which
 * password reset already calls — US-016 AC4 ("sessions invalidated on password
 * change") is therefore a matter of supplying the implementation, not of
 * revisiting this file.
 *
 * It also has no HTTP layer, because this service has none yet: `main.ts` is
 * still a stub. What is here is the domain, with ports for storage, mail and
 * sessions.
 *
 * ## Account enumeration is treated as a requirement, not a nicety
 *
 * An endpoint that reveals whether an address is registered leaks that a person
 * uses a Vedic astrology service. Under GDPR that is a disclosure about a named
 * individual, and the plausible inferences — belief, ethnicity — are the
 * special categories in Article 9. So every route out of this class is shaped
 * to answer identically for a registered and an unregistered address:
 *
 * - Sign-up with a taken address returns the same result as a fresh one, and
 *   mails the existing owner instead of creating anything.
 * - A password reset request always resolves the same way.
 * - A login against a non-existent account still spends a full scrypt
 *   verification, so the response time does not give it away.
 * - Failed attempts are counted for addresses with no account, so lockouts do
 *   not distinguish either.
 *
 * LICENSING: no engine code. See docs/AGPL-BOUNDARY.md.
 */

import { Logger } from '../../observability/logger.js';

import {
  type Account,
  type AccountRepository,
  DuplicateAccountError,
} from './account.js';
import { EmailAddressError, normaliseEmail } from './email_address.js';
import { EmailIndexer } from './email_index.js';
import { LoginThrottle } from './login_throttle.js';
import { type PasswordHasher } from './password_hasher.js';
import {
  normalisePassword,
  type PasswordPolicy,
  type PasswordRejection,
} from './password_policy.js';
import {
  EMAIL_VERIFICATION_TTL_MS,
  issueToken,
  lookupToken,
  PASSWORD_RESET_TTL_MS,
  type TokenRejection,
  type TokenRepository,
} from './secret_token.js';

/** The recipient of a transactional email. Never logged. */
export interface MailRecipient {
  readonly email: string;
  readonly locale: string;
}

/**
 * Outbound transactional mail.
 *
 * Implemented by the `notification` module. The bodies are ICU resources there,
 * not strings in this file — German is the source language and roughly 30%
 * longer than English (CLAUDE.md).
 */
export interface IdentityMailer {
  /** US-011 AC1. [secret] goes in the link and nowhere else. */
  sendVerificationLink(to: MailRecipient, secret: string): Promise<void>;
  /** US-011 AC4. */
  sendPasswordResetLink(to: MailRecipient, secret: string): Promise<void>;
  /**
   * Sent after a password changes.
   *
   * Not a courtesy. It is how someone whose account has been taken over finds
   * out, and it is the only notification an attacker cannot suppress.
   */
  sendPasswordChangedNotice(to: MailRecipient): Promise<void>;
  /**
   * Sent when someone tries to register an address that already has an account.
   *
   * The substitute for an error message. It tells the real owner that someone
   * used their address, and tells the person at the keyboard nothing at all.
   */
  sendAccountAlreadyExistsNotice(to: MailRecipient): Promise<void>;
}

/** Implemented by US-016. */
export interface SessionRevoker {
  revokeAllForAccount(accountId: string): Promise<void>;
}

/** A no-op revoker for the period before US-016 lands. */
export class NoSessionRevoker implements SessionRevoker {
  async revokeAllForAccount(): Promise<void> {
    // Nothing to revoke: no sessions are issued yet.
  }
}

export interface IdentityServiceDependencies {
  readonly accounts: AccountRepository;
  readonly tokens: TokenRepository;
  readonly hasher: PasswordHasher;
  readonly policy: PasswordPolicy;
  readonly indexer: EmailIndexer;
  /** Guards password verification. US-011 AC3. */
  readonly loginThrottle: LoginThrottle;
  /**
   * Guards anything that sends mail to an address the sender does not control.
   * Without it, sign-up and password reset are an open mail relay pointed at
   * whoever the attacker names, and the bounce rate takes the sending domain's
   * reputation with it.
   */
  readonly mailThrottle: LoginThrottle;
  readonly mailer: IdentityMailer;
  readonly sessions?: SessionRevoker;
  readonly logger?: Logger;
  readonly now?: () => Date;
  readonly newId?: () => string;
}

export interface SignUpRequest {
  readonly email: string;
  readonly password: string;
  readonly locale: string;
  /** As determined by the edge. Omitted when there is no trustworthy value. */
  readonly clientAddress?: string;
}

export type SignUpResult =
  /**
   * The request was well formed. Says nothing about whether an account was
   * created — see the enumeration note at the top of the file.
   */
  | { readonly outcome: 'accepted' }
  | { readonly outcome: 'invalid_email'; readonly reason: string }
  | { readonly outcome: 'weak_password'; readonly rejections: readonly PasswordRejection[] };

export interface LoginRequest {
  readonly email: string;
  readonly password: string;
  readonly clientAddress?: string;
}

/** What a successful login yields. Sessions are US-016's to build on top. */
export interface AuthenticatedPrincipal {
  readonly accountId: string;
  /**
   * Unverified accounts may authenticate; ordering a paid report requires a
   * verified address, which the `order` module enforces. Blocking login outright
   * would strand anyone whose verification mail was filtered, and the address
   * has to be proven before a €11 PDF is sent to it either way.
   */
  readonly emailVerified: boolean;
}

export type LoginRejection = 'INVALID_CREDENTIALS' | 'TEMPORARILY_LOCKED';

export type LoginResult =
  | { readonly outcome: 'authenticated'; readonly principal: AuthenticatedPrincipal }
  | {
      readonly outcome: 'rejected';
      readonly reason: LoginRejection;
      /** Present for a lockout, so a client can show a countdown. */
      readonly retryAfterMs?: number;
    };

export type VerifyEmailResult =
  | { readonly outcome: 'verified'; readonly accountId: string }
  | { readonly outcome: 'rejected'; readonly reason: TokenRejection };

export interface ResetPasswordRequest {
  readonly secret: string;
  readonly password: string;
}

export type ResetPasswordResult =
  | { readonly outcome: 'reset'; readonly accountId: string }
  | { readonly outcome: 'rejected'; readonly reason: TokenRejection }
  | { readonly outcome: 'weak_password'; readonly rejections: readonly PasswordRejection[] };

export class IdentityService {
  private readonly sessions: SessionRevoker;
  private readonly logger: Logger;
  private readonly now: () => Date;
  private readonly newId: () => string;

  constructor(private readonly dependencies: IdentityServiceDependencies) {
    this.sessions = dependencies.sessions ?? new NoSessionRevoker();
    this.logger = dependencies.logger ?? new Logger();
    this.now = dependencies.now ?? ((): Date => new Date());
    this.newId = dependencies.newId ?? ((): string => crypto.randomUUID());
  }

  /**
   * Creates an account and sends a verification link (US-011 AC1, AC2).
   *
   * The password is checked before the address is looked up. That ordering is
   * what lets a weak password be reported in detail without the response
   * depending on whether the account exists.
   */
  async signUp(request: SignUpRequest): Promise<SignUpResult> {
    let email: string;
    try {
      email = normaliseEmail(request.email);
    } catch (error) {
      const code = error instanceof EmailAddressError ? error.code : 'MALFORMED';
      return { outcome: 'invalid_email', reason: code };
    }

    const password = normalisePassword(request.password);
    const verdict = await this.dependencies.policy.check(password, { email });
    if (!verdict.acceptable) {
      return { outcome: 'weak_password', rejections: verdict.rejections };
    }

    const emailIndex = this.dependencies.indexer.forEmail(email);
    const clientKey = this.clientKey(request.clientAddress);

    // Hashed before the address is looked up, and discarded unused if it turns
    // out to be taken. The identical response text would otherwise still be
    // separable with a stopwatch: creating an account costs a full scrypt
    // derivation, recognising a duplicate costs a SELECT. Paying it on both
    // paths is the cheapest way to make the two indistinguishable.
    const passwordHash = await this.dependencies.hasher.hash(password);

    const at = this.now();
    const existing = await this.dependencies.accounts.findByEmailIndex(emailIndex);
    if (existing !== null) {
      await this.sendIfBudgetAllows(emailIndex, clientKey, 'sign_up', () =>
        this.dependencies.mailer.sendAccountAlreadyExistsNotice({
          email: existing.email,
          locale: existing.locale,
        }),
      );
      return { outcome: 'accepted' };
    }

    const account: Account = {
      id: this.newId(),
      emailIndex,
      email,
      passwordHash,
      emailVerifiedAt: null,
      locale: request.locale,
      createdAt: at,
      updatedAt: at,
    };

    try {
      await this.dependencies.accounts.insert(account);
    } catch (error) {
      // The unique index, not the lookup above, is what actually prevents a
      // duplicate: two requests can pass the lookup before either inserts. The
      // loser answers exactly like the winner.
      if (error instanceof DuplicateAccountError) return { outcome: 'accepted' };
      throw error;
    }

    // The account exists whether or not the mail goes out. Gating creation on
    // the mail budget would let an attacker burn a stranger's allowance and
    // thereby stop them registering at all; leaving the account in place means
    // the worst case is a verification link the user has to ask for again.
    await this.sendIfBudgetAllows(emailIndex, clientKey, 'sign_up', () =>
      this.issueVerification(account, at),
    );
    this.logger.info('account created', { operation: 'sign_up', userId: account.id });
    return { outcome: 'accepted' };
  }

  /**
   * Sends a fresh verification link.
   *
   * Resolves the same way whatever the address is: unknown, known and
   * unverified, known and already verified. Rate limited, because this is the
   * one endpoint whose entire purpose is to send mail on demand.
   */
  async resendVerification(email: string, clientAddress?: string): Promise<void> {
    let normalised: string;
    try {
      normalised = normaliseEmail(email);
    } catch {
      return;
    }
    const emailIndex = this.dependencies.indexer.forEmail(normalised);
    const account = await this.dependencies.accounts.findByEmailIndex(emailIndex);

    // The budget is spent whether or not anything is sent. An address that
    // never costs anything to ask about is an address an attacker can ask about
    // all day, and comparing which ones exhaust their allowance would sort the
    // registered from the unregistered.
    await this.sendIfBudgetAllows(
      emailIndex,
      this.clientKey(clientAddress),
      'resend_verification',
      async () => {
        if (account === null || account.emailVerifiedAt !== null) return;
        await this.issueVerification(account, this.now());
      },
    );
  }

  /** Redeems a verification link (US-011 AC1). */
  async verifyEmail(secret: string): Promise<VerifyEmailResult> {
    const at = this.now();
    const lookup = await lookupToken(
      this.dependencies.tokens,
      secret,
      'email_verification',
      at,
    );
    if (!lookup.valid) return { outcome: 'rejected', reason: lookup.reason };

    const consumed = await this.dependencies.tokens.markConsumed(lookup.record.hash, at);
    if (!consumed) return { outcome: 'rejected', reason: 'ALREADY_USED' };

    const account = await this.dependencies.accounts.findById(lookup.record.accountId);
    if (account === null) return { outcome: 'rejected', reason: 'NOT_FOUND' };

    if (account.emailVerifiedAt === null) {
      await this.dependencies.accounts.update({ ...account, emailVerifiedAt: at, updatedAt: at });
    }
    this.logger.info('email verified', { operation: 'verify_email', userId: account.id });
    return { outcome: 'verified', accountId: account.id };
  }

  /**
   * Verifies a password (US-011 AC3).
   *
   * Order is deliberate: throttle, then look up, then verify. Verifying first
   * would spend 64 MiB and a hundred milliseconds on an attempt the limiter was
   * about to refuse, which is the resource the limiter exists to protect.
   */
  async logIn(request: LoginRequest): Promise<LoginResult> {
    let email: string;
    try {
      email = normaliseEmail(request.email);
    } catch {
      // A malformed address cannot belong to any account, so answering
      // immediately reveals nothing and costs nothing.
      return { outcome: 'rejected', reason: 'INVALID_CREDENTIALS' };
    }

    const emailIndex = this.dependencies.indexer.forEmail(email);
    const clientKey = this.clientKey(request.clientAddress);

    const decision = await this.dependencies.loginThrottle.check(emailIndex, clientKey);
    if (!decision.allowed) {
      this.logger.warn('login refused by throttle', {
        operation: 'login',
        errorCode: decision.scope === 'account' ? 'ACCOUNT_LOCKED' : 'CLIENT_RATE_LIMITED',
        retryAfterMs: decision.retryAfterMs,
      });
      return {
        outcome: 'rejected',
        reason: 'TEMPORARILY_LOCKED',
        retryAfterMs: decision.retryAfterMs,
      };
    }

    const account = await this.dependencies.accounts.findByEmailIndex(emailIndex);
    const password = normalisePassword(request.password);

    if (account === null || account.passwordHash === null) {
      // Equalise the response time. Without this, "no such account" returns in
      // microseconds and every address in a list can be classified in one pass.
      await this.dependencies.hasher.spendVerificationTime();
      await this.dependencies.loginThrottle.recordFailure(emailIndex, clientKey);
      return { outcome: 'rejected', reason: 'INVALID_CREDENTIALS' };
    }

    const correct = await this.dependencies.hasher.verify(password, account.passwordHash);
    if (!correct) {
      await this.dependencies.loginThrottle.recordFailure(emailIndex, clientKey);
      return { outcome: 'rejected', reason: 'INVALID_CREDENTIALS' };
    }

    await this.dependencies.loginThrottle.recordSuccess(emailIndex);
    await this.rehashIfNeeded(account, password);

    return {
      outcome: 'authenticated',
      principal: { accountId: account.id, emailVerified: account.emailVerifiedAt !== null },
    };
  }

  /**
   * Starts a password reset (US-011 AC4).
   *
   * Returns nothing, always, regardless of whether the address is registered or
   * the rate limit was hit. A caller that wants to tell the user something says
   * "if that address has an account, a link is on its way" — which is true in
   * every case.
   */
  async requestPasswordReset(email: string, clientAddress?: string): Promise<void> {
    let normalised: string;
    try {
      normalised = normaliseEmail(email);
    } catch {
      return;
    }

    const emailIndex = this.dependencies.indexer.forEmail(normalised);
    const account = await this.dependencies.accounts.findByEmailIndex(emailIndex);

    // Budget spent for an unknown address too, so asking about one costs the
    // same as asking about a real one.
    await this.sendIfBudgetAllows(
      emailIndex,
      this.clientKey(clientAddress),
      'password_reset_request',
      async () => {
        if (account === null) return;

        const at = this.now();
        // Any earlier link stops working the moment a new one is asked for. Two
        // live reset tokens means a link forwarded, screenshotted or left in a
        // shared inbox stays usable after the user has already reset.
        await this.dependencies.tokens.invalidateAllForAccount(account.id, 'password_reset', at);

        const issued = issueToken(account.id, 'password_reset', PASSWORD_RESET_TTL_MS, at);
        await this.dependencies.tokens.insert(issued.record);
        await this.dependencies.mailer.sendPasswordResetLink(
          { email: account.email, locale: account.locale },
          issued.secret,
        );
        this.logger.info('password reset requested', {
          operation: 'password_reset_request',
          userId: account.id,
        });
      },
    );
  }

  /**
   * Completes a password reset (US-011 AC2, AC4).
   *
   * The token is consumed *before* the password is written, and consumption is
   * a compare-and-set. Two clicks of the same link racing each other must not
   * both succeed — that is the shape of an attack where a stolen link is
   * redeemed alongside the real user's.
   *
   * The new password is checked first, so a rejected password does not burn the
   * user's only link and send them back for another email.
   */
  async resetPassword(request: ResetPasswordRequest): Promise<ResetPasswordResult> {
    const at = this.now();
    const lookup = await lookupToken(this.dependencies.tokens, request.secret, 'password_reset', at);
    if (!lookup.valid) return { outcome: 'rejected', reason: lookup.reason };

    const account = await this.dependencies.accounts.findById(lookup.record.accountId);
    if (account === null) return { outcome: 'rejected', reason: 'NOT_FOUND' };

    const password = normalisePassword(request.password);
    const verdict = await this.dependencies.policy.check(password, { email: account.email });
    if (!verdict.acceptable) {
      return { outcome: 'weak_password', rejections: verdict.rejections };
    }

    const consumed = await this.dependencies.tokens.markConsumed(lookup.record.hash, at);
    if (!consumed) return { outcome: 'rejected', reason: 'ALREADY_USED' };

    await this.dependencies.accounts.update({
      ...account,
      passwordHash: await this.dependencies.hasher.hash(password),
      // Clicking the link proved control of the mailbox, which is the same
      // thing the verification link proves. Making the user do it twice serves
      // nobody.
      emailVerifiedAt: account.emailVerifiedAt ?? at,
      updatedAt: at,
    });

    await this.dependencies.tokens.invalidateAllForAccount(account.id, 'password_reset', at);
    // US-016 AC4. A takeover that ends with the attacker still holding a live
    // session is not over.
    await this.sessions.revokeAllForAccount(account.id);
    // The lockout the attacker (or the user's own forgetfulness) caused is
    // lifted: mailbox control outranks the failed attempts that produced it.
    await this.dependencies.loginThrottle.clear(account.emailIndex);

    await this.dependencies.mailer.sendPasswordChangedNotice({
      email: account.email,
      locale: account.locale,
    });
    this.logger.info('password reset completed', {
      operation: 'password_reset',
      userId: account.id,
    });
    return { outcome: 'reset', accountId: account.id };
  }

  /**
   * Runs [send] if this address still has mail budget, and records the spend.
   *
   * The budget is charged whenever the check passes, including when [send]
   * turns out to have nothing to do. That uniformity is the point: an address
   * that is free to ask about is an address an attacker can ask about all day,
   * and comparing which addresses exhaust their allowance would separate the
   * registered from the unregistered.
   *
   * Returns whether the send ran. **No caller may surface that value**, for the
   * same reason.
   */
  private async sendIfBudgetAllows(
    emailIndex: string,
    clientKey: string | undefined,
    operation: string,
    send: () => Promise<void>,
  ): Promise<boolean> {
    const key = mailKey(emailIndex);
    const allowance = await this.dependencies.mailThrottle.check(key, clientKey);
    if (!allowance.allowed) {
      this.logger.warn('transactional mail suppressed by rate limit', {
        operation,
        errorCode: 'MAIL_RATE_LIMITED',
        retryAfterMs: allowance.retryAfterMs,
      });
      return false;
    }
    await this.dependencies.mailThrottle.consumeAllowance(key, clientKey);
    await send();
    return true;
  }

  private async issueVerification(account: Account, at: Date): Promise<void> {
    await this.dependencies.tokens.invalidateAllForAccount(account.id, 'email_verification', at);
    const issued = issueToken(account.id, 'email_verification', EMAIL_VERIFICATION_TTL_MS, at);
    await this.dependencies.tokens.insert(issued.record);
    await this.dependencies.mailer.sendVerificationLink(
      { email: account.email, locale: account.locale },
      issued.secret,
    );
  }

  /**
   * Re-hashes on login when the stored parameters have fallen behind.
   *
   * This is the only moment the plaintext exists, so it is the only moment the
   * upgrade can happen. A failure here must not fail the login — the user
   * supplied the right password, and the old hash still works.
   */
  private async rehashIfNeeded(account: Account, password: string): Promise<void> {
    if (account.passwordHash === null) return;
    if (!this.dependencies.hasher.needsRehash(account.passwordHash)) return;
    try {
      const at = this.now();
      await this.dependencies.accounts.update({
        ...account,
        passwordHash: await this.dependencies.hasher.hash(password),
        updatedAt: at,
      });
    } catch {
      this.logger.warn('password rehash failed', {
        operation: 'login',
        errorCode: 'REHASH_FAILED',
        userId: account.id,
      });
    }
  }

  private clientKey(clientAddress: string | undefined): string | undefined {
    return clientAddress === undefined
      ? undefined
      : this.dependencies.indexer.forClientAddress(clientAddress);
  }
}

/**
 * Namespaces the mail budget away from the login budget.
 *
 * They share a store. Without the prefix, a burst of password reset requests
 * for an address would count towards that account's login lockout — handing
 * anyone a way to lock a stranger out without guessing a single password.
 */
function mailKey(emailIndex: string): string {
  return `mail:${emailIndex}`;
}
