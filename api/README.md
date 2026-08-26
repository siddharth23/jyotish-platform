# API

Proprietary backend. Modular monolith.

## The one rule

**This service must never compute an astrological chart.**

It receives computed chart JSON from clients and stores it. It does not import the engine
package, does not run the WASM build, and does not invoke the native libraries.

Doing any of those would place this entire repository under AGPL-3.0 and oblige us to publish
its source. `scripts/check_agpl_boundary.sh` fails the build if you try.

See `docs/AGPL-BOUNDARY.md`.

## TypeScript version

Pinned to **6.x**, not 7. `typescript-eslint` declares `typescript >=4.8.4 <6.1.0` as a peer
range, so TypeScript 7 fails `npm install` with ERESOLVE before any code runs. Bumping past 6
means losing TypeScript-aware linting entirely — including the `no-explicit-any` and
`explicit-function-return-type` rules this repo requires — so the pin stays until
typescript-eslint ships support (typescript-eslint#10940).

`tsconfig.json` sets `"types": ["node"]` explicitly. TypeScript 6 stopped including every
installed `@types/*` package by default, and without it `Buffer` and `node:crypto` are unresolved
across the identity module. Removing that line looks harmless and breaks the build.

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
