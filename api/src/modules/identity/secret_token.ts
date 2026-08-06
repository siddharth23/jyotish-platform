/**
 * Single-use secrets sent by email — verification and reset links
 * (US-011 AC1, AC4).
 *
 * ## Stored hashed, never in the clear
 *
 * A live password-reset token *is* the account. Anyone holding one can take it
 * over without knowing the password. So only SHA-256 of the token is stored,
 * and the token itself exists in exactly two places: the email, and the URL the
 * user clicks. A database dump, a backup, a support query or a stray log line
 * then yields nothing usable.
 *
 * Plain SHA-256 is correct here and would be wrong for a password. Stretching
 * exists to compensate for low-entropy inputs; a 256-bit random token has
 * nothing to compensate for, and the lookup happens on every click.
 *
 * ## Expiry and single use are separate properties
 *
 * A token stops working when it expires *or* when it is used. Both are needed:
 * expiry bounds the window on a token sitting in an inbox forever, single use
 * bounds a token that leaked through a browser's history, a referer header, or
 * a forwarded email.
 *
 * LICENSING: no engine code. See docs/AGPL-BOUNDARY.md.
 */

import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';

/** US-011 AC4 — thirty minutes, no longer. */
export const PASSWORD_RESET_TTL_MS = 30 * 60 * 1000;

/**
 * Verification links are given a day.
 *
 * Longer than a reset token because the risk is different: a verification link
 * confirms a mailbox, it does not grant access to an existing account. Shorter
 * than a week because people register on a phone, plan to confirm on a laptop,
 * and a stale link that produces an error is a support ticket.
 */
export const EMAIL_VERIFICATION_TTL_MS = 24 * 60 * 60 * 1000;

/** 256 bits. Guessing is not an attack against this; nothing rate-limits it because nothing needs to. */
const TOKEN_BYTES = 32;

export type TokenPurpose = 'email_verification' | 'password_reset';

/** What the caller gets when a token is issued: the secret to send, and the record to store. */
export interface IssuedToken {
  /** Goes in the email. Never persisted, never logged. */
  readonly secret: string;
  readonly record: TokenRecord;
}

export interface TokenRecord {
  /** SHA-256 of the secret, hex. The primary key. */
  readonly hash: string;
  readonly accountId: string;
  readonly purpose: TokenPurpose;
  readonly createdAt: Date;
  readonly expiresAt: Date;
  /** Set the first time the token is redeemed. */
  readonly consumedAt: Date | null;
}

export interface TokenRepository {
  insert(record: TokenRecord): Promise<void>;
  findByHash(hash: string): Promise<TokenRecord | null>;
  /** Records the redemption. Must be atomic — see [InMemoryTokenRepository]. */
  markConsumed(hash: string, at: Date): Promise<boolean>;
  /** Kills every outstanding token of one purpose for one account. */
  invalidateAllForAccount(accountId: string, purpose: TokenPurpose, at: Date): Promise<void>;
}

/**
 * In-memory implementation.
 *
 * A placeholder, as in `admin/flags/flag_audit.ts`: this service has no database
 * yet. **Replace before launch.** Reset tokens surviving a deploy is not a
 * nicety — a token issued at 14:00 and a release at 14:05 means a user clicks a
 * link that has silently ceased to exist.
 *
 * The persistent implementation must make `markConsumed` atomic — a conditional
 * update on `consumed_at IS NULL`, checking the affected row count. Read-then-
 * write allows two clicks of the same link, milliseconds apart, to both succeed,
 * which is exactly what a token-stealing attacker races for.
 */
export class InMemoryTokenRepository implements TokenRepository {
  private readonly records = new Map<string, TokenRecord>();

  async insert(record: TokenRecord): Promise<void> {
    this.records.set(record.hash, record);
  }

  async findByHash(hash: string): Promise<TokenRecord | null> {
    return this.records.get(hash) ?? null;
  }

  async markConsumed(hash: string, at: Date): Promise<boolean> {
    const record = this.records.get(hash);
    if (record === undefined || record.consumedAt !== null) return false;
    this.records.set(hash, { ...record, consumedAt: at });
    return true;
  }

  async invalidateAllForAccount(
    accountId: string,
    purpose: TokenPurpose,
    at: Date,
  ): Promise<void> {
    for (const [hash, record] of this.records) {
      if (record.accountId === accountId && record.purpose === purpose && record.consumedAt === null) {
        this.records.set(hash, { ...record, consumedAt: at });
      }
    }
  }

  /** Housekeeping the persistent implementation does with a scheduled delete. */
  async deleteExpired(now: Date): Promise<number> {
    let removed = 0;
    for (const [hash, record] of this.records) {
      if (record.expiresAt.getTime() <= now.getTime()) {
        this.records.delete(hash);
        removed += 1;
      }
    }
    return removed;
  }
}

/** SHA-256 of a token secret, hex. */
export function hashToken(secret: string): string {
  return createHash('sha256').update(secret, 'utf8').digest('hex');
}

/**
 * Mints a token and the record to store beside it.
 *
 * base64url so the value survives a URL, an email client's line wrapping and a
 * user copying it out of a plain-text mail.
 */
export function issueToken(
  accountId: string,
  purpose: TokenPurpose,
  ttlMs: number,
  now: Date,
  randomiser: () => Buffer = () => randomBytes(TOKEN_BYTES),
): IssuedToken {
  const secret = randomiser().toString('base64url');
  return {
    secret,
    record: {
      hash: hashToken(secret),
      accountId,
      purpose,
      createdAt: now,
      expiresAt: new Date(now.getTime() + ttlMs),
      consumedAt: null,
    },
  };
}

export type TokenRejection = 'NOT_FOUND' | 'ALREADY_USED' | 'EXPIRED' | 'WRONG_PURPOSE';

export type TokenLookup =
  | { readonly valid: true; readonly record: TokenRecord }
  | { readonly valid: false; readonly reason: TokenRejection };

/**
 * Resolves a secret to its record and checks it is still usable.
 *
 * Does not consume it — the caller does that only once the operation it guards
 * has succeeded, so a rejected new password does not burn the user's only link.
 */
export async function lookupToken(
  repository: TokenRepository,
  secret: string,
  purpose: TokenPurpose,
  now: Date,
): Promise<TokenLookup> {
  const record = await repository.findByHash(hashToken(secret));
  if (record === null) return { valid: false, reason: 'NOT_FOUND' };
  // A verification token must not double as a reset token. Both are random and
  // both are ours; only the recorded purpose keeps "confirm your address" from
  // becoming "change the password".
  if (record.purpose !== purpose) return { valid: false, reason: 'WRONG_PURPOSE' };
  if (record.consumedAt !== null) return { valid: false, reason: 'ALREADY_USED' };
  if (record.expiresAt.getTime() <= now.getTime()) return { valid: false, reason: 'EXPIRED' };
  return { valid: true, record };
}

/**
 * Constant-time comparison of two hex digests.
 *
 * Not needed for the database lookup above — that compares a full-entropy hash
 * by index — but exported for call sites that hold two digests and are tempted
 * to use `===`.
 */
export function digestsEqual(a: string, b: string): boolean {
  const left = Buffer.from(a, 'utf8');
  const right = Buffer.from(b, 'utf8');
  if (left.length !== right.length) return false;
  return timingSafeEqual(left, right);
}
