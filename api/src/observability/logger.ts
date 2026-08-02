/**
 * Structured logging with correlation IDs (US-007 AC1).
 *
 * One JSON object per line, so a log aggregator can index fields rather than
 * regex over prose. Every line carries the correlation id of the request that
 * caused it, which is what makes an incident traceable from the app, through the
 * API, into a worker.
 *
 * Every message and every field passes through redaction. That is not optional
 * and there is no bypass: a logger with an "unsafe" escape hatch grows callers.
 *
 * LICENSING: no engine code. See docs/AGPL-BOUNDARY.md.
 */

import { AsyncLocalStorage } from 'node:async_hooks';

import { redactFields, redactText, type SafeFields } from './redaction.js';

export type LogLevel = 'debug' | 'info' | 'warn' | 'error';

const LEVEL_ORDER: Record<LogLevel, number> = {
  debug: 10,
  info: 20,
  warn: 30,
  error: 40,
};

export interface LogRecord {
  readonly timestamp: string;
  readonly level: LogLevel;
  readonly message: string;
  readonly correlationId: string | null;
  readonly fields: SafeFields;
}

/** Where records go. Swapped for a collector in production, captured in tests. */
export interface LogSink {
  write(record: LogRecord): void;
}

/** Writes one JSON object per line to stdout. */
export class ConsoleSink implements LogSink {
  write(record: LogRecord): void {
    // eslint-disable-next-line no-console
    console.log(JSON.stringify(record));
  }
}

/** Keeps records in memory, for tests. */
export class MemorySink implements LogSink {
  readonly records: LogRecord[] = [];
  write(record: LogRecord): void {
    this.records.push(record);
  }
  clear(): void {
    this.records.length = 0;
  }
}

interface CorrelationContext {
  readonly correlationId: string;
}

const storage = new AsyncLocalStorage<CorrelationContext>();

/**
 * Runs [callback] with [correlationId] attached to every log line inside it,
 * including across `await` boundaries.
 *
 * Uses AsyncLocalStorage rather than passing the id through every function
 * signature. Threading it by hand means the one path that forgets is the one
 * that breaks an incident investigation, and it is always a path someone added
 * later.
 */
export function withCorrelationId<T>(correlationId: string, callback: () => T): T {
  return storage.run({ correlationId }, callback);
}

/** The correlation id in scope, if any. */
export function currentCorrelationId(): string | null {
  return storage.getStore()?.correlationId ?? null;
}

/**
 * Accepts an inbound correlation id, or mints one.
 *
 * An id from a client is untrusted input: it lands in logs and in any downstream
 * system, so it is length-capped and restricted to characters that cannot break
 * a log line or be read as markup. Anything else is replaced rather than
 * sanitised in place, since a caller sending a malformed id is not a caller
 * whose id is worth preserving.
 */
export function acceptCorrelationId(inbound: string | null | undefined): string {
  if (typeof inbound === 'string') {
    const trimmed = inbound.trim();
    if (/^[A-Za-z0-9_-]{8,64}$/.test(trimmed)) return trimmed;
  }
  return crypto.randomUUID();
}

export class Logger {
  constructor(
    private readonly sink: LogSink = new ConsoleSink(),
    private readonly minimumLevel: LogLevel = 'info',
    private readonly now: () => Date = () => new Date(),
  ) {}

  debug(message: string, fields: Record<string, unknown> = {}): void {
    this.log('debug', message, fields);
  }
  info(message: string, fields: Record<string, unknown> = {}): void {
    this.log('info', message, fields);
  }
  warn(message: string, fields: Record<string, unknown> = {}): void {
    this.log('warn', message, fields);
  }

  /**
   * Logs an error.
   *
   * Takes an error *code*, not an Error. A stack trace or an exception message
   * routinely contains the value that caused it — the email that failed
   * validation, the row that failed to parse — so passing one straight to a log
   * sink is the most common way personal data escapes.
   */
  error(message: string, errorCode: string, fields: Record<string, unknown> = {}): void {
    this.log('error', message, { ...fields, errorCode });
  }

  private log(level: LogLevel, message: string, fields: Record<string, unknown>): void {
    if (LEVEL_ORDER[level] < LEVEL_ORDER[this.minimumLevel]) return;
    this.sink.write({
      timestamp: this.now().toISOString(),
      level,
      message: redactText(message),
      correlationId: currentCorrelationId(),
      fields: redactFields(fields),
    });
  }
}
