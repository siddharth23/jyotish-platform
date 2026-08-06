/**
 * Email address normalisation and validation (US-011).
 *
 * The address is the account's identity, its delivery channel for a paid report
 * and the reset path for a lost password. Getting normalisation wrong shows up
 * as duplicate accounts — someone registers `Anna@Example.de`, comes back and
 * types `anna@example.de`, and their orders are on the other account.
 *
 * LICENSING: no engine code. See docs/AGPL-BOUNDARY.md.
 */

/** Why an address was rejected. Codes, not prose — the UI strings are ICU. */
export type EmailRejection =
  | 'EMPTY'
  | 'TOO_LONG'
  | 'MALFORMED'
  | 'LOCAL_PART_TOO_LONG'
  | 'DOMAIN_INVALID';

export class EmailAddressError extends Error {
  constructor(
    message: string,
    readonly code: EmailRejection,
  ) {
    super(message);
    this.name = 'EmailAddressError';
  }
}

/** RFC 5321: 254 for the whole address, 64 for the local part. */
const MAX_ADDRESS_LENGTH = 254;
const MAX_LOCAL_PART_LENGTH = 64;
const MAX_DOMAIN_LABEL_LENGTH = 63;

/**
 * Trims, Unicode-normalises and lowercases an address, or throws.
 *
 * ## What is deliberately *not* done
 *
 * Gmail's aliasing rules — stripping dots, cutting everything after `+` — are
 * not applied. They are Gmail's, not the internet's: `a.b@gmx.de` and
 * `ab@gmx.de` are different mailboxes at most German providers, and collapsing
 * them would let one person take over another's account by registering the
 * punctuation variant first. The cost of not collapsing is that one Gmail user
 * can hold several accounts, which is harmless.
 *
 * The local part is lowercased even though RFC 5321 makes it case-sensitive.
 * No provider anyone will use here treats it as such, and honouring the RFC
 * would mean `Anna@` and `anna@` are separate accounts — a support burden with
 * no upside.
 *
 * Normalisation is NFKC so that visually identical forms collapse to one
 * representation before hashing. Confusable *scripts* (Cyrillic `а` for Latin
 * `a`) are not addressed here; that is a registrar-level problem and the
 * verification link is what actually proves control of the mailbox.
 */
export function normaliseEmail(raw: string): string {
  const trimmed = raw.normalize('NFKC').trim();
  if (trimmed === '') {
    throw new EmailAddressError('An email address is required.', 'EMPTY');
  }
  if (trimmed.length > MAX_ADDRESS_LENGTH) {
    throw new EmailAddressError('The address exceeds 254 characters.', 'TOO_LONG');
  }
  // Control characters and internal whitespace: header-injection material (a
  // CR or LF reaching an SMTP client adds headers), and never legitimate in an
  // address someone typed.
  // eslint-disable-next-line no-control-regex
  if (/[\u0000-\u0020\u007f]/.test(trimmed)) {
    throw new EmailAddressError('The address contains illegal characters.', 'MALFORMED');
  }

  const at = trimmed.lastIndexOf('@');
  if (at <= 0 || at === trimmed.length - 1) {
    throw new EmailAddressError('The address needs a local part and a domain.', 'MALFORMED');
  }

  const localPart = trimmed.slice(0, at);
  const domain = trimmed.slice(at + 1);

  if (localPart.length > MAX_LOCAL_PART_LENGTH) {
    throw new EmailAddressError('The local part exceeds 64 characters.', 'LOCAL_PART_TOO_LONG');
  }
  // Quoted local parts (`"a b"@example.de`) are legal and effectively unused.
  // They are rejected rather than supported because every downstream consumer —
  // the mailer, the CSV an astrologer exports — would need to handle the
  // quoting, and one of them would not.
  if (localPart.startsWith('"') || localPart.includes('..')) {
    throw new EmailAddressError('The local part is not a supported form.', 'MALFORMED');
  }
  if (localPart.startsWith('.') || localPart.endsWith('.')) {
    throw new EmailAddressError('The local part may not start or end with a dot.', 'MALFORMED');
  }
  if (!/^[^@[\]<>(),;:\\"]+$/.test(localPart)) {
    throw new EmailAddressError('The local part contains illegal characters.', 'MALFORMED');
  }

  assertValidDomain(domain);

  return trimmed.toLowerCase();
}

/**
 * A domain must have at least two labels and a non-numeric last label.
 *
 * Address literals (`user@[192.0.2.1]`) are rejected: they are valid SMTP and a
 * near-certain sign of a typo or a probe in a consumer sign-up form.
 */
function assertValidDomain(domain: string): void {
  if (domain.length > 253 || domain.startsWith('[')) {
    throw new EmailAddressError('The domain is not a supported form.', 'DOMAIN_INVALID');
  }
  const labels = domain.split('.');
  if (labels.length < 2) {
    throw new EmailAddressError('The domain needs at least two labels.', 'DOMAIN_INVALID');
  }
  for (const label of labels) {
    if (label.length === 0 || label.length > MAX_DOMAIN_LABEL_LENGTH) {
      throw new EmailAddressError('A domain label has an illegal length.', 'DOMAIN_INVALID');
    }
    if (label.startsWith('-') || label.endsWith('-')) {
      throw new EmailAddressError('A domain label may not start or end with a hyphen.', 'DOMAIN_INVALID');
    }
    if (!/^[\p{L}\p{N}-]+$/u.test(label)) {
      throw new EmailAddressError('A domain label contains illegal characters.', 'DOMAIN_INVALID');
    }
  }
  const topLevel = labels[labels.length - 1] as string;
  if (/^\d+$/.test(topLevel)) {
    throw new EmailAddressError('The top-level domain may not be numeric.', 'DOMAIN_INVALID');
  }
}

/** [normaliseEmail] without the throw, for call sites that only need a verdict. */
export function isValidEmail(raw: string): boolean {
  try {
    normaliseEmail(raw);
    return true;
  } catch {
    return false;
  }
}

/** The part before the `@` of an already-normalised address. */
export function localPartOf(normalisedEmail: string): string {
  return normalisedEmail.slice(0, normalisedEmail.lastIndexOf('@'));
}
