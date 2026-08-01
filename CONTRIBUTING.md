# Contributing

## Before your first pull request

Read [`docs/AGPL-BOUNDARY.md`](docs/AGPL-BOUNDARY.md). It is short, and misunderstanding it
is the one mistake in this repository that cannot be quietly fixed later.

## Branching

`main` is protected and always deployable. Work on `feature/US-XXX-short-description`,
referencing the story ID from the backlog.

## Commits

Conventional Commits, with the story ID:

```
feat(career): add industry selection screen (US-130)
fix(payments): make webhook handler idempotent (US-076)
docs(adr): record client-side computation decision
```

## Pull requests

- Small enough to review properly.
- Tests for new logic; the engine, career rules and payment paths are non-negotiable.
- No secrets, keys or real personal data — not in code, fixtures, tests or logs.
- The AGPL boundary check must pass. If it fails, do not work around it; ask.

## Code standards

| Area | Standard |
|---|---|
| Dart | `dart format`, `dart analyze --fatal-infos` clean |
| TypeScript | ESLint + Prettier, `strict` mode, no `any` |
| Tests | 70%+ coverage on engine integration, career rules and payments |
| Logs | Never log birth data, names, email addresses or payment details |

## Handling personal data

Birth data is sensitive. When touching it:

- Field-level encryption at rest, always.
- Never in logs, error messages, analytics events or crash reports.
- Never in test fixtures — use synthetic data.
- Access from admin tooling requires a justification and is audit-logged.

## Definition of done

- [ ] Acceptance criteria from the story are met
- [ ] Tests written and passing
- [ ] AGPL boundary check passing
- [ ] No personal data in logs or telemetry
- [ ] German strings externalised, not hardcoded
- [ ] Documentation updated where behaviour changed
