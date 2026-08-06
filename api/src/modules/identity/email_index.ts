/**
 * Blind index for looking up accounts by email (US-011).
 *
 * ## The problem this solves
 *
 * An email address is personal data and `docs/SECURITY.md` requires field-level
 * encryption at rest. But a login has to find one row out of many *by* the
 * address, and a properly encrypted column cannot be searched — that is what
 * makes it properly encrypted.
 *
 * The answer is a deterministic keyed hash stored alongside the ciphertext.
 * `HMAC-SHA-256(pepper, "email:" + address)` is stable, so it can be a unique
 * index, and it is keyed, so it cannot be brute-forced from the database alone.
 * An unkeyed SHA-256 would be useless here: the space of plausible email
 * addresses is small enough that a leaked column of bare hashes is a leaked
 * column of addresses.
 *
 * **The pepper must live outside the database** — a secret store, injected as
 * configuration. Storing it next to the data it protects reduces this to the
 * bare-hash case.
 *
 * Rotating it means recomputing every index from the decrypted addresses, which
 * is possible precisely because the addresses are recoverable. That is the
 * difference between this and a password pepper (see `password_hasher.ts`).
 *
 * ## Also used for throttle keys
 *
 * The rate limiter keys on these values rather than on addresses or IPs. It
 * usually runs in Redis, which is a second store with its own backups and its
 * own `MONITOR` command; putting plaintext addresses and client IPs in there
 * would quietly create a second copy of the user list.
 *
 * LICENSING: no engine code. See docs/AGPL-BOUNDARY.md.
 */

import { createHmac } from 'node:crypto';

/**
 * Below this the pepper is not a secret, it is a formality. 32 characters of
 * random base64 is 24 bytes of entropy.
 */
const MINIMUM_PEPPER_LENGTH = 32;

export class EmailIndexer {
  constructor(private readonly pepper: string) {
    if (pepper.length < MINIMUM_PEPPER_LENGTH) {
      throw new Error(
        `The blind-index pepper must be at least ${MINIMUM_PEPPER_LENGTH} characters. ` +
          'Generate one with `openssl rand -base64 48` and store it in the secret store.',
      );
    }
  }

  /** Lookup key for an address that has already been through `normaliseEmail`. */
  forEmail(normalisedEmail: string): string {
    return this.compute('email', normalisedEmail);
  }

  /**
   * Throttle key for a client address.
   *
   * The caller decides what "client address" means — behind a CDN it is a
   * header, and trusting the wrong one hands an attacker an unlimited supply of
   * distinct keys. That decision belongs at the edge, not here.
   */
  forClientAddress(clientAddress: string): string {
    return this.compute('ip', clientAddress.trim().toLowerCase());
  }

  /**
   * The domain tag is not decoration. Without it the index for the address
   * `1.2.3.4` and the index for the client address `1.2.3.4` would collide, and
   * one user's failed logins would count against an unrelated network.
   */
  private compute(domain: 'email' | 'ip', value: string): string {
    return createHmac('sha256', this.pepper).update(`${domain}:${value}`, 'utf8').digest('hex');
  }
}
