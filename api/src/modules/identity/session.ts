/**
 * Sessions, access tokens and rotating refresh tokens (US-016).
 *
 * ## The two tokens do different jobs
 *
 * The **access token** is a signed assertion. It is checked with an HMAC and
 * nothing else — no database read, no network hop — because it is presented on
 * every single request and a lookup there would put the session store on the
 * critical path of the whole API.
 *
 * The **refresh token** is a random secret with a row behind it. It is
 * presented rarely, so it can afford a lookup, and that lookup is what makes
 * revocation possible at all.
 *
 * The split is the reason AC1 says *short-lived*. A stateless access token
 * cannot be withdrawn: once signed, it is valid until it expires, and no
 * amount of revoking the session behind it changes that. So the window during
 * which a signed-out device still works is exactly [ACCESS_TOKEN_TTL_MS], and
 * that is the number to argue about — see the note on it below.
 *
 * ## Refresh tokens rotate, and reuse is treated as theft
 *
 * Every refresh mints a new refresh token and retires the one presented. A
 * stolen token therefore works only until the legitimate device refreshes
 * next, which shrinks the value of a theft from "until it expires" to "until
 * the user next opens the app".
 *
 * Rotation alone does not detect anything, though. The detection comes from
 * what happens when an *already retired* token is presented: that is a token
 * which was used twice, and a token can only be used twice if it was copied.
 * Whether the thief or the victim got there first is unknowable and does not
 * matter — the response is to revoke the entire family, forcing a real login.
 * See [SessionStore.refresh] and RFC 9700 §4.14.2.
 *
 * This is why [SessionRecord] carries a `familyId`. Without it, reuse
 * detection can revoke only the single leaked token, and the attacker simply
 * continues from the token they rotated it into.
 *
 * ## Nothing here holds personal data
 *
 * A session record names an account by opaque id and a device by a label the
 * user typed or the OS supplied. No email, no name, no birth data — CLAUDE.md
 * forbids those in logs and telemetry, and a session table is read during
 * exactly the kind of incident where that matters.
 *
 * LICENSING: no engine code. See docs/AGPL-BOUNDARY.md.
 */

import { createHash, createHmac, randomBytes, timingSafeEqual } from 'node:crypto';

import { Logger } from '../../observability/logger.js';

import type { SessionRevocationReason, SessionRevoker } from './identity_service.js';

/**
 * Fifteen minutes.
 *
 * This is the revocation window: the maximum time a device that has been
 * signed out remotely (AC3) or had its password changed under it (AC4) can
 * keep making authenticated requests. It is not a guess at how long a user
 * stays at their desk — the refresh token handles staying logged in, so
 * shortening this costs a background refresh, not a re-login.
 *
 * Shorter would be safer and is tempting. Fifteen minutes is where it lands
 * because every expiry is a refresh round-trip, and on a phone that has just
 * come back from suspend on a bad connection, that round-trip is the thing
 * standing between the user and their chart.
 */
export const ACCESS_TOKEN_TTL_MS = 15 * 60 * 1000;

/**
 * Sixty days of inactivity.
 *
 * Measured from last use, not from login: an app opened weekly should never
 * ask again. Someone who has not opened it in two months is re-authenticating
 * either way, because they have almost certainly changed device.
 */
export const REFRESH_TOKEN_TTL_MS = 60 * 24 * 60 * 60 * 1000;

/**
 * Six months, measured from the login that started the family.
 *
 * The idle TTL above renews on every use, so without this a session that is
 * touched once a month never ends. An absolute cap means a token stolen from
 * a device that was sold, lost, or handed to a family member eventually dies
 * on its own, with no one having to notice.
 */
export const SESSION_ABSOLUTE_TTL_MS = 180 * 24 * 60 * 60 * 1000;

/** 256 bits, as in `secret_token.ts`. Guessing is not the threat model. */
const REFRESH_TOKEN_BYTES = 32;

/** Why a session stopped working. Surfaced to the client; never to another user. */
export type RevocationReason =
  /** The user signed this device out. */
  | 'SIGNED_OUT'
  /** The user signed out everywhere, or an admin did (AC3). */
  | 'SIGNED_OUT_EVERYWHERE'
  /** The password changed, so every prior session dies (AC4). */
  | 'PASSWORD_CHANGED'
  /** A retired refresh token came back. The family is presumed stolen. */
  | 'TOKEN_REUSE_DETECTED';

export interface SessionRecord {
  /** Opaque id. Appears in access tokens, so it must not be guessable-to-useful. */
  readonly id: string;
  readonly accountId: string;
  /**
   * Groups every token this login has rotated through. Reuse detection revokes
   * by family, not by session — see the header.
   */
  readonly familyId: string;
  /** SHA-256 of the current refresh secret, hex. The lookup key. */
  readonly refreshTokenHash: string;
  /**
   * Shown in the device list. User-supplied or OS-supplied, never derived from
   * anything identifying: "Sid's iPhone" is what the OS reports and is fine;
   * an IP address or a raw user agent is not.
   */
  readonly deviceLabel: string;
  readonly createdAt: Date;
  /** When the family started. Fixed across rotations, for the absolute cap. */
  readonly familyStartedAt: Date;
  readonly lastUsedAt: Date;
  /** Set once the token is rotated away. A retired token is the reuse tripwire. */
  readonly rotatedAt: Date | null;
  readonly revokedAt: Date | null;
  readonly revokedReason: RevocationReason | null;
}

export interface SessionRepository {
  insert(record: SessionRecord): Promise<void>;
  findByRefreshTokenHash(hash: string): Promise<SessionRecord | null>;
  findById(id: string): Promise<SessionRecord | null>;
  /**
   * Retires [hash] and stores [replacement] as one unit.
   *
   * Returns false if the token was already retired — which is the reuse signal,
   * so this **must** be atomic. A read-then-write lets two refreshes with the
   * same token both succeed, which is precisely the race a thief runs.
   */
  rotate(hash: string, rotatedAt: Date, replacement: SessionRecord): Promise<boolean>;
  touch(id: string, at: Date): Promise<void>;
  revoke(id: string, at: Date, reason: RevocationReason): Promise<void>;
  revokeFamily(familyId: string, at: Date, reason: RevocationReason): Promise<void>;
  revokeAccount(accountId: string, at: Date, reason: RevocationReason): Promise<void>;
  /** Live sessions for the device list (AC3). Ordered most-recently-used first. */
  listActive(accountId: string, at: Date): Promise<readonly SessionRecord[]>;
}

/**
 * In-memory implementation.
 *
 * A placeholder, as in `secret_token.ts` and `admin/flags/flag_audit.ts`: this
 * service has no database yet. **Replace before launch.** Sessions that do not
 * survive a deploy mean every user is signed out on every release, which turns
 * a routine deploy into a login spike and a support queue.
 *
 * The persistent implementation must keep [rotate] atomic — a conditional
 * `UPDATE ... WHERE rotated_at IS NULL` inside the same transaction as the
 * insert, checking the affected row count. Reuse detection is the security
 * property of this module and it is exactly what a non-atomic rotate loses.
 */
export class InMemorySessionRepository implements SessionRepository {
  private readonly byId = new Map<string, SessionRecord>();
  private readonly idByHash = new Map<string, string>();

  async insert(record: SessionRecord): Promise<void> {
    this.byId.set(record.id, record);
    this.idByHash.set(record.refreshTokenHash, record.id);
  }

  async findByRefreshTokenHash(hash: string): Promise<SessionRecord | null> {
    const id = this.idByHash.get(hash);
    return id === undefined ? null : (this.byId.get(id) ?? null);
  }

  async findById(id: string): Promise<SessionRecord | null> {
    return this.byId.get(id) ?? null;
  }

  async rotate(hash: string, rotatedAt: Date, replacement: SessionRecord): Promise<boolean> {
    const id = this.idByHash.get(hash);
    if (id === undefined) return false;
    const current = this.byId.get(id);
    if (current === undefined || current.rotatedAt !== null) return false;

    this.byId.set(id, { ...current, rotatedAt });
    // The retired hash keeps pointing at the retired row on purpose: that is
    // what lets a replayed token be recognised rather than merely not found.
    this.byId.set(replacement.id, replacement);
    this.idByHash.set(replacement.refreshTokenHash, replacement.id);
    return true;
  }

  async touch(id: string, at: Date): Promise<void> {
    const current = this.byId.get(id);
    if (current !== undefined) this.byId.set(id, { ...current, lastUsedAt: at });
  }

  async revoke(id: string, at: Date, reason: RevocationReason): Promise<void> {
    const current = this.byId.get(id);
    if (current === undefined || current.revokedAt !== null) return;
    this.byId.set(id, { ...current, revokedAt: at, revokedReason: reason });
  }

  async revokeFamily(familyId: string, at: Date, reason: RevocationReason): Promise<void> {
    for (const [id, record] of this.byId) {
      if (record.familyId === familyId && record.revokedAt === null) {
        this.byId.set(id, { ...record, revokedAt: at, revokedReason: reason });
      }
    }
  }

  async revokeAccount(accountId: string, at: Date, reason: RevocationReason): Promise<void> {
    for (const [id, record] of this.byId) {
      if (record.accountId === accountId && record.revokedAt === null) {
        this.byId.set(id, { ...record, revokedAt: at, revokedReason: reason });
      }
    }
  }

  async listActive(accountId: string, at: Date): Promise<readonly SessionRecord[]> {
    return [...this.byId.values()]
      .filter(
        (record) =>
          record.accountId === accountId &&
          // Rotated: superseded by its replacement, which is the row to show.
          record.rotatedAt === null &&
          // Revoked: signed out, password-changed or reuse-revoked. Leaving
          // these in means "sign out everywhere" appears to have done nothing.
          record.revokedAt === null &&
          isLive(record, at) === null,
      )
      .sort((a, b) => b.lastUsedAt.getTime() - a.lastUsedAt.getTime());
  }

  /** Housekeeping the persistent implementation does with a scheduled delete. */
  async deleteExpired(now: Date): Promise<number> {
    let removed = 0;
    for (const [id, record] of this.byId) {
      const dead =
        now.getTime() - record.lastUsedAt.getTime() >= REFRESH_TOKEN_TTL_MS ||
        now.getTime() - record.familyStartedAt.getTime() >= SESSION_ABSOLUTE_TTL_MS;
      if (dead) {
        this.byId.delete(id);
        this.idByHash.delete(record.refreshTokenHash);
        removed += 1;
      }
    }
    return removed;
  }
}

/** SHA-256 of a refresh secret, hex. Same reasoning as `secret_token.ts`. */
export function hashRefreshToken(secret: string): string {
  return createHash('sha256').update(secret, 'utf8').digest('hex');
}

export interface AccessTokenClaims {
  readonly accountId: string;
  readonly sessionId: string;
  readonly emailVerified: boolean;
  readonly expiresAt: Date;
}

export type AccessTokenRejection =
  | 'MALFORMED'
  | 'BAD_SIGNATURE'
  | 'EXPIRED';

export type AccessTokenVerdict =
  | { readonly valid: true; readonly claims: AccessTokenClaims }
  | { readonly valid: false; readonly reason: AccessTokenRejection };

/**
 * Mints and checks access tokens.
 *
 * Deliberately not JWT. JWT's header carries the algorithm, and honouring an
 * attacker-supplied `alg` is the single most repeated authentication bug of
 * the last decade — `none` and RS256-verified-as-HS256 both come from taking
 * that field seriously. Here the algorithm is a constant in this file and the
 * token has nowhere to say otherwise. We gain nothing from JWT because no
 * third party consumes these tokens.
 *
 * The payload is signed, not encrypted: anyone holding a token can read the
 * account id inside it. That is fine — it is an opaque id, and whoever holds
 * the token can call the API as that account anyway.
 */
export class AccessTokenIssuer {
  private readonly key: Buffer;

  /**
   * @param signingKey At least 32 bytes of secret. Rotating it invalidates
   *   every outstanding access token, which is the break-glass control for a
   *   suspected key compromise: within [ACCESS_TOKEN_TTL_MS] every client is
   *   forced through refresh, where the session store gets its say.
   */
  constructor(signingKey: Buffer | string) {
    const key = typeof signingKey === 'string' ? Buffer.from(signingKey, 'utf8') : signingKey;
    if (key.length < 32) {
      throw new Error('Access token signing key must be at least 32 bytes.');
    }
    this.key = key;
  }

  issue(claims: AccessTokenClaims): string {
    const payload = base64UrlEncode(
      Buffer.from(
        JSON.stringify({
          sub: claims.accountId,
          sid: claims.sessionId,
          ver: claims.emailVerified,
          exp: claims.expiresAt.getTime(),
        }),
        'utf8',
      ),
    );
    return `${payload}.${this.sign(payload)}`;
  }

  verify(token: string, at: Date): AccessTokenVerdict {
    const separator = token.lastIndexOf('.');
    if (separator <= 0 || separator === token.length - 1) {
      return { valid: false, reason: 'MALFORMED' };
    }
    const payload = token.slice(0, separator);
    const signature = token.slice(separator + 1);

    // Signature first, always. Parsing attacker-controlled JSON before proving
    // it is ours means the parser is reachable by anyone with a URL.
    if (!this.signatureMatches(payload, signature)) {
      return { valid: false, reason: 'BAD_SIGNATURE' };
    }

    const claims = decodeClaims(payload);
    if (claims === null) return { valid: false, reason: 'MALFORMED' };
    if (claims.expiresAt.getTime() <= at.getTime()) {
      return { valid: false, reason: 'EXPIRED' };
    }
    return { valid: true, claims };
  }

  private sign(payload: string): string {
    return base64UrlEncode(createHmac('sha256', this.key).update(payload, 'utf8').digest());
  }

  private signatureMatches(payload: string, candidate: string): boolean {
    const expected = Buffer.from(this.sign(payload), 'utf8');
    const actual = Buffer.from(candidate, 'utf8');
    // timingSafeEqual throws on a length mismatch, which would itself leak the
    // expected length through an exception. Check first.
    if (expected.length !== actual.length) return false;
    return timingSafeEqual(expected, actual);
  }
}

export interface IssuedSession {
  readonly accessToken: string;
  readonly accessTokenExpiresAt: Date;
  /** Shown to the client once. Only its hash is stored. */
  readonly refreshToken: string;
  readonly refreshTokenExpiresAt: Date;
  readonly sessionId: string;
}

export type RefreshRejection =
  /** No live session holds this token. Also covers a token from a wiped store. */
  | 'UNKNOWN'
  /** Idle timeout or the absolute cap. */
  | 'EXPIRED'
  /** Revoked by sign-out, password change, or reuse detection. */
  | 'REVOKED'
  /** A retired token came back. The family has just been revoked. */
  | 'REUSED';

export type RefreshResult =
  | { readonly outcome: 'refreshed'; readonly session: IssuedSession }
  | { readonly outcome: 'rejected'; readonly reason: RefreshRejection };

export interface SessionPrincipal {
  readonly accountId: string;
  readonly emailVerified: boolean;
}

/**
 * Re-reads who an account currently is, during refresh.
 *
 * Two things depend on this. The obvious one is that verification state can
 * change mid-session and the access token should catch up without forcing a
 * login. The load-bearing one is that returning null ends the session: an
 * account that has been deleted (US-015) or disabled must stop refreshing, and
 * refresh is the only moment this module ever gets to ask.
 */
export type PrincipalResolver = (accountId: string) => Promise<SessionPrincipal | null>;

export interface SessionStoreDependencies {
  readonly sessions: SessionRepository;
  readonly issuer: AccessTokenIssuer;
  /**
   * Optional only so tests and callers that have no account repository to hand
   * can still exercise rotation. Omitting it in production means a deleted
   * account keeps refreshing until its tokens expire — wire it up.
   */
  readonly resolvePrincipal?: PrincipalResolver;
  readonly logger?: Logger;
  readonly now?: () => Date;
  readonly newId?: () => string;
}

/**
 * Issues, refreshes and revokes sessions.
 *
 * Implements [SessionRevoker], which `IdentityService` already calls on a
 * completed password reset — AC4 needed no new call site, only a real
 * implementation behind the seam US-011 left.
 */
export class SessionStore implements SessionRevoker {
  private readonly sessions: SessionRepository;
  private readonly issuer: AccessTokenIssuer;
  private readonly resolvePrincipal: PrincipalResolver | null;
  private readonly logger: Logger;
  private readonly now: () => Date;
  private readonly newId: () => string;

  constructor(dependencies: SessionStoreDependencies) {
    this.sessions = dependencies.sessions;
    this.issuer = dependencies.issuer;
    this.resolvePrincipal = dependencies.resolvePrincipal ?? null;
    this.logger = dependencies.logger ?? new Logger();
    this.now = dependencies.now ?? ((): Date => new Date());
    this.newId = dependencies.newId ?? ((): string => crypto.randomUUID());
  }

  /** Starts a session. Called after `IdentityService.logIn` authenticates. */
  async start(principal: SessionPrincipal, deviceLabel: string): Promise<IssuedSession> {
    const at = this.now();
    const familyId = this.newId();
    const record = this.mint(principal.accountId, familyId, at, at, deviceLabel);
    await this.sessions.insert(record.record);
    this.logger.info('session started', {
      operation: 'session_start',
      userId: principal.accountId,
      sessionId: record.record.id,
    });
    return this.issued(record, principal.emailVerified, at);
  }

  /**
   * Exchanges a refresh token for a new pair.
   *
   * The order of checks matters. Reuse is tested before expiry and before
   * revocation, because a replayed token proves a leak regardless of whether
   * the session it belongs to has since died, and the family revocation is
   * worth performing either way.
   */
  async refresh(refreshToken: string): Promise<RefreshResult> {
    const at = this.now();
    const hash = hashRefreshToken(refreshToken);
    const existing = await this.sessions.findByRefreshTokenHash(hash);
    if (existing === null) return { outcome: 'rejected', reason: 'UNKNOWN' };

    if (existing.rotatedAt !== null) {
      // Presented twice. One of the two holders is not the user, and there is
      // no way to tell which — so neither keeps access. See RFC 9700 §4.14.2.
      await this.sessions.revokeFamily(existing.familyId, at, 'TOKEN_REUSE_DETECTED');
      this.logger.warn('refresh token reuse detected', {
        operation: 'session_refresh',
        userId: existing.accountId,
        sessionId: existing.id,
        familyId: existing.familyId,
      });
      return { outcome: 'rejected', reason: 'REUSED' };
    }

    if (existing.revokedAt !== null) return { outcome: 'rejected', reason: 'REVOKED' };

    if (isLive(existing, at) !== null) {
      await this.sessions.revoke(existing.id, at, 'SIGNED_OUT');
      return { outcome: 'rejected', reason: 'EXPIRED' };
    }

    // The account gets a say before a new token is minted: deleted, disabled or
    // newly verified are all decided here. See [PrincipalResolver].
    let principal: SessionPrincipal = { accountId: existing.accountId, emailVerified: false };
    if (this.resolvePrincipal !== null) {
      const current = await this.resolvePrincipal(existing.accountId);
      if (current === null) {
        await this.sessions.revokeAccount(existing.accountId, at, 'SIGNED_OUT_EVERYWHERE');
        return { outcome: 'rejected', reason: 'REVOKED' };
      }
      principal = current;
    }

    const replacement = this.mint(
      existing.accountId,
      existing.familyId,
      existing.familyStartedAt,
      at,
      existing.deviceLabel,
    );
    const rotated = await this.sessions.rotate(hash, at, replacement.record);
    if (!rotated) {
      // Lost a race with a concurrent refresh of the same token. The winner
      // rotated it; from here this is indistinguishable from reuse, and it is
      // safer to treat it as such than to hand out a second live token.
      await this.sessions.revokeFamily(existing.familyId, at, 'TOKEN_REUSE_DETECTED');
      return { outcome: 'rejected', reason: 'REUSED' };
    }

    return {
      outcome: 'refreshed',
      session: this.issued(replacement, principal.emailVerified, at),
    };
  }

  /** Signs one device out. */
  async revokeSession(sessionId: string): Promise<void> {
    await this.sessions.revoke(sessionId, this.now(), 'SIGNED_OUT');
  }

  /**
   * Tears down every session for an account — AC3 when the user asks, AC4 when
   * `IdentityService` completes a password reset.
   *
   * The reason is recorded rather than inferred: in an incident, "the user
   * signed out" and "the password was reset out from under a live session"
   * are the two readings you need to tell apart.
   */
  async revokeAllForAccount(
    accountId: string,
    reason: SessionRevocationReason = 'SIGNED_OUT_EVERYWHERE',
  ): Promise<void> {
    await this.sessions.revokeAccount(accountId, this.now(), reason);
    this.logger.info('all sessions revoked', {
      operation: 'session_revoke_all',
      userId: accountId,
      revocationReason: reason,
    });
  }

  /** The device list behind AC3. */
  async listDevices(accountId: string): Promise<readonly SessionRecord[]> {
    return this.sessions.listActive(accountId, this.now());
  }

  /** Checks an access token. No store read — see the header. */
  verifyAccessToken(token: string): AccessTokenVerdict {
    return this.issuer.verify(token, this.now());
  }

  private mint(
    accountId: string,
    familyId: string,
    familyStartedAt: Date,
    at: Date,
    deviceLabel: string,
  ): MintedSession {
    const secret = base64UrlEncode(randomBytes(REFRESH_TOKEN_BYTES));
    return {
      secret,
      record: {
        id: this.newId(),
        accountId,
        familyId,
        refreshTokenHash: hashRefreshToken(secret),
        deviceLabel,
        createdAt: at,
        familyStartedAt,
        lastUsedAt: at,
        rotatedAt: null,
        revokedAt: null,
        revokedReason: null,
      },
    };
  }

  private issued(minted: MintedSession, emailVerified: boolean, at: Date): IssuedSession {
    const accessTokenExpiresAt = new Date(at.getTime() + ACCESS_TOKEN_TTL_MS);
    return {
      accessToken: this.issuer.issue({
        accountId: minted.record.accountId,
        sessionId: minted.record.id,
        emailVerified,
        expiresAt: accessTokenExpiresAt,
      }),
      accessTokenExpiresAt,
      refreshToken: minted.secret,
      refreshTokenExpiresAt: refreshExpiryOf(minted.record),
      sessionId: minted.record.id,
    };
  }
}

interface MintedSession {
  readonly secret: string;
  readonly record: SessionRecord;
}

/**
 * Returns null while [record] is still within both TTLs, or which one lapsed.
 *
 * Two clocks, both required: idle expiry renews on use, the absolute cap does
 * not. See the constants.
 */
function isLive(record: SessionRecord, at: Date): 'IDLE' | 'ABSOLUTE' | null {
  if (at.getTime() - record.lastUsedAt.getTime() >= REFRESH_TOKEN_TTL_MS) return 'IDLE';
  if (at.getTime() - record.familyStartedAt.getTime() >= SESSION_ABSOLUTE_TTL_MS) {
    return 'ABSOLUTE';
  }
  return null;
}

/** The earlier of the two deadlines — the one that will actually end the session. */
function refreshExpiryOf(record: SessionRecord): Date {
  const idle = record.lastUsedAt.getTime() + REFRESH_TOKEN_TTL_MS;
  const absolute = record.familyStartedAt.getTime() + SESSION_ABSOLUTE_TTL_MS;
  return new Date(Math.min(idle, absolute));
}

function decodeClaims(payload: string): AccessTokenClaims | null {
  try {
    const raw: unknown = JSON.parse(base64UrlDecode(payload).toString('utf8'));
    if (typeof raw !== 'object' || raw === null) return null;
    const { sub, sid, ver, exp } = raw as Record<string, unknown>;
    if (typeof sub !== 'string' || typeof sid !== 'string' || typeof exp !== 'number') {
      return null;
    }
    return {
      accountId: sub,
      sessionId: sid,
      emailVerified: ver === true,
      expiresAt: new Date(exp),
    };
  } catch {
    return null;
  }
}

function base64UrlEncode(buffer: Buffer): string {
  return buffer.toString('base64url');
}

function base64UrlDecode(value: string): Buffer {
  return Buffer.from(value, 'base64url');
}
