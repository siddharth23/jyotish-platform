# Jyotish DE — Technical Architecture v3

**Vedic astrology app for Germany · free chart + free career fit · €11 expert kundali evaluation**
**Engine: Swiss Ephemeris free AGPL edition, client-side only**
Siddharth Kala · 1 August 2026 · supersedes v1 (paid, licensed engine) and v2 (free hobby app)

---

## 1. What changed and why it matters

Two changes from the original commercial plan:

1. **Free AGPL Swiss Ephemeris instead of the CHF 750 Professional licence.** Saves ~€800, but forces a real architectural decision.
2. **A new free Career & Industry Fit feature** — 101 story points, second-largest epic in the plan, and the strongest free hook in the product.

The recruiter-facing version of the career feature has been dropped. That was the right call, and section 5 explains why.

---

## 2. The AGPL decision — the most important technical choice in this plan

### The problem

AGPL-3.0 section 13 is the network clause: if users interact with your software *remotely over a network*, you must offer them the complete source of that software. A backend that calls Swiss Ephemeris and serves charts to your app triggers this. Your entire commercial platform — orders, payments, astrologer marketplace, career rules — would have to be published.

That's not a theoretical risk. It's the default outcome if you build the obvious architecture.

### The solution: draw the boundary at the client

**Swiss Ephemeris runs client-side only. Your backend never links to it, never bundles it, never calls it.**

```
┌──────────────────────────────────────────────────────────────────────┐
│  PUBLIC — AGPL-3.0 repo "jyotish-engine"                             │
│                                                                       │
│  Swiss Ephemeris C source                                             │
│  Dart FFI bindings (mobile)      WASM build (astrologer console)      │
│  Rule evaluator (generic)                                             │
│                                                                       │
│  → no business logic, no content, no competitive advantage            │
└──────────────────────────────────────────────────────────────────────┘
         │ used by                          │ used by
         ▼                                  ▼
┌─────────────────────────┐      ┌──────────────────────────────────┐
│ Flutter app             │      │ Astrologer console (browser)     │
│ computes chart on-device│      │ computes chart in-browser (WASM) │
└───────────┬─────────────┘      └───────────┬──────────────────────┘
            │  uploads computed chart JSON   │
            ▼                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│  PRIVATE — your proprietary backend                                  │
│                                                                       │
│  Identity · Orders · Payments · Astrologer assignment · SLA           │
│  Report authoring · PDF rendering · Admin · Career rule sets          │
│  Content · Analytics                                                  │
│                                                                       │
│  → never touches Swiss Ephemeris. Stays closed.                      │
└──────────────────────────────────────────────────────────────────────┘
```

**How the astrologer gets a chart without the backend computing one:** the client computes the full dataset — D1, all divisionals, dashas, yogas, career significators — and uploads it as JSON with the order (US-039). It's snapshotted anyway for dispute resolution, so this costs you nothing. The console can also recompute in-browser via WASM when an astrologer wants to change ayanamsa or test a rectified birth time.

### What you must actually do

- Two repos from day one: public `jyotish-engine`, private `platform`. Retrofitting this later is painful (US-001).
- Same test vectors run against both FFI and WASM builds — if they diverge, the astrologer's chart disagrees with the customer's (US-040).
- Licence notice and repo link in the app under About.
- **Pay a software-licensing lawyer ~€1,500 to confirm the boundary.** This is the single cheapest insurance in the project. Getting it wrong means open-sourcing your platform.

Honest note: this saves €800 in licence fees and costs €1,500 in legal review. If you'd rather not think about it at all, the Professional licence at CHF 750 makes the whole question disappear and lets you compute server-side. I've built the plan the way you asked, but that trade is worth knowing.

### Side benefit

Client-side computation means no ephemeris service to run, scale or monitor. Cloud costs drop from ~€650/month to ~€480/month, and charts compute in under 500ms with no network round-trip.

---

## 3. System overview

```
CLIENTS      Flutter app (iOS/Android)  ·  Astrologer console  ·  Admin console
                        │                          │                    │
                    CDN + WAF + rate limiting  →  API Gateway
                        │
BACKEND      Identity · Profile · Career analysis storage · Order & Fulfilment
(private)    Payment & Billing · Astrologer assignment · Report authoring
             Notification · Admin & Support
                        │
SERVICES     Job queue + workers  ·  PDF render  ·  LLM drafting (EU-hosted)
                        │
DATA         PostgreSQL (encrypted, EU)  ·  Redis  ·  S3 (reports)
                        │
EXTERNAL     Stripe · Geocoding · APNs/FCM · Email · CMP
```

Stack: Flutter for mobile, React/Next.js for both consoles, Node/TypeScript or Python for the backend. Everything in `eu-central-1`.

---

## 4. The Career & Industry Fit feature (E16)

### How it works

The user picks an industry. The app computes classical career indicators from their chart and maps them onto that industry.

**Significators computed (US-131), all client-side:**

| Factor | What it indicates |
|---|---|
| 10th house and its lord | Karma, profession, public standing |
| D10 Dashamsha chart | The dedicated career divisional — the core of the analysis |
| Amatyakaraka (Jaimini) | Career-defining planet from the chart's own hierarchy |
| Saturn | Discipline, structure, long-haul work |
| Mercury | Analysis, communication, commerce |
| Jupiter | Advisory, teaching, expertise |
| Sun | Authority, leadership, visibility |
| Mars | Execution, competition, technical craft |
| Venus | Aesthetics, relationships, design |

Each is scored for dignity — exaltation, own sign, debilitation, combustion, retrogression, house placement — then cross-referenced with the running dasha.

**The industry mapping (US-132)** is a versioned JSON rule set, not code. IT maps to Mercury, Rahu, Saturn; healthcare to Moon, Jupiter, Ketu and the 6th house; finance to Mercury, Jupiter and the 2nd/11th houses; skilled trades to Mars and Saturn. Every mapping carries a source note — classical text or your consulting astrologer — and the rule-set version is recorded on every analysis generated. Editable through the CMS with reviewer approval, so your astrology consultant refines it without a release.

**Output:** strengths (US-133), growth areas (US-134), and 3–5 suggested roles ranked by fit (US-135), from a catalogue of 100+ roles using real German job titles.

### The framing is not optional

This is career guidance from an astrology app. Three rules baked into the acceptance criteria:

- **Capability, never destiny.** "Your chart suggests a natural pull towards…" not "you are suited to…"
- **Growth areas are developable, never fixed.** "This may need conscious effort," never "you are bad at this." Every weak significator comes with the classical reasoning for why it isn't a limit.
- **Concrete, not abstract.** "Explaining complex things simply," not "good communication."

Every strength and growth area expands to show the rule that produced it (US-133). That transparency is both the ethical position and your differentiation — you're teaching Jyotish, not dispensing verdicts.

### Why it earns 101 points

It's the strongest free hook you have. Career is what people actually search for, it's shareable, and US-139 routes it straight into the €11 report with career questions pre-filled. Your funnel becomes: install → chart → career analysis → paid evaluation, with the career page as a measurable step (US-111).

---

## 5. Why the recruiter feature had to go

You dropped it, and I want to record why so it doesn't come back later without the context.

An astrology tool used by an *employer* to assess a *candidate* hits three separate legal regimes in the EU:

**EU AI Act.** Recruitment and candidate-selection systems are classified high-risk under Annex III. That brings risk management, data governance, technical documentation, logging, human oversight, conformity assessment, CE marking and EU database registration. High-risk obligations were due 2 August 2026; the Digital Omnibus agreement pushes standalone Annex III systems to 2 December 2027 — but that's a deferral, not a repeal, and formal adoption was still pending as of mid-2026. You'd be building toward a deadline, not avoiding one.

**GDPR Article 22.** Decisions based solely on automated processing with significant effects — which employment decisions are — are prohibited without a narrow legal basis. No member state has authorised automated rejection in recruitment. And a human reviewer doesn't fix it: regulators have held that a reviewer without genuine authority, information and time to decide independently of the algorithm doesn't count as meaningful human involvement.

**AGG (Allgemeines Gleichbehandlungsgesetz).** Birth date is a direct age proxy. A German employer using birth-data-derived scoring to filter candidates would have an indefensible position under an AGG claim, and you'd be the tool vendor.

**What protects you now (US-102):** the terms of service explicitly prohibit use by employers, recruiters or agencies to assess candidates; this is stated on the career page itself, not buried in the AGB; and you expose no B2B API, no bulk analysis and no multi-candidate comparison. Have a German employment lawyer review the wording (~€800). That combination keeps the feature out of high-risk scope entirely.

---

## 6. The €11 evaluation flow (unchanged, one addition)

```
Confirm profile → 3 focus questions (career chips pre-filled from the
user's selected industry) → language choice → explicit consent that
work starts before the 14-day withdrawal period ends → Stripe checkout
→ webhook → order + chart snapshot + career analysis frozen
→ invoice → astrologer assigned → workbench → LLM draft → astrologer
edits and approves → QA review → PDF → delivered
```

`DRAFT → PAYMENT_PENDING → PAID → ASSIGNED → IN_ANALYSIS → IN_REVIEW → DELIVERED → CLOSED`

The astrologer now sees the user's selected industry and the auto-generated career analysis in the workbench (US-140), and may disagree with it — but must explain why. The report template gains a career section.

Payments stay Stripe web checkout, not App Store IAP: you're selling a human professional service, and the 15–30% commission would be €1.65–3.30 against a €3.92 contribution margin. Confirm the framing with your lawyer and state it in App Review notes.

---

## 7. Unit economics (unchanged)

| Line | € |
|---|---|
| Gross price (incl. 19% VAT) | 11.00 |
| Less VAT | −1.76 |
| **Net revenue** | **9.24** |
| Astrologer fee | −4.75 |
| Payment processing | −0.42 |
| Infra / PDF / email | −0.15 |
| **Contribution margin** | **3.92 (42%)** |

Break-even on operating cost alone: ~489 orders/month. Year-1 cost including one-offs: ~€41,000, excluding salaries.

---

## 8. Timeline

**806 MVP points → 14 sprints → 30 weeks**, up from 26 in the original plan. The career feature adds four weeks, and it's worth them.

Sprint sequencing is in the Release Plan tab. Two changes from the original ordering:

- **S0 now includes the AGPL boundary decision and its legal review.** Nothing else in the engine should start until that decision record exists — the repo split depends on it.
- **S2 builds and publishes the engine package** (FFI + WASM) before any chart features. Prove both builds produce identical output early.
- **S6 is the career feature.** It sits after the chart engine and before payments, because it's the funnel's front end and you want it in beta testers' hands early.

---

## 9. Where to start

**Week 1 — the AGPL decision record.** Before any code. Write down exactly where Swiss Ephemeris runs, what goes in the public repo, and what stays private. Send it to a licensing lawyer. Everything downstream depends on this being right.

**Weeks 1–2, in parallel:** engage the German lawyer for AGB/Datenschutz/Widerruf (4–8 weeks, gates your Stripe account), start recruiting astrologers (you need 5–8 before launch), and form the entity.

**Weeks 3–4 — the FFI/WASM spike.** Get Swiss Ephemeris compiled for iOS, Android and WASM, and prove all three produce identical output on shared test vectors. If the toolchain fights you, find out now.

**Weeks 5–6 — the timezone resolver.** German DST history 1945–79 and Indian pre-1955 offsets. This is where astrology apps silently break.

Then follow the Release Plan.

---

## Sources

- [Swiss Ephemeris licence terms (AGPL-3.0 / Professional)](https://www.astro.com/ftp/swisseph/LICENSE)
- [Swiss Ephemeris price list](https://www.astro.com/swisseph/swephprice_e.htm)
- [EU AI Act Omnibus agreement — postponed high-risk deadlines (Gibson Dunn)](https://www.gibsondunn.com/eu-ai-act-omnibus-agreement-postponed-high-risk-deadlines-and-other-key-changes/)
- [Digital AI Omnibus — proposed deferral of high-risk obligations (DLA Piper)](https://knowledge.dlapiper.com/dlapiperknowledge/globalemploymentlatestdevelopments/2026/The-Digital-AI-Omnibus-Proposed-deferral-of-high-risk-AI-obligations-under-the-AI-Act)
- [EU AI Act in recruitment — high-risk rules](https://accessfinancial.com/eu-ai-act-recruitment-high-risk-hiring-2026/)
- [GDPR Article 22 and AI recruitment screening](https://treegarden.io/blog/gdpr-article-22-ai-recruitment-screening/)
- [AI in recruitment and HR in Germany — legal compliance](https://se-legal.de/ai-recruitment-hr-germany-compliance-employers-international/?lang=en)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Germany VAT for digital services (Anrok)](https://www.anrok.com/vat-software-digital-services/germany)
- [Widerrufsrecht für digitale Inhalte (eRecht24)](https://www.e-recht24.de/ecommerce/13530-widerrufsrecht-fuer-digitale-inhalte.html)

*Legal and tax information here is for planning only — I'm not a lawyer or a tax advisor. The AGPL boundary, the career feature's terms of use, the Widerruf wording and the App Store IAP framing each need sign-off from the relevant specialist before launch.*
