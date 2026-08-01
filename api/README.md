# API

Proprietary backend. Modular monolith.

## The one rule

**This service must never compute an astrological chart.**

It receives computed chart JSON from clients and stores it. It does not import the engine
package, does not run the WASM build, and does not invoke the native libraries.

Doing any of those would place this entire repository under AGPL-3.0 and oblige us to publish
its source. `scripts/check_agpl_boundary.sh` fails the build if you try.

See `docs/AGPL-BOUNDARY.md`.

## Modules

```
src/modules/
  identity/      Accounts, sessions, deletion
  profile/       Chart subjects, encrypted birth data
  chart/         Snapshot STORAGE. No computation.
  career/        Industry selections and generated analyses
  order/         Lifecycle state machine, SLA timers
  payment/       Stripe, webhooks, invoices, VAT, refunds
  assignment/    Astrologer routing
  report/        Draft versions, QA review, publication
  notification/  Push, email, in-app
  admin/         Operations tooling, audit log
```

## Payments

Fulfilment is driven exclusively by verified Stripe webhooks. A client-side success signal is
never sufficient — SEPA settles asynchronously, and a client signal is forgeable. All handlers
are idempotent.
