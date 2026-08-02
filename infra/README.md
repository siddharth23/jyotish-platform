# Infrastructure

Terraform, Hetzner Cloud, Germany (`fsn1`/`nbg1`).

**Temporary scope: single environment.** Pre-launch, pre-real-users, this runs on one box
(`environments/single`) with the app, PDF worker, Postgres and Redis all co-located — no
separate dev/staging/prod. This trades away the isolation between production data and
in-progress work described below. **Before onboarding real users or handling real payments,
split this into isolated environments** (dev/staging/prod, or at minimum prod separated from
everything else) — see US-003 in the backlog for the full multi-environment scope this was
descoped from.

## Requirements

- All personal data at rest in Germany. No exceptions, including backups and logs.
- Production data never replicated to dev or staging — **not currently true**; see the
  single-environment note above. Must hold again once environments split.
- Secrets in a managed secret store. Never in state files, never in the repository.
- Point-in-time recovery on the database, with restores tested — an untested backup is a
  hope, not a backup. Not yet set up; Postgres runs self-managed on the box with Hetzner's
  automatic server backups as an interim safety net, not true PITR.
- CDN, WAF and rate limiting in front of the API — not yet wired up. Cloudflare (free tier)
  in front of the box is the intended interim approach; not provisioned by this Terraform yet.

## Layout

```
environments/single              The current single-environment setup
modules/app-server                Hetzner server + firewall + SSH key, reusable per environment
```

## Access

CI supplies the Terraform inputs from repository settings:

| Setting | Kind | Purpose |
|---|---|---|
| `HCLOUD_TOKEN` | secret | Hetzner Cloud API, project-scoped, read and write |
| `HETZNER_OBJECT_STORAGE_ACCESS_KEY` | secret | Remote state bucket |
| `HETZNER_OBJECT_STORAGE_SECRET_KEY` | secret | Remote state bucket |
| `INFRA_SSH_PUBLIC_KEY` | variable | Installed on the server for the `deploy` user |
| `INFRA_ALLOWED_SSH_CIDRS` | variable | Port 22 allowlist, an HCL list such as `["203.0.113.4/32"]` |

The keypair currently in `INFRA_SSH_PUBLIC_KEY` was generated as
`~/.ssh/jyotish_infra` on the maintainer's machine. **Its private half exists in exactly
one place and is not backed up** — losing it means losing SSH access to a provisioned
server, recoverable only through the Hetzner console. Once the host is up:

```bash
ssh -i ~/.ssh/jyotish_infra deploy@<server-ip>
```

`INFRA_ALLOWED_SSH_CIDRS` is a home IP address and will go stale whenever that address
changes; the symptom is SSH timing out while everything else works. Update the variable
and re-apply. The module rejects `0.0.0.0/0`, so widening it to "anywhere" is not an
option — add the new address instead.

## Note

No ephemeris or chart-computation compute is provisioned anywhere, by design. Charts are
computed on clients. See `docs/AGPL-BOUNDARY.md`.
