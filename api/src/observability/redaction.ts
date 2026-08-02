/**
 * Keeps personal data out of logs (US-007 AC4).
 *
 * `CLAUDE.md`: "Never log birth data, names, emails or payment details." This
 * module is how that is enforced rather than remembered, because the failure is
 * silent — nobody notices an email in a log line until a DPA asks, by which time
 * it is in the log vendor, its backups and its indices.
 *
 * ## Allowlist, not denylist
 *
 * Structured fields are dropped unless explicitly permitted. A denylist — strip
 * anything called `email`, `birthDate` and so on — fails **open**: the first
 * field someone adds called `geburtsort` or `customerMail` sails straight
 * through. An allowlist fails **closed**: a new field is invisible in logs until
 * someone decides it is safe, which is the direction the mistake should point.
 *
 * The cost is real. Adding a field to a log means adding it here, and a
 * developer debugging at 2am will find their new field missing. That is the
 * trade being made deliberately.
 *
 * LICENSING: no engine code. See docs/AGPL-BOUNDARY.md.
 */

export const REDACTED = '[redacted]';

/**
 * Structured log fields that may be recorded.
 *
 * Identifiers, states and durations — things that identify a *record* rather
 * than a *person*. `orderId` is fine; it resolves to a person only through the
 * database, which is access-controlled and audited. `email` is not.
 */
export const ALLOWED_FIELDS: ReadonlySet<string> = new Set([
  // Correlation and tracing
  'correlationId',
  'requestId',
  'spanId',
  'sessionId',
  // Record identifiers — pseudonymous, resolvable only via the database
  'orderId',
  'userId',
  'astrologerId',
  'chartId',
  'evaluationId',
  'paymentIntentId',
  // Request shape
  'method',
  'route',
  'statusCode',
  'durationMs',
  'queueDepth',
  'attempt',
  'retryAfterMs',
  // Domain state, no personal content
  'orderState',
  'previousState',
  'flagKey',
  'flagValue',
  'ruleSetVersion',
  'engineVersion',
  'locale',
  'platform',
  'appVersion',
  // Errors
  'errorCode',
  'errorType',
  'component',
  'operation',
]);

/**
 * Patterns scrubbed from free text.
 *
 * Messages are written by humans and will eventually interpolate something they
 * should not. Order matters: longer, more specific patterns run first so a card
 * number is not partly consumed by the generic digit-run rule.
 */
const TEXT_PATTERNS: ReadonlyArray<{ readonly name: string; readonly pattern: RegExp }> = [
  { name: 'email', pattern: /[\w.+-]+@[\w-]+\.[\w.-]+/gi },
  // IBAN. Not written as groups of four: a German IBAN is DE + 2 check digits
  // + 18 more, and 18 is not a multiple of 4, so a groups-of-four pattern
  // misses the unspaced form entirely — which is how it is usually stored.
  { name: 'iban', pattern: /\b[A-Z]{2}\d{2}(?:[ ]?[A-Z0-9]){10,30}\b/g },
  // Card numbers, with or without separators.
  { name: 'card', pattern: /\b(?:\d[ -]?){13,19}\b/g },
  // Coordinates: a birthplace to within a few metres.
  { name: 'coordinates', pattern: /\b-?\d{1,3}\.\d{4,}\s*,\s*-?\d{1,3}\.\d{4,}\b/g },
  // Dates in German or ISO form. Over-broad on purpose: a date in a log line is
  // more likely to be someone's birth date than anything worth keeping.
  { name: 'date', pattern: /\b\d{1,2}\.\d{1,2}\.\d{4}\b|\b\d{4}-\d{2}-\d{2}\b/g },
  { name: 'phone', pattern: /\b\+?\d[\d\s/-]{7,}\d\b/g },
  // Bearer tokens and API keys.
  { name: 'token', pattern: /\b(?:Bearer\s+)?[A-Za-z0-9_-]{32,}\b/g },
  { name: 'ipv4', pattern: /\b(?:\d{1,3}\.){3}\d{1,3}\b/g },
];

/** Replaces anything in [TEXT_PATTERNS] with a marker naming what was removed. */
export function redactText(input: string): string {
  let output = input;
  for (const { name, pattern } of TEXT_PATTERNS) {
    // Fresh regex each call: a shared /g regex carries lastIndex between calls
    // and would skip matches on the second message.
    output = output.replace(new RegExp(pattern.source, pattern.flags), `[${name} redacted]`);
  }
  return output;
}

/** A structured payload safe to hand to a log sink. */
export type SafeFields = Record<string, string | number | boolean | null>;

/**
 * Drops any field not in [ALLOWED_FIELDS] and scrubs the values that remain.
 *
 * Allowed values are still scrubbed: `route` is permitted, but
 * `/orders?email=a@b.de` should not survive because the field name was on the
 * list.
 */
export function redactFields(fields: Record<string, unknown>): SafeFields {
  const safe: SafeFields = {};
  const dropped: string[] = [];

  for (const [key, value] of Object.entries(fields)) {
    if (!ALLOWED_FIELDS.has(key)) {
      dropped.push(key);
      continue;
    }
    if (value === null || value === undefined) {
      safe[key] = null;
    } else if (typeof value === 'number' || typeof value === 'boolean') {
      safe[key] = value;
    } else {
      safe[key] = redactText(String(value));
    }
  }

  // Names of dropped fields are recorded, values never are. Without this a
  // developer sees their field silently vanish and assumes the logger is broken;
  // with it, they see exactly which field to add to the allowlist.
  if (dropped.length > 0) {
    safe.droppedFields = dropped.sort().join(',');
  }
  return safe;
}
