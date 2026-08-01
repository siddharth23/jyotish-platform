# Career module

Stores industry selections and the career analyses generated on the client, along with the
rule-set version that produced each one.

## Constraint (ADR-0005)

Personal use only. This module must never expose:

- A B2B or partner API
- Bulk or multi-subject analysis
- Ranking or comparison of one person against another
- Any endpoint that would let an employer assess a candidate

Those capabilities would bring the product into EU AI Act high-risk employment scope, engage
GDPR Article 22, and create AGG discrimination exposure.

Do not add them without specialist legal counsel.
