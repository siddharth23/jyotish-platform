# Birth data capture

US-020. Birth date and time entry, in German conventions.

| File | Purpose |
|---|---|
| `birth_details.dart` | Strict parsing and validation. Pure — no Flutter, no context. |
| `presentation/birth_data_screen.dart` | The form, the caveat and the explanation. |

## The parsing is hand-rolled on purpose

`DateTime(2000, 4, 31)` does not throw. It returns 1 May. Every widely used date
constructor rolls over silently, so a typo in the day yields a valid-looking chart for a
day the user never named, and nothing anywhere says so. For a €11 report keyed to a birth
moment, a silent off-by-one-day is far worse than a rejection — so `parseGermanDate`
round-trips the parts it was given and rejects anything that comes back different. Leap
years, including the 1900/2000 century rule, fall out of that for free.

Dots only, four-digit years, `HH:mm` in 24-hour form, nothing else. `01/02/2000` is
genuinely ambiguous and `7:30 pm` read as `07:30` moves the ascendant across roughly half
the zodiac — both are rejected rather than guessed at.

## `BirthDate` and `BirthTime` are not `DateTime`

A birth date on its own is not a moment. Turning it into one needs the birthplace and the
historical timezone rules for that place on that day — US-021 and US-022. Holding a
`DateTime` here would invite someone to call `.toUtc()` and shift the date across midnight,
which is the exact class of bug CLAUDE.md warns about under "things that will silently
break".

## "Time unknown" is a real fallback, not a smaller chart

Without a time there is no ascendant, so there are no houses, and most of what this app
sells — career, relationships, timing — depends on houses. The caveat says that plainly
instead of implying a slightly less precise result. AC2.

The inline explanation (AC4) gives the mechanism and a concrete next step: the ascendant
moves about a degree every four minutes and can change sign inside an hour, so check the
birth certificate. "Precision is important" would be true and useless.
