# Identity module

Accounts, credentials and the flows that prove someone controls an email address. US-011.

## What is here

| File | Purpose |
|---|---|
| `email_address.ts` | Normalisation and validation. One mailbox must map to one account. |
| `email_index.ts` | Keyed blind index, so an encrypted address column can still be searched. |
| `password_policy.ts` | Ten-character minimum and the breach-list check (AC2). |
| `password_hasher.ts` | scrypt, with the parameters recorded inside each hash. |
| `secret_token.ts` | Verification and reset links: hashed at rest, single use, expiring (AC1, AC4). |
| `login_throttle.ts` | Per-account lockout and per-client rate limiting (AC3). |
| `account.ts` | The account record and its storage port. |
| `identity_service.ts` | The flows that compose the above. |

## What is deliberately elsewhere

- **Sessions and tokens** — US-016. A successful login returns an `AuthenticatedPrincipal` and
  stops. The `SessionRevoker` port is the seam; password reset already calls it, so US-016 AC4
  ("sessions invalidated on password change") is a matter of supplying an implementation.
- **Social sign-in** — US-012. `Account.passwordHash` is nullable for exactly this reason.
- **Email bodies** — the `notification` module. This module hands over a recipient, a locale and a
  secret. German is the source language and the strings are ICU resources, not literals in `.ts`.
- **Ordering rules** — whether an unverified address may buy a report is the `order` module's
  decision. This module reports the state and does not enforce a policy on it.

## Account enumeration

Every flow that takes an email address answers identically whether or not that address is
registered. This is treated as a requirement rather than a refinement: an endpoint that confirms
membership discloses that a named person uses a Vedic astrology service, and the inferences that
follow — belief, ethnicity — are GDPR Article 9 special categories.

The mechanisms, each with a test:

- Sign-up with a taken address returns `accepted`, mails the existing owner a notice, and creates
  nothing. It also still pays for a password hash, so the two branches cost the same wall-clock time.
- A login against a missing account still spends a full verification (`spendVerificationTime`).
- Failed attempts are counted for addresses with no account, so lockout does not distinguish either.
- `requestPasswordReset` resolves the same way in every case and returns nothing.

## Placeholders that must be replaced before launch

There is no database in this service yet, so `InMemoryAccountRepository`,
`InMemoryTokenRepository` and `InMemoryThrottleStore` are placeholders. Each is documented at its
definition. Two of them have consequences worth repeating:

- The token repository's `markConsumed` must become a conditional update on `consumed_at IS NULL`
  that checks the affected row count. A read-then-write lets two clicks of one reset link both
  succeed.
- The throttle store must move to Redis. In-process counters multiply the effective limit by the
  number of application instances.

The account table needs a **unique** constraint on `email_index` and field-level encryption on the
address itself.

## Configuration

`IDENTITY_EMAIL_INDEX_PEPPER` — at least 32 characters, from the secret store, never in the
database it protects. Rotating it means recomputing every index from the decrypted addresses.

## Licensing

No engine code, no chart computation. See `docs/AGPL-BOUNDARY.md`.
