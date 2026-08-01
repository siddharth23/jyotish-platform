# 0002. Use the AGPL edition of Swiss Ephemeris with a client-side boundary

**Status:** Accepted
**Date:** 2026-08-01

## Context

Swiss Ephemeris is dual-licensed: AGPL-3.0, or a Professional licence at CHF 750 one-off.
This is a commercial product with proprietary business logic and content.

Using the AGPL edition server-side would oblige us to publish the entire platform under AGPL.

## Decision

Use the AGPL edition, and confine it to client-side execution — Dart FFI in the mobile app,
WebAssembly in the astrologer console. Publish the engine wrapper as a separate public
repository. No server-side component links to or invokes it.

Enforce with `scripts/check_agpl_boundary.sh` in CI.

## Consequences

**Positive** — no licence fee; chart computation is free, instant and offline; no ephemeris
service to operate; birth data need not leave the device to be computed.

**Negative** — the backend can never compute a chart, which constrains migrations, batch
operations and admin repair tooling. Every engineer must understand a non-obvious rule. The
engine wrapper is public, though it contains no business logic.

**Cost note** — this saves CHF 750 and adds roughly EUR 1,500 in legal review plus ongoing
engineering care. It is close to a wash. Revisit if server-side computation becomes genuinely
necessary; buying the Professional licence at that point is the sane response.

## Alternatives considered

- **Professional licence, CHF 750.** Simplest. Removes the constraint entirely.
- **Permissively licensed engine** (Astronomy Engine, Skyfield). No obligation, but the
  sidereal and Vedic layers would need building and validating from scratch.
- **Open-source the platform.** Rejected: rule sets and content are the differentiation.
