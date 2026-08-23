/**
 * Self-service account deletion (US-015).
 *
 * ## Two laws pull in opposite directions, and both must be obeyed
 *
 * GDPR Article 17 gives the user erasure. German tax law — §147 AO, and the
 * GoBD archive `docs/COMPLIANCE.md` commits us to — requires invoices to be
 * kept for ten years, and §14 UStG says what an invoice must contain, which
 * includes the customer's name. Article 17(3)(b) resolves it: erasure does not
 * apply where processing is necessary for compliance with a legal obligation.
 *
 * So deletion is not "remove every row that mentions this person". It is:
 * **erase everything, except the specific fields a retention law names, and
 * keep those in a form that can serve no other purpose.** [DeletionPlan] is
 * that list, written down rather than left to whoever writes the SQL.
 *
 * The distinction has to be explained to the user before they confirm — AC2 —
 * because "delete my account" and "delete every trace of me" are not the same
 * promise, and discovering the difference afterwards is a complaint to a
 * supervisory authority.
 *
 * ## Why there is a grace period
 *
 * The account stops working the moment deletion is requested: sessions are
 * revoked, login is refused. The data goes later, after [DELETION_GRACE_MS].
 *
 * The window exists because deletion is the one irreversible thing a stolen
 * account can do. Someone who takes over an account and deletes it destroys
 * the victim's paid reports and their birth data with no recovery path; a
 * grace period plus the notice email turns that into something the real owner
 * can stop. It also catches the ordinary misclick.
 *
 * It is deliberately far shorter than the thirty days AC3 allows. Article 12(3)
 * makes one month the *outer* bound for acting on a request, not a budget to
 * spend, and Article 17 says "without undue delay" — scheduling the erasure for
 * day thirty would put us at the limit with no room for a failed job.
 *
 * ## Apple guideline 5.1.1(v)
 *
 * An app that offers account creation must offer deletion *inside the app*.
 * Not a support address, not a web form, not a "contact us". Failing this is a
 * review rejection, so `app/lib/features/profile/` owns reaching this flow in
 * three taps (AC1) and neither half is optional.
 *
 * LICENSING: no engine code. See docs/AGPL-BOUNDARY.md.
 */

import { Logger } from '../../observability/logger.js';

import type { Account, AccountRepository } from './account.js';

/**
 * Seven days.
 *
 * Long enough that a notice email sent to someone on holiday for a week is
 * still useful; short enough to stay well inside the thirty days of AC3 even
 * if the purge job fails and has to be retried for several days.
 */
export const DELETION_GRACE_MS = 7 * 24 * 60 * 60 * 1000;

/** The promise AC3 makes. Asserted in tests against the grace period. */
export const DELETION_DEADLINE_MS = 30 * 24 * 60 * 60 * 1000;

/**
 * Ten years, per §147 AO and the GoBD archive in `docs/COMPLIANCE.md`.
 *
 * Runs from the end of the calendar year the invoice was issued in, not from
 * the invoice date — a subtlety that belongs to the `payment` module's purge
 * job. Recorded here because this is where someone will look for it.
 */
export const INVOICE_RETENTION_YEARS = 10;

/**
 * What deletion does to one category of data.
 *
 * `erase` — the row goes.
 * `retain` — a law names it. The reason must be a specific obligation, not a
 *   business preference: "we might need it" is not a lawful basis, and this
 *   field is what an Article 30 record and a DPIA are written from.
 */
export type DeletionDisposition =
  | { readonly action: 'erase' }
  | { readonly action: 'retain'; readonly basis: string; readonly until: string };

export interface DeletionPlanEntry {
  /** The category as a user would name it, not a table name. */
  readonly category: string;
  readonly disposition: DeletionDisposition;
  /** Which module owns carrying this out. */
  readonly owner: string;
}

/**
 * The authoritative list of what deletion means.
 *
 * Kept as data rather than as prose in a runbook so that the screen the user
 * confirms on (AC2), the purge job, and the Article 30 record are all derived
 * from one source. If they are written three times they will disagree, and the
 * one that is wrong will be the one shown to the user.
 *
 * **Adding a category that stores personal data without adding it here is the
 * failure mode.** `plannedCategories` is asserted in tests so a new module has
 * to make a decision rather than inherit silence.
 */
export const DELETION_PLAN: readonly DeletionPlanEntry[] = [
  { category: 'account', owner: 'identity', disposition: { action: 'erase' } },
  { category: 'email_address', owner: 'identity', disposition: { action: 'erase' } },
  { category: 'password', owner: 'identity', disposition: { action: 'erase' } },
  { category: 'sessions', owner: 'identity', disposition: { action: 'erase' } },
  { category: 'birth_data', owner: 'profile', disposition: { action: 'erase' } },
  { category: 'chart_snapshots', owner: 'chart', disposition: { action: 'erase' } },
  { category: 'career_analyses', owner: 'career', disposition: { action: 'erase' } },
  { category: 'delivered_reports', owner: 'report', disposition: { action: 'erase' } },
  { category: 'focus_questions', owner: 'order', disposition: { action: 'erase' } },
  { category: 'push_tokens', owner: 'notification', disposition: { action: 'erase' } },
  {
    category: 'invoices',
    owner: 'payment',
    disposition: {
      action: 'retain',
      // The name and address on an invoice are required content under §14
      // UStG; the archive itself is §147 AO. Neither is optional and neither
      // is ours to waive at the user's request — Article 17(3)(b).
      basis: 'GDPR Art. 17(3)(b); §147 AO; §14 UStG',
      until: `${INVOICE_RETENTION_YEARS} years from the end of the year of issue`,
    },
  },
  {
    category: 'deletion_record',
    owner: 'identity',
    disposition: {
      action: 'retain',
      // Proving a deletion happened requires not deleting the proof. Holds an
      // account id and timestamps, never an address.
      basis: 'GDPR Art. 5(2) accountability',
      until: 'indefinite; contains no personal data',
    },
  },
];

/** Categories the plan covers. Every module holding personal data must appear. */
export function plannedCategories(): readonly string[] {
  return DELETION_PLAN.map((entry) => entry.category);
}

/** What the confirmation screen shows (AC2). */
export function erasedCategories(): readonly string[] {
  return DELETION_PLAN.filter((e) => e.disposition.action === 'erase').map((e) => e.category);
}

export function retainedCategories(): readonly DeletionPlanEntry[] {
  return DELETION_PLAN.filter((e) => e.disposition.action === 'retain');
}

export type DeletionState = 'scheduled' | 'completed' | 'cancelled';

export interface DeletionRequest {
  readonly accountId: string;
  readonly requestedAt: Date;
  /** When the purge becomes due. [requestedAt] + [DELETION_GRACE_MS]. */
  readonly purgeDueAt: Date;
  readonly state: DeletionState;
  readonly completedAt: Date | null;
  readonly cancelledAt: Date | null;
}

export interface DeletionRepository {
  insert(request: DeletionRequest): Promise<void>;
  findByAccountId(accountId: string): Promise<DeletionRequest | null>;
  update(request: DeletionRequest): Promise<void>;
  /** Requests whose grace period has elapsed and which are still scheduled. */
  listDue(at: Date): Promise<readonly DeletionRequest[]>;
}

/**
 * In-memory implementation.
 *
 * A placeholder, as elsewhere in this service. **Replace before launch**, and
 * with more care than the others: a deletion request that does not survive a
 * deploy is an erasure that silently never happens, which is the kind of
 * failure that is discovered by a supervisory authority rather than by us.
 * The purge job must be idempotent and must record its own completion.
 */
export class InMemoryDeletionRepository implements DeletionRepository {
  private readonly byAccountId = new Map<string, DeletionRequest>();

  async insert(request: DeletionRequest): Promise<void> {
    this.byAccountId.set(request.accountId, request);
  }

  async findByAccountId(accountId: string): Promise<DeletionRequest | null> {
    return this.byAccountId.get(accountId) ?? null;
  }

  async update(request: DeletionRequest): Promise<void> {
    this.byAccountId.set(request.accountId, request);
  }

  async listDue(at: Date): Promise<readonly DeletionRequest[]> {
    return [...this.byAccountId.values()].filter(
      (request) =>
        request.state === 'scheduled' && request.purgeDueAt.getTime() <= at.getTime(),
    );
  }
}

/**
 * Erases one module's data for one account.
 *
 * Each owning module implements this. Deliberately not a single "delete
 * everything" function: the identity module does not know what a chart
 * snapshot is, and a module that later stores personal data must register here
 * rather than be remembered by whoever wrote this file.
 */
export interface PersonalDataEraser {
  /** Matches a `category` in [DELETION_PLAN]. */
  readonly category: string;
  erase(accountId: string): Promise<void>;
}

/** Revokes sessions. Satisfied by `SessionStore` from US-016. */
export interface DeletionSessionRevoker {
  revokeAllForAccount(accountId: string, reason: 'SIGNED_OUT_EVERYWHERE'): Promise<void>;
}

export interface DeletionMailer {
  /** Sent on request: what will go, what stays, and how to stop it. AC2, AC3. */
  sendDeletionScheduledNotice(to: { email: string; locale: string }, purgeDueAt: Date): Promise<void>;
  /** Sent once the data is gone. AC3. */
  sendDeletionCompletedNotice(to: { email: string; locale: string }): Promise<void>;
  sendDeletionCancelledNotice(to: { email: string; locale: string }): Promise<void>;
}

export interface DeletionServiceDependencies {
  readonly accounts: AccountRepository;
  readonly deletions: DeletionRepository;
  readonly sessions: DeletionSessionRevoker;
  readonly mailer: DeletionMailer;
  /** One per module holding personal data. Checked against [DELETION_PLAN]. */
  readonly erasers: readonly PersonalDataEraser[];
  readonly logger?: Logger;
  readonly now?: () => Date;
}

export type RequestDeletionResult =
  | { readonly outcome: 'scheduled'; readonly purgeDueAt: Date }
  /** Already scheduled. Idempotent: the original date stands. */
  | { readonly outcome: 'already_scheduled'; readonly purgeDueAt: Date }
  | { readonly outcome: 'unknown_account' };

export type CancelDeletionResult =
  | { readonly outcome: 'cancelled' }
  | { readonly outcome: 'not_scheduled' }
  /** The grace period elapsed and the data is gone. Nothing to restore. */
  | { readonly outcome: 'already_completed' };

export class DeletionService {
  private readonly logger: Logger;
  private readonly now: () => Date;

  constructor(private readonly dependencies: DeletionServiceDependencies) {
    this.logger = dependencies.logger ?? new Logger();
    this.now = dependencies.now ?? ((): Date => new Date());

    // Fail at construction, not at 3am when a purge runs. A module that holds
    // personal data and supplies no eraser would otherwise leave that data
    // behind, and nothing would say so.
    const missing = erasedCategories().filter(
      (category) => !dependencies.erasers.some((eraser) => eraser.category === category),
    );
    if (missing.length > 0) {
      throw new Error(`No eraser registered for: ${missing.join(', ')}.`);
    }
  }

  /**
   * Schedules deletion and locks the account out immediately.
   *
   * The lockout is not cosmetic. Between the request and the purge the account
   * must not be usable — otherwise a session that outlives the request keeps
   * reading the very data being erased, and a login during the window would
   * make "deleted" mean nothing.
   */
  async requestDeletion(accountId: string): Promise<RequestDeletionResult> {
    const account = await this.dependencies.accounts.findById(accountId);
    if (account === null) return { outcome: 'unknown_account' };

    const existing = await this.dependencies.deletions.findByAccountId(accountId);
    if (existing !== null && existing.state === 'scheduled') {
      return { outcome: 'already_scheduled', purgeDueAt: existing.purgeDueAt };
    }

    const at = this.now();
    const purgeDueAt = new Date(at.getTime() + DELETION_GRACE_MS);
    await this.dependencies.deletions.insert({
      accountId,
      requestedAt: at,
      purgeDueAt,
      state: 'scheduled',
      completedAt: null,
      cancelledAt: null,
    });

    // US-016. Every device signs out now, not at purge time.
    await this.dependencies.sessions.revokeAllForAccount(accountId, 'SIGNED_OUT_EVERYWHERE');

    await this.dependencies.mailer.sendDeletionScheduledNotice(
      { email: account.email, locale: account.locale },
      purgeDueAt,
    );

    this.logger.info('deletion scheduled', {
      operation: 'account_deletion_request',
      userId: accountId,
    });
    return { outcome: 'scheduled', purgeDueAt };
  }

  /** Stops a scheduled deletion during the grace period. */
  async cancelDeletion(accountId: string): Promise<CancelDeletionResult> {
    const existing = await this.dependencies.deletions.findByAccountId(accountId);
    if (existing === null) return { outcome: 'not_scheduled' };
    if (existing.state === 'completed') return { outcome: 'already_completed' };
    if (existing.state === 'cancelled') return { outcome: 'not_scheduled' };

    const at = this.now();
    await this.dependencies.deletions.update({
      ...existing,
      state: 'cancelled',
      cancelledAt: at,
    });

    const account = await this.dependencies.accounts.findById(accountId);
    if (account !== null) {
      await this.dependencies.mailer.sendDeletionCancelledNotice({
        email: account.email,
        locale: account.locale,
      });
    }

    this.logger.info('deletion cancelled', {
      operation: 'account_deletion_cancel',
      userId: accountId,
    });
    return { outcome: 'cancelled' };
  }

  /**
   * Runs every due purge. Called by a scheduled job.
   *
   * Returns how many completed. Failures are logged and left scheduled rather
   * than marked done, so the next run retries them — the grace period is short
   * enough that several retries still land inside the thirty days.
   */
  async runDuePurges(): Promise<number> {
    const at = this.now();
    const due = await this.dependencies.deletions.listDue(at);

    let completed = 0;
    for (const request of due) {
      try {
        await this.purge(request);
        completed += 1;
      } catch (error) {
        // One account's failure must not abandon the rest of the batch.
        this.logger.error('deletion purge failed', 'DELETION_PURGE_FAILED', {
          operation: 'account_deletion_purge',
          userId: request.accountId,
          errorType: error instanceof Error ? error.name : 'unknown',
        });
      }
    }
    return completed;
  }

  private async purge(request: DeletionRequest): Promise<void> {
    // Read the address before anything erases it: the completion notice (AC3)
    // has to be sent somewhere, and after the purge there is nowhere left to
    // look it up. Held only for the duration of this function.
    const account = await this.dependencies.accounts.findById(request.accountId);

    // Erasers run before the account row goes. The reverse order would leave
    // an orphaned chart snapshot if a later eraser threw, and nothing would
    // point at it.
    for (const eraser of this.dependencies.erasers) {
      await eraser.erase(request.accountId);
    }

    const at = this.now();
    await this.dependencies.deletions.update({
      ...request,
      state: 'completed',
      completedAt: at,
    });

    if (account !== null) {
      await this.dependencies.mailer.sendDeletionCompletedNotice({
        email: account.email,
        locale: account.locale,
      });
    }

    this.logger.info('deletion completed', {
      operation: 'account_deletion_purge',
      userId: request.accountId,
    });
  }

  /**
   * Whether this account may still authenticate.
   *
   * Wired into US-016's `PrincipalResolver` so a refresh during the grace
   * period fails, and into login so a password cannot reopen the account.
   */
  async isLockedOut(accountId: string): Promise<boolean> {
    const existing = await this.dependencies.deletions.findByAccountId(accountId);
    return existing !== null && existing.state === 'scheduled';
  }
}

/** Wraps a function as an eraser, for modules with nothing more to hold. */
export function callbackEraser(
  category: string,
  erase: (accountId: string) => Promise<void>,
): PersonalDataEraser {
  return { category, erase };
}

/**
 * Overwrites an account's identifying fields in place.
 *
 * Used where a hard row delete is not possible because other rows still
 * reference the account — a retained invoice, for instance. The row survives
 * as a tombstone with nothing personal in it.
 *
 * `email` becomes empty rather than something like `deleted@example.invalid`:
 * a placeholder that looks like an address will eventually be treated as one,
 * and the blind index must not resolve either, or the address is still
 * discoverable by searching for it.
 */
export function tombstone(account: Account, at: Date): Account {
  return {
    ...account,
    email: '',
    emailIndex: '',
    passwordHash: null,
    emailVerifiedAt: null,
    updatedAt: at,
  };
}
