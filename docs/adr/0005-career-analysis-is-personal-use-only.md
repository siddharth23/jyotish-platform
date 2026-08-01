# 0005. Career analysis is personal-use only

**Status:** Accepted
**Date:** 2026-08-01

## Context

The career feature analyses a user's chart against a chosen industry and suggests strengths,
growth areas and suitable roles. An employer-facing version was considered and rejected.

## Decision

The feature is contractually and technically restricted to personal use. No B2B API, no bulk
analysis, no multi-candidate comparison, no ranking of one person against another. The terms
of service prohibit use by employers, recruiters or agencies to assess candidates, stated on
the career page itself rather than buried in the AGB.

## Consequences

Keeps the product out of three separate regimes:

- **EU AI Act** — recruitment and candidate-selection systems are high-risk under Annex III,
  bringing conformity assessment, technical documentation, human oversight and registration
  obligations.
- **GDPR Article 22** — automated decisions with significant effects, which employment
  decisions are. A nominal human reviewer does not cure this.
- **AGG** — birth date is a direct age proxy; birth-data-derived candidate scoring would be
  indefensible under a discrimination claim, with us as the tool vendor.

Forgoes a B2B revenue line. That line would require a compliance programme larger than the
rest of the product combined.

**Do not reintroduce an employer-facing mode without specialist legal counsel.**
