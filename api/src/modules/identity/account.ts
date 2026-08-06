/**
 * The account record and its storage port (US-011).
 *
 * LICENSING: no engine code. See docs/AGPL-BOUNDARY.md.
 */

export interface Account {
  readonly id: string;
  /**
   * Blind index of the email — the lookup key. See `email_index.ts`.
   *
   * The persistent schema must put a **unique** constraint here. Application
   * code checking "does this address exist" before inserting is a read followed
   * by a write, and two sign-ups arriving in the same millisecond both pass it.
   */
  readonly emailIndex: string;
  /**
   * The address itself.
   *
   * `docs/SECURITY.md` requires field-level encryption at rest for personal
   * data. The persistence adapter is responsible for that: this type is the
   * decrypted view the domain works with. It must not reach a log, a metric or
   * a test fixture.
   */
  readonly email: string;
  /**
   * The encoded password hash, or null.
   *
   * Null covers accounts created through Sign in with Apple or Google (US-012),
   * which have no password until someone sets one. Every code path that
   * verifies a password must handle it — a null hash means "no password login
   * for this account", never "any password will do".
   */
  readonly passwordHash: string | null;
  /** When the address was proven, or null. US-011 AC1. */
  readonly emailVerifiedAt: Date | null;
  /** BCP 47. Decides the language of verification and reset emails. */
  readonly locale: string;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

export class DuplicateAccountError extends Error {
  constructor() {
    super('An account already exists for this address.');
    this.name = 'DuplicateAccountError';
  }
}

export interface AccountRepository {
  findByEmailIndex(emailIndex: string): Promise<Account | null>;
  findById(id: string): Promise<Account | null>;
  /** Throws [DuplicateAccountError] if `emailIndex` is taken. */
  insert(account: Account): Promise<void>;
  update(account: Account): Promise<void>;
}

/**
 * In-memory implementation.
 *
 * A placeholder, as elsewhere in this service — there is no database yet.
 * **Replace before launch.** Accounts that vanish on deploy are not accounts.
 */
export class InMemoryAccountRepository implements AccountRepository {
  private readonly byId = new Map<string, Account>();
  private readonly idByEmailIndex = new Map<string, string>();

  async findByEmailIndex(emailIndex: string): Promise<Account | null> {
    const id = this.idByEmailIndex.get(emailIndex);
    return id === undefined ? null : (this.byId.get(id) ?? null);
  }

  async findById(id: string): Promise<Account | null> {
    return this.byId.get(id) ?? null;
  }

  async insert(account: Account): Promise<void> {
    if (this.idByEmailIndex.has(account.emailIndex)) throw new DuplicateAccountError();
    this.byId.set(account.id, account);
    this.idByEmailIndex.set(account.emailIndex, account.id);
  }

  async update(account: Account): Promise<void> {
    if (!this.byId.has(account.id)) throw new Error(`No account ${account.id}.`);
    this.byId.set(account.id, account);
  }

  /** Test helper. Never call from production code. */
  get size(): number {
    return this.byId.size;
  }
}
