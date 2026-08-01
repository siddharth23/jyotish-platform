# Compliance

Operational summary. Not legal advice — each item below needs professional sign-off before
launch.

## GDPR

| Obligation | Where it lives |
|---|---|
| Consent (GDPR + TTDSG) | CMP fires before any analytics or crash SDK; reject-all as prominent as accept-all |
| Right of access / portability | Automated export, machine-readable, within 30 days |
| Right to erasure | Automated purge; in-app account deletion (also required by Apple 5.1.1(v)) |
| Art. 30 record | Maintained; reviewed annually |
| DPIA | Required — birth data plus career profiling plus health-adjacent questions |
| Art. 28 processors | Signed DPA with Stripe, cloud, CMP, analytics, email, LLM vendor; AVV with every astrologer |
| Art. 32 security | Field-level encryption, access logging, TLS 1.3, KMS key rotation |
| Breach notification | 72 hours from awareness. Runbook in `RUNBOOKS.md`. |

## German consumer law

- **Impressum** per DDG §5.
- **AGB, Datenschutzerklärung, Widerrufsbelehrung** plus the model withdrawal form, in German.
- **Right of withdrawal.** The buyer must explicitly consent that work begins before the
  14-day period expires and acknowledge losing the right. Captured with a timestamp at
  checkout and repeated in the confirmation email. Without valid consent, work does not start.
  Incorrect or missing Widerrufsbelehrung extends the window to 12 months and 14 days.

## Tax

- 19% German VAT on the EUR 11 price (net EUR 9.24).
- Customer country determined by two non-contradictory pieces of evidence.
- Cross-border EU B2C sales above EUR 10,000/year require destination-country VAT via OSS.
- Gapless invoice numbering, 10-year GoBD-compliant archive.

## App stores

- Privacy nutrition labels (Apple) and Data Safety form (Play), completed accurately.
- Age rating 12+ with entertainment framing consistent across app, listing and screenshots.
- DSA trader status verification — we sell, so this applies.
- Guideline 4.3 differentiation package in reviewer notes: human expert marketplace, career
  analysis, German-language Vedic depth, open-source engine.

## Career feature

Personal use only. See ADR-0005. No employer-facing mode without specialist counsel.

## Content

No medical, legal, financial or pregnancy predictions — enforced by the astrologer style
guide and an intake filter on user questions. No claims about earnings or hiring outcomes in
career content.
