# 0003. Compute charts on the client and upload snapshots

**Status:** Accepted
**Date:** 2026-08-01

## Context

Given ADR-0002, the backend cannot compute charts. But orders, reports and the astrologer
console all need chart data.

## Decision

The client computes the complete dataset — D1, all divisional charts, dashas, yogas and
career significators — and uploads it as JSON with the order. The backend stores it as an
immutable snapshot alongside the engine version and rule-set version.

The astrologer console recomputes in-browser via WASM when an astrologer changes ayanamsa or
tests a rectified birth time.

## Consequences

Snapshots were required anyway for reproducibility and dispute resolution, so this is close
to free. Server load drops. A client on an old app version may produce charts from an older
engine version — hence storing the version, and hence the cache key including it.

Requires the mobile FFI build and the console WASM build to produce byte-identical output.
That is verified by a shared test-vector suite in the engine repository, and it is not
optional: an astrologer writing from one and a customer reading the other must see the same
chart.
