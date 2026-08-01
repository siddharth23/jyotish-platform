# Security

## Reporting

Internal: raise a P1 incident. External: private vulnerability report on this repository.
Never open a public issue.

## Practices

| Area | Requirement |
|---|---|
| Secrets | Managed secret store only. Never in the repo, never in the app binary. |
| Transport | TLS 1.3 enforced everywhere |
| Birth data | Field-level envelope encryption via KMS; decryption logged and role-gated |
| Reports | S3 with signed, expiring URLs; never publicly enumerable |
| Tokens | Short-lived access token, rotating refresh token, Keychain/Keystore storage |
| Admin access | SSO, mandatory 2FA, least privilege, full audit trail |
| Mobile | Certificate pinning, root/jailbreak signals, no secrets in the binary |
| Logging | No PII, birth data or payment details. Ever. |
| Dependencies | Dependabot, weekly review, no unreviewed transitive additions |

## Pre-launch

External penetration test against OWASP MASVS (mobile) and ASVS L2 (API). All critical and
high findings fixed and retested before public release.

## Note on the public engine repository

`jyotish-engine` is public. Nothing secret may enter it — no keys, endpoints, internal
hostnames or business rules. Treat every commit there as permanently public, because it is.
