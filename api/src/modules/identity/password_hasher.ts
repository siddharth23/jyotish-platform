/**
 * Password hashing (US-011).
 *
 * ## Why scrypt
 *
 * Argon2id is the first choice in OWASP's guidance and would be used if a
 * dependency were on the table. It is not yet: this service has no runtime
 * dependencies, and a native module in the login path is a build and supply
 * chain commitment. scrypt is OWASP's named alternative, it is memory-hard, and
 * it ships in Node's standard library.
 *
 * The parameters live inside the encoded hash, so moving to Argon2id later is a
 * new prefix and a rehash-on-next-login, not a migration. Nobody's password can
 * be rehashed offline — the plaintext only exists during a login — so every
 * upgrade path is "verify with the old parameters, immediately rehash with the
 * new ones". That is why the format is versioned from the first commit.
 *
 * ## Why these parameters, and what they cost
 *
 * N=65536, r=8, p=2 is one of OWASP's listed pairs. Memory is 128 · N · r ≈
 * 64 MiB **per concurrent verification**. Fifty simultaneous logins is 3 GiB.
 * That is not a footnote: it is the reason the login throttle in
 * `login_throttle.ts` exists as a limit on *attempts* and not only on
 * credential stuffing. An expensive KDF without a rate limit in front of it is
 * a memory exhaustion primitive that anyone can reach unauthenticated.
 *
 * ## No pepper
 *
 * A server-side pepper would mean a database leak alone does not yield
 * crackable hashes. It is not used here because rotating it requires rehashing
 * every password, which requires plaintexts we do not have — so in practice a
 * pepper is never rotated, and an unrotatable secret that lives on every
 * application host is worth less than it appears. (The email index in
 * `email_index.ts` does use one, because that value *can* be recomputed from
 * the stored ciphertext.)
 *
 * LICENSING: no engine code. See docs/AGPL-BOUNDARY.md.
 */

import { randomBytes, scrypt, type ScryptOptions, timingSafeEqual } from 'node:crypto';

/**
 * `promisify(scrypt)` is not used: its type resolves to the three-argument
 * overload, which cannot carry the options object, and every parameter set here
 * needs `maxmem` (see [ScryptPasswordHasher.derive]).
 */
function deriveKey(
  password: string,
  salt: Buffer,
  keyLength: number,
  options: ScryptOptions,
): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    scrypt(password, salt, keyLength, options, (error, key) => {
      if (error !== null) reject(error);
      else resolve(key);
    });
  });
}

export interface ScryptParameters {
  /** CPU/memory cost. A power of two. */
  readonly N: number;
  /** Block size. */
  readonly r: number;
  /** Parallelisation. */
  readonly p: number;
}

/** OWASP's scrypt option at roughly 64 MiB per verification. */
export const DEFAULT_SCRYPT_PARAMETERS: ScryptParameters = { N: 65536, r: 8, p: 2 };

const KEY_LENGTH = 32;
const SALT_LENGTH = 16;
const ALGORITHM = 'scrypt';

/**
 * Bounds on parameters read back out of storage.
 *
 * A stored hash is data, and data can be wrong — a bad migration, or someone
 * with write access to the database. Without a ceiling, `N=2^30` in one row
 * turns one login attempt into an out-of-memory kill. Without a floor, a
 * rewritten row silently downgrades that account's hash to something crackable.
 */
const MIN_N = 1 << 12;
const MAX_N = 1 << 20;
const MAX_R = 32;
const MAX_P = 16;

export class PasswordHashError extends Error {
  constructor(
    message: string,
    readonly code: 'MALFORMED_HASH' | 'UNSUPPORTED_ALGORITHM' | 'PARAMETERS_OUT_OF_RANGE',
  ) {
    super(message);
    this.name = 'PasswordHashError';
  }
}

export interface PasswordHasher {
  hash(password: string): Promise<string>;
  verify(password: string, encoded: string): Promise<boolean>;
  /** Spends the same work as a verification, against no account. See below. */
  spendVerificationTime(): Promise<void>;
  needsRehash(encoded: string): boolean;
}

/**
 * scrypt with the parameters recorded in the encoded value.
 *
 * Encoded form: `scrypt$N=65536,r=8,p=2$<salt>$<key>`, both base64url.
 */
export class ScryptPasswordHasher implements PasswordHasher {
  private dummyHash: string | null = null;

  constructor(private readonly parameters: ScryptParameters = DEFAULT_SCRYPT_PARAMETERS) {
    assertParametersInRange(parameters);
  }

  async hash(password: string): Promise<string> {
    const salt = randomBytes(SALT_LENGTH);
    const key = await this.derive(password, salt, this.parameters);
    const { N, r, p } = this.parameters;
    return `${ALGORITHM}$N=${N},r=${r},p=${p}$${base64url(salt)}$${base64url(key)}`;
  }

  /**
   * Verifies a password. Returns false rather than throwing on a malformed
   * stored value: a corrupt row must fail the login, not the request.
   */
  async verify(password: string, encoded: string): Promise<boolean> {
    let parsed: ParsedHash;
    try {
      parsed = parseHash(encoded);
    } catch {
      return false;
    }
    const candidate = await this.derive(password, parsed.salt, parsed.parameters);
    // Length is not secret — it is fixed by the format — so comparing it first
    // leaks nothing, and timingSafeEqual requires equal lengths anyway.
    if (candidate.length !== parsed.key.length) return false;
    return timingSafeEqual(candidate, parsed.key);
  }

  /**
   * Burns a verification's worth of CPU and memory against a throwaway hash.
   *
   * Called when a login names an address with no account, or an account with no
   * password (social-only, US-012). Without it, "no such account" returns in
   * microseconds and "wrong password" returns in a hundred milliseconds, and
   * that difference is a free account-enumeration oracle — one that survives
   * every carefully identical error message in the layer above.
   */
  async spendVerificationTime(): Promise<void> {
    this.dummyHash ??= await this.hash(randomBytes(24).toString('base64url'));
    await this.verify('this password is never correct', this.dummyHash);
  }

  /** True if [encoded] was produced with weaker parameters than are current. */
  needsRehash(encoded: string): boolean {
    try {
      const { parameters } = parseHash(encoded);
      return (
        parameters.N < this.parameters.N ||
        parameters.r < this.parameters.r ||
        parameters.p < this.parameters.p
      );
    } catch {
      // Unparseable or written by an algorithm this build does not know: it
      // cannot verify anyway, and saying "rehash" is the safe answer.
      return true;
    }
  }

  private async derive(
    password: string,
    salt: Buffer,
    parameters: ScryptParameters,
  ): Promise<Buffer> {
    const { N, r, p } = parameters;
    // Node's default maxmem is 32 MiB and it throws — rather than degrading —
    // when 128 · N · r exceeds it. Every parameter set worth using is above
    // that default, so it has to be raised explicitly. Headroom of 2× covers
    // the allocator's own overhead.
    const maxmem = 256 * N * r;
    return deriveKey(password, salt, KEY_LENGTH, { N, r, p, maxmem });
  }
}

interface ParsedHash {
  readonly parameters: ScryptParameters;
  readonly salt: Buffer;
  readonly key: Buffer;
}

function parseHash(encoded: string): ParsedHash {
  const parts = encoded.split('$');
  if (parts.length !== 4) {
    throw new PasswordHashError('The stored hash is not in the expected form.', 'MALFORMED_HASH');
  }
  const [algorithm, parameterPart, saltPart, keyPart] = parts as [string, string, string, string];
  if (algorithm !== ALGORITHM) {
    throw new PasswordHashError(
      `This build cannot verify a "${algorithm}" hash.`,
      'UNSUPPORTED_ALGORITHM',
    );
  }

  const match = /^N=(\d+),r=(\d+),p=(\d+)$/.exec(parameterPart);
  if (match === null) {
    throw new PasswordHashError('The stored parameters are malformed.', 'MALFORMED_HASH');
  }
  const parameters: ScryptParameters = {
    N: Number(match[1]),
    r: Number(match[2]),
    p: Number(match[3]),
  };
  assertParametersInRange(parameters);

  const salt = Buffer.from(saltPart, 'base64url');
  const key = Buffer.from(keyPart, 'base64url');
  if (salt.length === 0 || key.length !== KEY_LENGTH) {
    throw new PasswordHashError('The stored salt or key has a bad length.', 'MALFORMED_HASH');
  }
  return { parameters, salt, key };
}

function assertParametersInRange({ N, r, p }: ScryptParameters): void {
  const isPowerOfTwo = N > 0 && (N & (N - 1)) === 0;
  if (!isPowerOfTwo || N < MIN_N || N > MAX_N || r < 1 || r > MAX_R || p < 1 || p > MAX_P) {
    throw new PasswordHashError(
      `scrypt parameters out of range: N=${N}, r=${r}, p=${p}.`,
      'PARAMETERS_OUT_OF_RANGE',
    );
  }
}

function base64url(buffer: Buffer): string {
  return buffer.toString('base64url');
}
