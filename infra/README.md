# Infrastructure

Terraform. Three environments — `dev`, `staging`, `prod` — all in `eu-central-1` (Frankfurt).

## Requirements

- All personal data at rest in the EU. No exceptions, including backups and logs.
- Production data never replicated to dev or staging.
- Secrets in a managed secret store. Never in state files, never in the repository.
- Point-in-time recovery on the database, with restores tested — an untested backup is a
  hope, not a backup.
- CDN, WAF and rate limiting in front of the API.

## Layout

```
environments/dev|staging|prod    Per-environment configuration
modules/                         Reusable components
```

## Note

No ephemeris or chart-computation compute is provisioned anywhere, by design. Charts are
computed on clients. See `docs/AGPL-BOUNDARY.md`.
