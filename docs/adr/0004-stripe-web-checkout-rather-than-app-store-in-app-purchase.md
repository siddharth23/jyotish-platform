# 0004. Stripe web checkout rather than App Store in-app purchase

**Status:** Accepted
**Date:** 2026-08-01

## Context

The paid product is a EUR 11 expert kundali evaluation — a written analysis produced by a
human astrologer within 72 hours.

Apple requires in-app purchase for digital content consumed within an app, at 15-30%
commission. On EUR 11 that is EUR 1.65-3.30, against a contribution margin of EUR 3.92.

## Decision

Use Stripe web checkout with SEPA Direct Debit, Klarna, PayPal, cards, Apple Pay and Google
Pay. The product is a human professional service, which normally falls outside the IAP
requirement.

State this explicitly in App Review notes.

## Consequences

Margin preserved. German buyers get the payment methods they actually use — PayPal and SEPA
far outrank cards in this market.

Carries App Review risk: the framing must be defensible and clearly presented. Requires legal
confirmation before submission (see the launch checklist).

Note that subscriptions, if introduced later, **do** require IAP. This decision covers one-off
professional services only.
