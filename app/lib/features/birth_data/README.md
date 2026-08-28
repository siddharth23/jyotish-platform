# Birth data capture

Birth date, time and place — the input everything downstream is computed from.

| File | Purpose |
|---|---|
| `birth_details.dart` | Strict date/time parsing (US-020). Pure Dart. |
| `place.dart` | The gazetteer, folding and search (US-021). Pure Dart. |
| `coordinates.dart` | Manual coordinate entry (US-021 AC4). Pure Dart. |
| `gazetteer_loader.dart` | Decodes the bundled asset off the UI thread. |
| `presentation/` | The form, the caveat, the type-ahead and the fallback. |

## The search never leaves the device

A birthplace is part of a birth record. Under CLAUDE.md every processor touching personal
data needs a signed DPA and an EU data plane, and a type-ahead against a hosted geocoder
sends a fragment of that record off-device **on every keystroke** — dozens of transfers to
build one chart. Bundling the data removes the processor entirely, costs nothing per
request, and works offline, which the app already promises for saved kundalis.

The backlog files US-021 under "Backend". This is a deliberate departure; the vendor sheet
points the same way — *"Bundle GeoNames offline where possible to cut this to zero."*

## Two things about the data that are not obvious

**GeoNames' primary `name` is often the English exonym.** It says *Munich*, not *München*;
*Milan*, not *Mailand*. Shipping that to a German-first audience would be wrong on the most
visible field on the screen. The German names come from the language-tagged
`alternateNamesV2` export, which also yields the ASCII forms people type (*Muenchen*) and
the historical names they still use (*Bombay*, *Konstantinopel*) — as data, not as a
hand-curated exonym table that would be wrong the first time somebody was born somewhere
we forgot.

**The untagged `alternatenames` column is a trap.** It mixes every language on earth, so
searching it matches Hungarian and Japanese transliterations of the same town.

## Folding is where German input actually breaks

*München* gets typed `münchen`, `Munchen` and `Muenchen`. Diacritic stripping alone gets
the first two: German transliteration **expands** rather than strips (ä→ae, ö→oe, ü→ue,
ß→ss). So every name is indexed under both foldings and the query is matched against both.
The same applies to Turkish ı/ş/ğ/ç for AC3.

## Exact matches outrank population

Ranking by population alone put Romania's *Konstanza* (317k) above Germany's *Konstanz*
(81k), because the query is a prefix of the larger city. An exact name match is a far
stronger signal of intent, so it wins; the prefix scan then fills the rest, still
population-ordered so it can stop early.

## A typed coordinate has no timezone

`BirthPlaceField` reports manual coordinates with an empty `timeZoneId`. Defaulting to UTC
would silently produce a chart an hour or more out — exactly the failure CLAUDE.md lists
under "things that will silently break". **US-022 owns resolving the zone**, and it needs
the birth date as well as the coordinates.

Places chosen from the gazetteer *do* carry an IANA zone, because GeoNames already knows
it. That is the zone, not the offset: German double summer time and India's pre-1955
offset are still US-022's problem.

See `ATTRIBUTION.md` — the data is CC BY 4.0 and the notice must appear in the app.
