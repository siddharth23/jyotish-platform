/**
 * Audit trail for feature flag changes (US-006 AC3).
 *
 * A kill switch is an operational control that changes what customers can buy.
 * When someone asks six months later why the paid flow was off for forty
 * minutes on a Tuesday, the answer has to exist. That means every change
 * carries who made it and why, and nothing can write a change without both.
 *
 * LICENSING: no engine code, no chart computation. See docs/AGPL-BOUNDARY.md.
 */

/** What kind of change was made. */
export type FlagChangeKind =
  | 'created'
  | 'enabled'
  | 'disabled'
  | 'rollout_changed'
  | 'segments_changed'
  | 'deleted';

/** A single recorded change. Append-only: entries are never edited or removed. */
export interface FlagAuditEntry {
  readonly id: string;
  readonly flagKey: string;
  readonly kind: FlagChangeKind;
  /** Serialised previous and next state, for reconstructing history. */
  readonly before: string | null;
  readonly after: string | null;
  /** Who made the change. An account identifier, never a display name. */
  readonly actor: string;
  /** Why. Free text, required — see `MISSING_REASON`. */
  readonly reason: string;
  readonly at: Date;
  /** The rule-set version this change produced. */
  readonly version: number;
}

export interface FlagChangeRequest {
  readonly flagKey: string;
  readonly kind: FlagChangeKind;
  readonly before?: unknown;
  readonly after?: unknown;
  readonly actor: string;
  readonly reason: string;
}

export class FlagAuditError extends Error {
  constructor(
    message: string,
    readonly code: 'MISSING_ACTOR' | 'MISSING_REASON' | 'MISSING_FLAG_KEY',
  ) {
    super(message);
    this.name = 'FlagAuditError';
  }
}

/** Storage for audit entries. */
export interface FlagAuditRepository {
  append(entry: FlagAuditEntry): Promise<void>;
  /** Newest first. */
  list(filter?: { flagKey?: string; limit?: number }): Promise<FlagAuditEntry[]>;
}

/**
 * In-memory implementation.
 *
 * A placeholder: there is no database in this service yet, so nothing here
 * survives a restart. **This must be replaced with durable, append-only storage
 * before the kill switch is relied upon in production** — an audit trail that
 * disappears on deploy is not an audit trail. Kept as a separate class behind
 * [FlagAuditRepository] so swapping it is a one-line change.
 */
export class InMemoryFlagAuditRepository implements FlagAuditRepository {
  private readonly entries: FlagAuditEntry[] = [];

  async append(entry: FlagAuditEntry): Promise<void> {
    this.entries.push(entry);
  }

  async list(filter?: { flagKey?: string; limit?: number }): Promise<FlagAuditEntry[]> {
    let result = [...this.entries].reverse();
    if (filter?.flagKey !== undefined) {
      result = result.filter((entry) => entry.flagKey === filter.flagKey);
    }
    if (filter?.limit !== undefined) {
      result = result.slice(0, filter.limit);
    }
    return result;
  }
}

/**
 * Records flag changes.
 *
 * Refuses a change that does not name an actor and a reason. That refusal is the
 * whole point: making the audit optional means it is complete right up until the
 * incident that needed it.
 */
export class FlagAuditService {
  constructor(
    private readonly repository: FlagAuditRepository,
    private readonly now: () => Date = () => new Date(),
    private readonly newId: () => string = () => crypto.randomUUID(),
  ) {}

  async record(request: FlagChangeRequest, version: number): Promise<FlagAuditEntry> {
    if (request.flagKey.trim() === '') {
      throw new FlagAuditError('A flag key is required.', 'MISSING_FLAG_KEY');
    }
    if (request.actor.trim() === '') {
      throw new FlagAuditError(
        'Every flag change must name the account that made it.',
        'MISSING_ACTOR',
      );
    }
    if (request.reason.trim() === '') {
      throw new FlagAuditError(
        'Every flag change must state why. "Turning the paid flow off" is not ' +
          'self-explanatory six months later.',
        'MISSING_REASON',
      );
    }

    const entry: FlagAuditEntry = {
      id: this.newId(),
      flagKey: request.flagKey,
      kind: request.kind,
      before: request.before === undefined ? null : JSON.stringify(request.before),
      after: request.after === undefined ? null : JSON.stringify(request.after),
      actor: request.actor,
      reason: request.reason.trim(),
      at: this.now(),
      version,
    };
    await this.repository.append(entry);
    return entry;
  }

  /** History for one flag, newest first. */
  async history(flagKey: string, limit = 50): Promise<FlagAuditEntry[]> {
    return this.repository.list({ flagKey, limit });
  }

  /** Everything, newest first. */
  async recent(limit = 100): Promise<FlagAuditEntry[]> {
    return this.repository.list({ limit });
  }
}
