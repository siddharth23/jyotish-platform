# 0001. Record architecture decisions

**Status:** Accepted
**Date:** 2026-08-01

## Context

Decisions with long-lived consequences get made in chat and forgotten. Six months later
nobody remembers whether something was deliberate or accidental.

## Decision

Record significant decisions as numbered ADRs in `docs/adr/`. An ADR is warranted when a
decision is expensive to reverse, constrains future work, or would otherwise be re-litigated.

Format: Context, Decision, Consequences, Alternatives considered. Superseded ADRs are marked,
never deleted.

## Consequences

Slight overhead per decision. Considerably less overhead than rediscovering the reasoning.
