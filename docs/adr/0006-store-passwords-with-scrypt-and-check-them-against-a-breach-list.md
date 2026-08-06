# 0006. Store passwords with scrypt and check them against a breach list

**Status:** Accepted
**Date:** 2026-08-06

## Context

US-011 introduces email and password accounts. Two of its decisions are expensive to reverse.

The first is the key derivation function. A password hash cannot be upgraded offline: the plaintext
exists only during a login, so migrating to a different algorithm means verifying with the old one
and immediately rehashing with the new one, for each user, as they return. Accounts that never come
back keep the original hash indefinitely. Whatever is chosen now is still in the database years
later.

The second is the password rule set. Rules can be tightened for new passwords at any time, but
every password already accepted under a weaker rule stays until its owner changes it.

Argon2id is OWASP's first recommendation. It requires a native dependency in the login path. This
service currently has no runtime dependencies at all.

## Decision

**scrypt from the Node standard library**, at N=65536, r=8, p=2 — one of OWASP's listed parameter
pairs, roughly 64 MiB per verification. Parameters are stored inside each encoded hash
(`scrypt$N=65536,r=8,p=2$salt$key`) and re-read on verification, and `needsRehash` triggers an
upgrade on the next successful login. Moving to Argon2id later is a new prefix, not a migration.

Parameters read out of storage are bounds-checked. A row claiming N=2^30 must not turn one login
into an out-of-memory kill, and a row rewritten with N=2 must not silently downgrade that account.

**No pepper.** Rotating one requires rehashing every password, which requires plaintexts we do not
have, so in practice it is never rotated — and an unrotatable secret present on every application
host buys less than it appears to. (The blind index over email addresses *does* use a pepper,
because that value can be recomputed from the stored ciphertext.)

**Length and a blocklist, no composition rules**, per NIST SP 800-63B: a ten-character minimum, a
breach-list check, and rejection of single-repeated and sequential strings, the service's own name
and the account's own address. No "must contain an uppercase letter and a symbol", which produces
`Passwort1!` rather than entropy and pushes people towards reuse.

The breach list is queried **by hash prefix**: the interface takes five hex characters of a SHA-1
and returns the matching suffixes. k-anonymity is therefore structural — an implementation that sent
a whole password, or a whole hash, to a third party would have to fight the signature to do it. The
default implementation is local, which avoids the processor question entirely. When the list cannot
answer, the password is **rejected** by default: an outage ends, and a weak password chosen during
one does not.

## Consequences

64 MiB per concurrent verification is the number that decides how many logins a host survives. Fifty
simultaneous logins is 3 GiB. An expensive KDF reachable unauthenticated and unmetered is a memory
exhaustion primitive, so the per-client rate limiter in `login_throttle.ts` is not an optional
hardening measure — it is a precondition for these parameters, and lowering it requires re-doing the
arithmetic.

Accepting the ten-character minimum and no composition rules means a support conversation with
anyone who expects the familiar rules, and it means the breach list is doing work that complexity
requirements are usually credited with.

Defaulting to reject during a breach-list outage means the list is on the sign-up critical path.
A local list makes that acceptable; adopting a remote one would change the availability profile and
needs the DPA question answered first.

Raising the scrypt parameters is safe and cheap. Lowering them is not: existing hashes keep their
recorded parameters, so a reduction only applies going forward and produces a database with two
strengths in it.
