/**
 * Rate limiting and account lockout (US-011 AC3).
 *
 * Two counters, both keyed on blind indexes (see `email_index.ts`) so no
 * address and no client IP is written to the throttle store in the clear:
 *
 * - **Per account** — ten failures inside the window locks that account for the
 *   lockout period. This is the acceptance criterion.
 * - **Per client address** — a much larger budget over the same window. This is
 *   the one that actually stops credential stuffing, where an attacker tries
 *   one password against ten thousand different addresses and never trips a
 *   single per-account counter.
 *
 * Neither is the first line of defence. The architecture puts a WAF and a rate
 * limiter at the CDN, which sheds volume before it reaches a process holding a
 * database connection. This is defence in depth, and it is also what makes the
 * password hasher affordable: scrypt at 64 MiB per verification is a memory
 * exhaustion primitive if anything unauthenticated can call it in a loop.
 *
 * ## Lockout is a denial-of-service primitive, and that is accepted knowingly
 *
 * Anyone who knows an address can lock that account by failing ten times. There
 * is no version of "lock after N failures" that does not have this property.
 * What is controlled is the blast radius:
 *
 * - The lock **expires**. It is never an administrative unlock, which would
 *   turn a nuisance into a support queue and a per-user outage.
 * - The counter resets when the lock expires, so a legitimate user who mistypes
 *   once afterwards is not instantly re-locked.
 * - A successful password reset clears it, because proving control of the
 *   mailbox is stronger evidence than the failures were.
 *
 * The residue is that a determined attacker sustains ten guesses per fifteen
 * minutes against one account — about 960 a day. That is absorbed by the breach
 * list check at sign-up, which is what stops the password being in the first
 * thousand an attacker would try.
 *
 * ## Fixed window, not sliding
 *
 * A fixed window lets an attacker fire the limit at the end of one window and
 * again at the start of the next, so the true short-term ceiling is double the
 * configured limit. A sliding window would need every attempt timestamp stored
 * per key. The doubling is uninteresting at these limits, and the fixed window
 * is one integer and one expiry — which is what makes it correct under the
 * Redis implementation that will replace the one below.
 *
 * LICENSING: no engine code. See docs/AGPL-BOUNDARY.md.
 */

/** US-011 AC3. */
export const MAX_ACCOUNT_FAILURES = 10;
export const ACCOUNT_WINDOW_MS = 15 * 60 * 1000;
export const ACCOUNT_LOCKOUT_MS = 15 * 60 * 1000;

/**
 * Generous on purpose. Carrier-grade NAT and corporate networks put thousands
 * of unrelated people behind one address; a tight per-IP limit locks out a
 * whole office because one person forgot their password.
 */
export const MAX_CLIENT_FAILURES = 50;
export const CLIENT_WINDOW_MS = 15 * 60 * 1000;
export const CLIENT_LOCKOUT_MS = 15 * 60 * 1000;

/**
 * Limits for the second instance of this class, the one metering outbound mail.
 *
 * An hour rather than fifteen minutes, and far tighter counts. Sign-up and
 * password reset send a message to whatever address is typed, so without a
 * budget they are a mail cannon aimed at a stranger — and the bounces and spam
 * reports land on the sending domain's reputation, which is what the €11
 * report has to be delivered through.
 *
 * Five per address per hour still covers a real person clicking "resend"
 * because nothing arrived.
 */
export const MAIL_THROTTLE_LIMITS = {
  account: { maxFailures: 5, windowMs: 60 * 60 * 1000, lockoutMs: 60 * 60 * 1000 },
  client: { maxFailures: 20, windowMs: 60 * 60 * 1000, lockoutMs: 60 * 60 * 1000 },
} as const;

/** Epoch milliseconds throughout: what a Redis hash can hold without a codec. */
export interface AttemptRecord {
  readonly failures: number;
  /** Start of the current counting window. */
  readonly windowStartedAt: number;
  readonly lockedUntil: number | null;
}

export interface ThrottleStore {
  read(key: string): Promise<AttemptRecord | null>;
  /** [ttlMs] is a hint; the store may expire the key once it elapses. */
  write(key: string, record: AttemptRecord, ttlMs: number): Promise<void>;
  delete(key: string): Promise<void>;
}

/**
 * In-memory implementation.
 *
 * A placeholder. **It is wrong the moment there is more than one application
 * instance**, because each process would keep its own counters and the
 * effective limit would multiply by the instance count. Redis, shared across
 * instances, is the intended store — the interface above is deliberately
 * expressible as `HGETALL` / `HSET` + `PEXPIRE` / `DEL`.
 */
export class InMemoryThrottleStore implements ThrottleStore {
  private readonly records = new Map<string, { record: AttemptRecord; expiresAt: number }>();

  async read(key: string): Promise<AttemptRecord | null> {
    const entry = this.records.get(key);
    if (entry === undefined) return null;
    if (Date.now() >= entry.expiresAt) {
      this.records.delete(key);
      return null;
    }
    return entry.record;
  }

  async write(key: string, record: AttemptRecord, ttlMs: number): Promise<void> {
    this.records.set(key, { record, expiresAt: Date.now() + ttlMs });
  }

  async delete(key: string): Promise<void> {
    this.records.delete(key);
  }
}

export interface ThrottleLimits {
  readonly maxFailures: number;
  readonly windowMs: number;
  readonly lockoutMs: number;
}

export interface LoginThrottleOptions {
  readonly account?: ThrottleLimits;
  readonly client?: ThrottleLimits;
}

/** Which limit refused the attempt. Never returned to the client verbatim. */
export type ThrottleScope = 'account' | 'client';

export type ThrottleDecision =
  | { readonly allowed: true }
  | { readonly allowed: false; readonly scope: ThrottleScope; readonly retryAfterMs: number };

/**
 * Counts failures and locks out.
 *
 * Keys are opaque: the caller passes blind indexes, and this class never sees
 * an address or an IP.
 */
export class LoginThrottle {
  private readonly accountLimits: ThrottleLimits;
  private readonly clientLimits: ThrottleLimits;

  constructor(
    private readonly store: ThrottleStore,
    options: LoginThrottleOptions = {},
    private readonly now: () => Date = () => new Date(),
  ) {
    this.accountLimits = options.account ?? {
      maxFailures: MAX_ACCOUNT_FAILURES,
      windowMs: ACCOUNT_WINDOW_MS,
      lockoutMs: ACCOUNT_LOCKOUT_MS,
    };
    this.clientLimits = options.client ?? {
      maxFailures: MAX_CLIENT_FAILURES,
      windowMs: CLIENT_WINDOW_MS,
      lockoutMs: CLIENT_LOCKOUT_MS,
    };
  }

  /**
   * Whether an attempt may proceed.
   *
   * Must be called **before** the password is verified. Checking afterwards
   * spends the scrypt work first, which is the resource the limit is protecting.
   *
   * [clientKey] is optional so a caller behind an edge that does not forward a
   * trustworthy client address degrades to per-account limiting only, rather
   * than limiting everyone against one shared key.
   */
  async check(accountKey: string, clientKey?: string): Promise<ThrottleDecision> {
    const at = this.now().getTime();

    if (clientKey !== undefined) {
      const clientLock = lockedUntil(await this.store.read(clientKey), at);
      if (clientLock !== null) {
        return { allowed: false, scope: 'client', retryAfterMs: clientLock - at };
      }
    }
    const accountLock = lockedUntil(await this.store.read(accountKey), at);
    if (accountLock !== null) {
      return { allowed: false, scope: 'account', retryAfterMs: accountLock - at };
    }
    return { allowed: true };
  }

  /**
   * Counts a failed attempt against both keys.
   *
   * Called for an address with no account too. If failures were only counted
   * for accounts that exist, an attacker could tell the two apart by watching
   * which addresses eventually lock — the enumeration oracle removed everywhere
   * else in this module would come straight back in through the throttle.
   */
  async recordFailure(accountKey: string, clientKey?: string): Promise<void> {
    await this.consumeAllowance(accountKey, clientKey);
  }

  /**
   * The same increment under the name that fits a non-login budget.
   *
   * The second instance of this class meters outbound mail, where the thing
   * being counted is a *successful* send, not a failure. Same arithmetic,
   * opposite meaning, so it gets its own name rather than call sites that read
   * as though sending an email were an error.
   */
  async consumeAllowance(key: string, clientKey?: string): Promise<void> {
    await this.increment(key, this.accountLimits);
    if (clientKey !== undefined) await this.increment(clientKey, this.clientLimits);
  }

  /**
   * Clears the account counter after a correct password.
   *
   * The client counter is deliberately left alone. Clearing it would let an
   * attacker holding one valid account of their own reset their address's
   * budget between batches of guesses and stuff credentials indefinitely.
   */
  async recordSuccess(accountKey: string): Promise<void> {
    await this.store.delete(accountKey);
  }

  /** Lifts a lock outright — for a completed password reset. */
  async clear(accountKey: string): Promise<void> {
    await this.store.delete(accountKey);
  }

  private async increment(key: string, limits: ThrottleLimits): Promise<void> {
    const at = this.now().getTime();
    const existing = await this.store.read(key);

    const withinWindow =
      existing !== null && at - existing.windowStartedAt < limits.windowMs && existing.lockedUntil === null;

    const failures = withinWindow ? existing.failures + 1 : 1;
    const windowStartedAt = withinWindow ? existing.windowStartedAt : at;
    const locked = failures >= limits.maxFailures;

    const record: AttemptRecord = {
      failures: locked ? 0 : failures,
      // Resetting the counter as the lock is set is what gives a returning user
      // a fresh allowance when it expires, instead of one attempt before being
      // locked out again.
      windowStartedAt: locked ? at + limits.lockoutMs : windowStartedAt,
      lockedUntil: locked ? at + limits.lockoutMs : null,
    };

    await this.store.write(key, record, limits.windowMs + limits.lockoutMs);
  }
}

/** The lock expiry still in force, or null. */
function lockedUntil(record: AttemptRecord | null, at: number): number | null {
  if (record?.lockedUntil == null) return null;
  return record.lockedUntil > at ? record.lockedUntil : null;
}
