# The AGPL Boundary

**Status:** Accepted · **Date:** 2026-08-01 · **Owner:** Tech Lead

**This is the most important document in the repository. Read all of it.**

---

## The rule

> Swiss Ephemeris runs on the client. Never on the server.

## Why

The calculation engine ([`sidkalaapcoa/jyotish-engine`](https://github.com/sidkalaapcoa/jyotish-engine))
embeds Swiss Ephemeris under **AGPL-3.0**, not the paid Professional licence.

AGPL section 13 — the network clause — requires that users who interact with the software
over a network be offered its complete corresponding source. A backend that computes charts
and serves them to the app triggers this: every customer becomes such a user, and the
operator must publish the source of the work they interact with.

In this product that would mean publishing the order system, payment integration, astrologer
marketplace, career rule sets and all proprietary content.

Client-side execution avoids it. Software running on the user's own device or in their own
browser is not a network service they interact with remotely.

## What this means concretely

**Permitted**

- The Flutter app links the engine via FFI and computes charts on-device
- The astrologer console loads the WASM build and computes in the browser
- Clients POST computed chart JSON to the API
- The API stores, queries, renders and bills against that JSON freely

Computed data is not a derivative work of the program that produced it.

**Forbidden anywhere under `api/`**

- Importing, requiring or otherwise depending on the engine package
- Running the WASM build under Node.js or any server runtime
- Calling the native libraries from a job, worker or script
- Shipping the engine inside any server container image
- Writing a "small" server-side chart utility for a migration or admin fix

That last one is how this gets breached. It always looks harmless.

## How the astrologer console works without server computation

The client computes the complete dataset — D1, all divisionals, dashas, yogas, career
significators — and uploads it as JSON with the order (US-039). It is snapshotted anyway for
reproducibility and dispute resolution, so this costs nothing.

When an astrologer needs to recompute — a different ayanamsa, a rectified birth time — the
console does it in-browser via WASM. The backend still never computes.

## Enforcement

`scripts/check_agpl_boundary.sh` runs on every pull request. It greps server-side directories
for engine imports and Swiss Ephemeris symbols and fails the build on a match.

It is a blunt instrument. It will not catch a determined workaround, and it is not a
substitute for understanding the rule. It exists to catch the accidental import at 2am.

**Do not delete, skip or weaken this check.** If it blocks something you believe is
legitimate, that belief needs review before the check does.

## If you think you need server-side computation

You probably do not. Push the computation to a client and upload the result.

If you genuinely do — a bulk recalculation across historical orders, for instance — the
options are:

1. **Buy the Swiss Ephemeris Professional licence** (CHF 750 one-off). Removes the constraint
   entirely and permits server-side computation. Almost always the right answer at that point.
2. Implement the needed calculation independently against a permissively licensed ephemeris.
3. Drive it through a controlled client.

Escalate to the Tech Lead. Do not decide alone.

## Outstanding

This boundary must be reviewed by a software-licensing lawyer before public launch (US-030).
Nothing here is legal advice. The reasoning is conventional and sound, but the consequence of
being wrong is publishing the entire commercial codebase.
