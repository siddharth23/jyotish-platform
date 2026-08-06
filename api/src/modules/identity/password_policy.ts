/**
 * Password rules and the breach-list check (US-011 AC2).
 *
 * The policy follows NIST SP 800-63B: length and a blocklist, no composition
 * rules. There is deliberately no "must contain an uppercase letter and a
 * symbol" requirement. Those rules do not produce unpredictable passwords —
 * they produce `Passwort1!`, which is in every cracking dictionary — and they
 * push people towards reuse, which is the failure this check actually exists to
 * catch.
 *
 * Rejections are returned as codes. No German prose lives in this file: UI
 * strings are ICU resources on the client (CLAUDE.md, "no hardcoded UI
 * strings"), and the same code has to render differently in a sign-up form and
 * in a password-reset form anyway.
 *
 * LICENSING: no engine code. See docs/AGPL-BOUNDARY.md.
 */

import { createHash } from 'node:crypto';

/** US-011 AC2. Ten, not eight: the story says ten and NIST's floor is eight. */
export const MINIMUM_PASSWORD_LENGTH = 10;

/**
 * An upper bound, not a security control.
 *
 * NIST asks for at least 64 characters to be accepted, so passphrases and
 * password-manager output work. The cap exists only so an unbounded string
 * cannot be pushed through the key derivation function; 256 is far past any
 * real passphrase.
 */
export const MAXIMUM_PASSWORD_LENGTH = 256;

export type PasswordRejection =
  | 'TOO_SHORT'
  | 'TOO_LONG'
  | 'BREACHED'
  | 'REPETITIVE'
  | 'CONTAINS_EMAIL'
  | 'CONTAINS_SERVICE_TERM'
  | 'BREACH_CHECK_UNAVAILABLE';

export interface PasswordVerdict {
  readonly acceptable: boolean;
  /** Every failed rule, so a form can show them all at once. */
  readonly rejections: readonly PasswordRejection[];
}

/**
 * Unicode-normalises a password.
 *
 * NFKC, applied once, before both the policy check and hashing. A password
 * typed with a composed `ü` on a Mac and a decomposed `ü` on Android is the
 * same password to the person typing it; without normalisation the second
 * device produces a different byte string and a failed login nobody can
 * explain.
 *
 * Not trimmed. A leading or trailing space is part of the password — silently
 * removing it means a password manager's value and a typed value diverge.
 */
export function normalisePassword(raw: string): string {
  return raw.normalize('NFKC');
}

/**
 * Length in code points.
 *
 * `String.length` counts UTF-16 units, so an emoji would count as two and a
 * five-emoji password would pass a ten-character minimum. Code points are what
 * the person typing believes they entered.
 */
export function passwordLength(password: string): number {
  return [...password].length;
}

/**
 * A source of known-breached passwords, queried by hash prefix.
 *
 * The interface takes a **prefix** and returns the matching suffixes rather
 * than taking a password and returning a boolean. That shape is the point: it
 * makes k-anonymity the only natural way to implement a remote list. An
 * implementation that sent the whole password, or the whole hash, to a third
 * party would have to fight this signature to do it.
 *
 * Hashes are SHA-1, uppercase hex, split 5 + 35 — the format Have I Been
 * Pwned's range API uses, so a remote implementation is a thin wrapper. SHA-1's
 * collision weakness is irrelevant here: this is a lookup key into a public
 * corpus, not a credential store.
 *
 * A remote list is an outbound call to a processor. Before one is wired up it
 * needs the DPA question answered (CLAUDE.md: "No processor without a signed
 * DPA") even though only five hex characters leave the building. The local
 * implementation below avoids that question entirely and is the default.
 */
export interface BreachList {
  /** Suffixes (35 uppercase hex characters) whose hash begins with [prefix]. */
  suffixesFor(prefix: string): Promise<ReadonlySet<string>>;
}

/** SHA-1 of the password's UTF-8 bytes, uppercase hex. */
export function breachHash(password: string): string {
  return createHash('sha1').update(password, 'utf8').digest('hex').toUpperCase();
}

/**
 * A list held in this process, built from plaintext or from hashes.
 *
 * Suitable for the top few hundred thousand passwords loaded from a file at
 * boot. The full HIBP corpus is around a billion entries and does not belong in
 * process memory; that is what a remote or on-disk implementation is for.
 */
export class InMemoryBreachList implements BreachList {
  private readonly byPrefix = new Map<string, Set<string>>();

  /** @param hashes Full SHA-1 hashes, any case. */
  constructor(hashes: Iterable<string> = []) {
    for (const hash of hashes) this.addHash(hash);
  }

  /** Builds a list from plaintext passwords — for tests and seed data. */
  static fromPasswords(passwords: Iterable<string>): InMemoryBreachList {
    const list = new InMemoryBreachList();
    for (const password of passwords) list.addHash(breachHash(normalisePassword(password)));
    return list;
  }

  addHash(hash: string): void {
    const upper = hash.trim().toUpperCase();
    if (!/^[0-9A-F]{40}$/.test(upper)) return;
    const prefix = upper.slice(0, 5);
    const suffix = upper.slice(5);
    const bucket = this.byPrefix.get(prefix);
    if (bucket === undefined) this.byPrefix.set(prefix, new Set([suffix]));
    else bucket.add(suffix);
  }

  async suffixesFor(prefix: string): Promise<ReadonlySet<string>> {
    return this.byPrefix.get(prefix.toUpperCase()) ?? new Set<string>();
  }
}

/**
 * What to do when the breach list cannot answer.
 *
 * `reject` is the default. Accepting an unchecked password degrades the control
 * exactly when it is most likely to be under load, and the resulting weak
 * password is permanent — the outage ends, the password does not. The cost is
 * that a list outage blocks sign-ups, which is visible, alarming and fixed
 * quickly. That is the better failure.
 */
export type BreachCheckFallback = 'reject' | 'accept';

export interface PasswordPolicyOptions {
  readonly whenBreachListUnavailable?: BreachCheckFallback;
  /** Product words that must not form the password. Lowercase. */
  readonly serviceTerms?: readonly string[];
}

const DEFAULT_SERVICE_TERMS = ['jyotish', 'kundali', 'horoskop', 'astro', 'passwort', 'password'];

export interface PasswordContext {
  /** The account's normalised email, if known at check time. */
  readonly email?: string;
}

export class PasswordPolicy {
  private readonly fallback: BreachCheckFallback;
  private readonly serviceTerms: readonly string[];

  constructor(
    private readonly breachList: BreachList,
    options: PasswordPolicyOptions = {},
  ) {
    this.fallback = options.whenBreachListUnavailable ?? 'reject';
    this.serviceTerms = options.serviceTerms ?? DEFAULT_SERVICE_TERMS;
  }

  /**
   * Checks a password, collecting every reason it fails.
   *
   * Takes the raw password and normalises internally so no caller can check one
   * string and hash another.
   */
  async check(raw: string, context: PasswordContext = {}): Promise<PasswordVerdict> {
    const password = normalisePassword(raw);
    const rejections: PasswordRejection[] = [];
    const length = passwordLength(password);

    if (length < MINIMUM_PASSWORD_LENGTH) rejections.push('TOO_SHORT');
    if (length > MAXIMUM_PASSWORD_LENGTH) rejections.push('TOO_LONG');

    // NIST names repetitive and sequential characters as blocklist material.
    // `aaaaaaaaaa` and `abcdefghij` clear a ten-character minimum and are the
    // first two things a cracker tries.
    if (length >= MINIMUM_PASSWORD_LENGTH && isRepetitiveOrSequential(password)) {
      rejections.push('REPETITIVE');
    }

    const folded = password.toLowerCase();
    if (this.serviceTerms.some((term) => folded.includes(term))) {
      rejections.push('CONTAINS_SERVICE_TERM');
    }
    if (containsEmailFragment(folded, context.email)) {
      rejections.push('CONTAINS_EMAIL');
    }

    // Skipped when the password is already too long: pushing 100kB through the
    // hash and the lookup to tell someone something they have already been told
    // is free work for an attacker.
    if (!rejections.includes('TOO_LONG')) {
      const breached = await this.isBreached(password);
      if (breached === 'yes') rejections.push('BREACHED');
      if (breached === 'unknown' && this.fallback === 'reject') {
        rejections.push('BREACH_CHECK_UNAVAILABLE');
      }
    }

    return { acceptable: rejections.length === 0, rejections };
  }

  private async isBreached(password: string): Promise<'yes' | 'no' | 'unknown'> {
    const hash = breachHash(password);
    const prefix = hash.slice(0, 5);
    const suffix = hash.slice(5);
    try {
      const suffixes = await this.breachList.suffixesFor(prefix);
      return suffixes.has(suffix) ? 'yes' : 'no';
    } catch {
      // The error is swallowed on purpose: it would carry the request that
      // caused it, and callers only need to know the answer is missing. The
      // implementation logs its own failures.
      return 'unknown';
    }
  }
}

/** True if the whole password is one repeated character or one run of consecutive ones. */
function isRepetitiveOrSequential(password: string): boolean {
  const points = [...password];
  const first = points[0];
  if (first === undefined) return false;
  if (points.every((point) => point === first)) return true;

  const codes = points.map((point) => point.codePointAt(0) ?? 0);
  let ascending = true;
  let descending = true;
  for (let i = 1; i < codes.length; i += 1) {
    const previous = codes[i - 1] as number;
    const current = codes[i] as number;
    if (current !== previous + 1) ascending = false;
    if (current !== previous - 1) descending = false;
  }
  return ascending || descending;
}

/**
 * True if the password contains the account's own address or its local part.
 *
 * Only fragments of four characters or more count. A two-letter local part is a
 * substring of half the passwords in the world and rejecting on it would be
 * noise.
 */
function containsEmailFragment(foldedPassword: string, email: string | undefined): boolean {
  if (email === undefined || email === '') return false;
  const address = email.toLowerCase();
  const localPart = address.slice(0, address.lastIndexOf('@'));
  const fragments = [address, localPart].filter((fragment) => fragment.length >= 4);
  return fragments.some((fragment) => foldedPassword.includes(fragment));
}
