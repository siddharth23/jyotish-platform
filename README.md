# jyotish-platform

Private monorepo for the Jyotish DE product — a Vedic astrology application for the German
market, offering free chart generation and career analysis, plus a paid expert kundali
evaluation.

**Proprietary and confidential.** See [`LICENSE`](LICENSE).

---

## Read this before writing any code

This repository is proprietary. It stays that way only because of a licensing boundary that
is easy to breach by accident.

The astrological calculation engine ([`sidkalaapcoa/jyotish-engine`](https://github.com/sidkalaapcoa/jyotish-engine))
is **AGPL-3.0**. If any server-side code here links to, bundles, or calls it, this entire
platform becomes subject to AGPL source-disclosure obligations.

**Charts are computed on the client. Never on the server.**

- Mobile app → Dart FFI → engine runs on the user's device
- Astrologer console → WebAssembly → engine runs in the astrologer's browser
- Backend → receives computed chart JSON. Never computes.

`scripts/check_agpl_boundary.sh` runs in CI and fails the build on violation. Read
[`docs/AGPL-BOUNDARY.md`](docs/AGPL-BOUNDARY.md) in full before touching `api/`.

---

## Layout

```
app/                  Flutter application (iOS, Android)
api/                  Backend services — orders, payments, fulfilment, admin
console-astrologer/   Web console for astrologers writing evaluations
console-admin/        Internal operations and support console
shared/               Types and contracts shared across packages
infra/                Infrastructure as code (EU region)
scripts/              Build, CI and guard scripts
docs/                 Architecture, decisions, runbooks
```

## Environments

All personal data resides in `eu-central-1` (Frankfurt). Three environments — `dev`,
`staging`, `prod` — defined in `infra/`. Production data never flows to the others.

## Getting started

```bash
cp .env.example .env        # then fill in — never commit .env
./scripts/bootstrap.sh      # tool versions, dependencies, pre-commit hooks
./scripts/dev.sh            # local stack
```

Requires Flutter 3.24+, Node 20+, Docker, and Terraform 1.9+.

## Documentation

| Document | Purpose |
|---|---|
| [`docs/AGPL-BOUNDARY.md`](docs/AGPL-BOUNDARY.md) | The licensing constraint. Mandatory reading. |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | System design |
| [`docs/adr/`](docs/adr/) | Architecture decision records |
| [`docs/COMPLIANCE.md`](docs/COMPLIANCE.md) | GDPR, VAT, consumer law, store requirements |
| [`docs/SECURITY.md`](docs/SECURITY.md) | Security practices and incident response |
| [`docs/RUNBOOKS.md`](docs/RUNBOOKS.md) | On-call procedures |
