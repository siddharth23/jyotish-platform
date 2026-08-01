# Runbooks

## Severity

| Level | Definition | Response |
|---|---|---|
| P1 | Payments down, data breach suspected, or total outage | Immediate, page on-call |
| P2 | Fulfilment blocked, SLA at risk across many orders | Within 1 hour |
| P3 | Degraded feature, single-order issues | Next business day |
| P4 | Cosmetic | Backlog |

## Payment processing outage

1. Confirm against the Stripe status page.
2. Enable the paid-flow kill switch (feature flag) so users see a clear message rather than
   a failure.
3. Verify no orders were created without a confirmed payment — the webhook path should make
   this impossible, but check.
4. On recovery, replay the webhook dead-letter queue. Handlers are idempotent.
5. Contact anyone who attempted payment during the window.

## PDF generation backlog

1. Check queue depth and worker health.
2. Scale workers. Generation is CPU-bound and stateless.
3. Identify orders at risk against the 72-hour SLA.
4. If the SLA will breach, notify customers proactively with a goodwill credit. Do not wait
   for them to ask.

## SLA breach risk

Automatic warnings fire at 48h, 60h and 70h; auto-reassignment at 66h. If manual intervention
is needed: reassign in admin, extend only with a recorded reason, and inform the customer
before the deadline rather than after.

## Suspected data breach

**The GDPR 72-hour clock starts the moment you become aware. Not when you finish
investigating.**

1. Contain — revoke credentials, isolate the affected system.
2. Preserve evidence. Do not clean up before capturing state.
3. Notify the Tech Lead and DPO immediately.
4. Assess scope: which data subjects, which categories, what quantity.
5. Notify the supervisory authority within 72 hours if there is a risk to rights and freedoms.
6. Notify data subjects if the risk is high.
7. Post-incident review within one week.

## Chart accuracy report from a user

1. Get the exact inputs — date, time, coordinates, timezone, ayanamsa, house system.
2. Reproduce against astro.com with identical settings. Most reports are ayanamsa or house
   system mismatches rather than bugs.
3. If genuine, check whether the mobile FFI and console WASM builds agree. Divergence is a
   high-severity correctness bug.
4. Add a vector to the engine repository's golden-master suite before fixing.
5. Identify affected delivered reports and decide on reissue.
