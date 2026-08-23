# Identity module

Accounts, credentials, sessions, and the flows that prove someone controls an email address.
US-011 and US-016.

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
| `session.ts` | Access tokens, rotating refresh tokens and revocation (US-016). |

## What is deliberately elsewhere

- **Token storage on the device** — `app/lib/features/auth/`. The Keychain and the Android Keystore
  are the client's problem; this module never sees where a token is kept.
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
- `InMemorySessionRepository` must persist, or every deploy signs every user out. Its `rotate` must
  become a conditional `UPDATE ... WHERE rotated_at IS NULL` in the same transaction as the insert —
  see the note on reuse detection above.

The account table needs a **unique** constraint on `email_index` and field-level encryption on the
address itself.

## Sessions (US-016)

`session.ts` issues an HMAC-signed access token (15 minutes, stateless) alongside a rotating
refresh token (60 days idle, 180 days absolute). Three things about it are load-bearing:

**Refresh-token reuse is treated as theft.** Every refresh retires the token presented and mints a
new one in the same family. Presenting an already-retired token proves the token was copied, so the
whole family is revoked and the user must log in again. This is why `SessionRepository.rotate` must
be atomic in the persistent implementation — a read-then-write lets a thief's refresh and the real
device's refresh both succeed, which is exactly what reuse detection exists to catch.

**Clients must refresh single-flight.** The direct consequence of the above: a client that fires one
refresh per in-flight request presents the same token several times and signs the user out of every
device. `app/lib/features/auth/session_controller.dart` collapses concurrent callers onto one
refresh for this reason. Any other client — the astrologer console, the admin console — has to do
the same.

**Revocation lags by up to the access-token lifetime.** Access tokens are verified by signature
alone, with no store read, so "sign out all devices" (AC3) and password-change invalidation (AC4)
stop refreshes immediately but leave an already-issued access token working until it expires. That
window *is* `ACCESS_TOKEN_TTL_MS`. Shortening it is the only lever; a store read per request is the
alternative, and it puts the session table on the critical path of every call.

`IdentityService` revokes through the `SessionRevoker` port, so a completed password reset tears
down sessions without the identity module knowing how sessions are stored.

## Configuration

`IDENTITY_EMAIL_INDEX_PEPPER` — at least 32 characters, from the secret store, never in the
database it protects. Rotating it means recomputing every index from the decrypted addresses.

`IDENTITY_ACCESS_TOKEN_KEY` — at least 32 bytes, from the secret store. Rotating it invalidates
every outstanding access token, which is the break-glass control for a suspected key compromise:
within fifteen minutes every client is forced through refresh, where the session store gets its say.

## Licensing

No engine code, no chart computation. See `docs/AGPL-BOUNDARY.md`.
