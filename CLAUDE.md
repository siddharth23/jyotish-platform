# CLAUDE.md — jyotish-platform

Context for AI coding assistants working in this repository. Read this before making changes.

---

## The product

**Jyotish DE** — a Vedic (sidereal) astrology application for the German market.

| | |
|---|---|
| Target market | Germany primary; Austria and Switzerland secondary |
| Free features | Kundali chart generation, auto-generated insight cards, Career & Industry Fit |
| Paid product | Expert kundali evaluation — **€11.00 incl. 19% German VAT**, written by a human astrologer, delivered as a PDF within 72 hours |
| Platform | Flutter app (iOS + Android), plus web consoles for astrologers and admin |
| Payments | Stripe web checkout — SEPA, Klarna, PayPal, cards, Apple/Google Pay. **Not** App Store IAP |
| Language | German first. Content is authored in German and translated to English, never the reverse |

Unit economics per order: €11.00 gross → €9.24 net after VAT → **€3.92 contribution margin** after
astrologer fee (€4.75), payment processing (€0.42) and infrastructure (€0.15). The margin is thin,
which is why astrologer time is the cost to optimise.

---

## THE RULE THAT MATTERS MOST

> **Swiss Ephemeris runs on the client. Never on the server.**

The calculation engine (`../jyotish-engine`, also on GitHub) embeds Swiss Ephemeris under
**AGPL-3.0** — the free edition, not the paid Professional licence.

AGPL section 13 requires that users interacting with the software *over a network* be offered its
complete source. If any server-side code here links to or invokes the engine, **this entire
proprietary platform becomes disclosable** — orders, payments, career rule sets, content, all of it.

**Therefore:**

- Flutter app → Dart FFI → engine runs on the user's device ✅
- Astrologer console → WebAssembly → engine runs in the browser ✅
- Backend → receives computed chart JSON, stores it, never computes ✅
- Anything under `api/` importing the engine ❌

`scripts/check_agpl_boundary.sh` runs in CI and on pre-commit. It greps server-side paths for engine
imports and Swiss Ephemeris symbols. **Do not delete, skip or weaken it.** If it blocks something,
escalate rather than working around it.

Full reasoning: `docs/AGPL-BOUNDARY.md` and `docs/adr/0002-*.md`.

**If you find yourself wanting server-side computation** — for a migration, a batch job, an admin
repair tool — stop. Push it to a client, or escalate. The correct fix at that point is usually to buy
the Professional licence (CHF 750), not to breach the boundary.

---

## The second constraint: the career feature is personal-use only

The Career & Industry Fit feature analyses a user's own chart against an industry they select.

**It must never become employer-facing.** No B2B API, no bulk analysis, no multi-candidate
comparison, no ranking one person against another.

An astrology tool used by an employer to assess a candidate engages three separate regimes:

- **EU AI Act** — recruitment/candidate-selection is high-risk under Annex III (conformity
  assessment, technical documentation, human oversight, registration)
- **GDPR Article 22** — automated decisions with significant effects; a nominal human reviewer does
  not cure it
- **AGG** — birth date is a direct age proxy; birth-data-derived candidate scoring is indefensible
  under a discrimination claim, with us as the tool vendor

See `docs/adr/0005-*.md`. Do not reintroduce an employer-facing mode without specialist counsel.

---

## Architecture

```
Flutter app (FFI engine)   Astrologer console (WASM engine)   Admin console
            └──────────── CDN + WAF + rate limit ────────────┘
                                  │
                            API Gateway
                                  │
    Identity · Profile · Chart snapshots · Career · Orders · Payments
    Assignment · Reports · Notifications · Admin
                                  │
    Job queue · PDF render · LLM drafting (EU-hosted)
                                  │
    PostgreSQL (encrypted) · Redis · S3 · Stripe        [all eu-central-1]
```

**Key patterns**

- **Client computes, server records.** The client computes the full chart dataset — D1, all
  divisionals, dashas, yogas, career significators — and uploads it as JSON with the order.
- **Payment and fulfilment are decoupled.** Verified Stripe webhooks are the only source of truth
  for "paid". SEPA settles asynchronously and client-side success signals are forgeable. All handlers
  idempotent.
- **Paid orders are immutable snapshots.** Birth data, questions, industry selection, chart, engine
  version and rule-set version frozen at payment, for reproducibility and dispute resolution.
- **EU-only data plane.** All personal data at rest in Frankfurt. No processor without a signed DPA.
- **Modular monolith.** One deployable plus a PDF worker. Do not split into microservices.

Order lifecycle:
`DRAFT → PAYMENT_PENDING → PAID → ASSIGNED → IN_ANALYSIS → IN_REVIEW → DELIVERED → CLOSED`
Branches: `REFUND_REQUESTED → REWORK | REFUNDED`, `SLA_BREACHED`, `CANCELLED`.

---

## Layout

```
app/                  Flutter application — feature-first folders
api/                  Backend — modular monolith, NEVER computes charts
console-astrologer/   Astrologer web console (loads WASM engine in-browser)
console-admin/        Internal ops and support console
shared/              Types and contracts (server-consumed — keep AGPL-free)
infra/                Terraform, eu-central-1
scripts/              Build and guard scripts
docs/                 Architecture, ADRs, compliance, runbooks
```

`api/src/modules/`: `identity` · `profile` · `chart` (storage only) · `career` · `order` ·
`payment` · `assignment` · `report` · `notification` · `admin`

---

## Working conventions

**Branches** — `feature/US-XXX-short-description`, referencing the backlog story ID.

**Commits** — Conventional Commits with the story ID:
```
feat(career): add industry selection screen (US-130)
fix(payments): make webhook handler idempotent (US-076)
```

**Commit authorship — important:** commits are authored solely by Siddharth Kala. Do **not** add
`Co-Authored-By` trailers, "Generated with" lines, or any AI-assistant attribution to commit
messages, code comments, PR descriptions or documentation.

**Code standards**

| Area | Standard |
|---|---|
| Dart | `dart format`; `dart analyze --fatal-infos` clean |
| TypeScript | ESLint + Prettier, `strict`, no `any` |
| Tests | 70%+ on engine integration, career rules, payments |
| Logging | **Never** log birth data, names, emails or payment details |
| Strings | No hardcoded UI strings — German is externalised via ICU, ~30% longer than English |

**Personal data** — birth data is sensitive. Field-level encryption at rest, never in logs or
telemetry, never in test fixtures (use synthetic data), admin access justified and audit-logged.

---

## Commands

```bash
./scripts/bootstrap.sh              # toolchain check, .env, pre-commit hooks
./scripts/dev.sh                    # local stack
./scripts/check_agpl_boundary.sh    # must pass before every commit
./scripts/check_secrets.sh          # must pass before every commit

cd app && flutter analyze && flutter test
cd api && npm run lint && npm test
```

---

## Definition of done

- [ ] Story acceptance criteria met (see the backlog workbook)
- [ ] Tests written and passing
- [ ] `check_agpl_boundary.sh` passing
- [ ] `check_secrets.sh` passing
- [ ] No personal data in logs, telemetry or fixtures
- [ ] German strings externalised
- [ ] ADR added if a consequential decision was made
- [ ] No AI-assistant attribution anywhere

---

## Planning artefacts

- `docs/planning/Jyotish_DE_Backlog_v3.xlsx` — 16 epics, 113 stories with acceptance criteria,
  release plan, launch checklist, vendors and costs, unit economics. **Story IDs referenced in
  branches and commits come from here.**
- `docs/planning/Jyotish_DE_Architecture_v3.md` — full architecture rationale
- `docs/adr/` — five founding decisions

Timeline: 806 MVP story points, ~14 two-week sprints, **30 weeks to public launch**.

---

## Open items blocking launch

These are known and deliberate, not oversights:

1. **Software-licensing lawyer must review the AGPL boundary** (~€1,500) — US-030. Highest priority.
2. **German lawyer** for AGB, Datenschutzerklärung, Widerrufsbelehrung, DPIA (~€4,500). 4–8 week lead
   time and it gates the Stripe account.
3. **Employment lawyer** to review the career feature's personal-use terms (~€800).
4. **5–8 vetted astrologers under contract with AVVs** before launch, or the 72h SLA breaks.
5. **External penetration test** (~€8,000), all critical/high findings closed.
6. **Apple Guideline 4.3 differentiation package** — Apple rejects generic astrology apps. Lead with
   the human expert marketplace, career analysis, German-language Vedic depth, open-source engine.
7. Withdrawal-right consent at checkout — the buyer must explicitly agree work starts before the
   14-day period ends. Without correct Widerrufsbelehrung the window becomes 12 months + 14 days.

---

## Things that will silently break

- **Timezone and DST resolution.** One hour of error shifts the ascendant a full sign. German double
  summer time 1945–49, no DST 1950–79, India pre-1955 at +05:53:20. Resolve from IANA using
  coordinates *and* historical date — never the user's current timezone.
- **FFI and WASM divergence.** The astrologer writes a report from one build, the customer reads the
  chart from the other. They must produce byte-identical output. Shared test vectors in the engine
  repo enforce this.
- **Ayanamsa.** Default Lahiri/Chitrapaksha. Always display which is active.
- **Missing Android ABI.** Doesn't fail the build; crashes on devices you don't own.
