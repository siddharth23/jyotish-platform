# Flutter application

Feature-first structure. Each feature owns its data, domain and presentation layers.

```
lib/
  features/
    onboarding/     First run, consent, account creation
    birth_data/     Date, time, place capture; timezone resolution
    chart/          Kundali rendering (North, South, Western)
    career/         Industry selection and career analysis   [E16]
    evaluation/     EUR 11 expert report ordering and reading
    daily/          Panchang and transits
    profile/        Saved people, settings, data deletion
  core/
    engine/         Wrapper over the AGPL package — ON-DEVICE ONLY
    storage/        Drift database, encrypted birth data
    network/        API client (sends computed charts, never raw computation)
    l10n/           de-DE and en-GB
    design/         Design system
```

## The engine

The engine wrapper in `core/engine/` links the AGPL-licensed package via FFI. Charts are
computed here, on the device, and the resulting JSON is uploaded with an order.

The app is a client-side context, so this is permitted. Read `docs/AGPL-BOUNDARY.md` before
changing anything in `core/engine/` or in how chart data reaches the API.

## Localisation

German is the primary language and content is authored in German first. No hardcoded strings.
German runs roughly 30% longer than English — check layouts with pseudo-localisation.
