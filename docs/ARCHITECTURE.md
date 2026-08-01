# Architecture

## Principles

1. **The client computes; the server records.** Chart computation is client-side for
   licensing reasons (see `AGPL-BOUNDARY.md`) and stays there.
2. **Payment and fulfilment are decoupled.** Stripe webhooks are the only source of truth
   for "paid". Nothing is fulfilled optimistically.
3. **Paid orders are immutable snapshots.** Birth data, questions, industry selection,
   computed chart, engine version and rule-set version are frozen at payment.
4. **EU-only data plane.** All personal data at rest in Frankfurt. No processor without a
   signed DPA.
5. **Modular monolith first.** At launch volumes, one well-structured deployable plus a PDF
   worker beats a constellation of services.

## Shape

```
Flutter app          Astrologer console        Admin console
  (FFI engine)         (WASM engine)
      │                     │                       │
      └─────────── CDN + WAF + rate limit ──────────┘
                          │
                     API Gateway
                          │
   ┌──────────────────────────────────────────────────┐
   │ Identity · Profile · Chart snapshots · Career    │
   │ Orders · Payments · Assignment · Reports         │
   │ Notifications · Admin                            │
   └──────────────────────────────────────────────────┘
        │              │                │
   Job queue      PDF render     LLM drafting (EU)
        │
   PostgreSQL (encrypted) · Redis · S3 · Stripe
```

## Modules under `api/`

| Module | Owns |
|---|---|
| `identity` | Accounts, sessions, social sign-in, deletion |
| `profile` | Chart subjects, birth data (encrypted), geocoding |
| `chart` | Snapshot storage and retrieval. **Storage only — no computation.** |
| `career` | Industry selections, rule-set versions, generated analyses |
| `order` | Lifecycle state machine, SLA timers, escalation |
| `payment` | Stripe integration, webhooks, invoices, refunds, VAT |
| `assignment` | Astrologer routing by language, specialisation, capacity |
| `report` | Draft versions, QA review, approval, publication |
| `notification` | Push, email, in-app; consent enforcement |
| `admin` | Operations tooling, audit log |

## Order state machine

```
DRAFT → PAYMENT_PENDING → PAID → ASSIGNED → IN_ANALYSIS → IN_REVIEW → DELIVERED → CLOSED
```

Branches: `REFUND_REQUESTED → REWORK | REFUNDED`, `SLA_BREACHED`, `CANCELLED`.

Every transition is recorded in `order_events` with actor and timestamp.

## Data

| Concern | Approach |
|---|---|
| Birth data | Envelope encryption via KMS; decryption role-gated and logged |
| Chart snapshots | Immutable JSONB keyed by engine version |
| Career analyses | Stored with the rule-set version that produced them |
| Reports | Versions in Postgres, final PDFs in S3 with signed expiring URLs |
| Cache, locks | Redis |
| Audit | Append-only `audit_log` |

## Retention

Birth data deleted on account deletion. Invoices retained 10 years (AO/HGB). Logs 90 days.
Analytics 14 months. Purge jobs automated with an audit trail.
