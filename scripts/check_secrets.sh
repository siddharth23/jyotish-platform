#!/usr/bin/env bash
#
# Coarse scan for credentials committed to the repository.
# Not a replacement for a proper scanner -- a fast guard against the obvious.
#
set -euo pipefail

PATTERNS=(
  'sk_live_[0-9a-zA-Z]{20,}'
  'sk_test_[0-9a-zA-Z]{20,}'
  'rk_live_[0-9a-zA-Z]{20,}'
  'gh[pousr]_[0-9a-zA-Z]{30,}'
  'AKIA[0-9A-Z]{16}'
  '-----BEGIN (RSA |EC |OPENSSH |PGP )?PRIVATE KEY-----'
  'whsec_[0-9a-zA-Z]{20,}'
)

failed=0
echo "Scanning for committed secrets..."

for pattern in "${PATTERNS[@]}"; do
  if matches=$(grep -rnE --binary-files=without-match \
                 --exclude-dir=node_modules \
                 --exclude-dir=.git \
                 --exclude="check_secrets.sh" \
                 --exclude=".env.example" \
                 "$pattern" . 2>/dev/null); then
    echo ""
    echo "POSSIBLE SECRET: pattern /$pattern/"
    echo "$matches" | sed 's/^/  /'
    failed=1
  fi
done

if [[ -f .env ]]; then
  echo ""
  echo "ERROR: .env is present in the working tree and must never be committed."
  failed=1
fi

echo ""
if [[ $failed -ne 0 ]]; then
  echo "Secret scan failed. Remove the credential AND rotate it -- git history is forever."
  exit 1
fi

echo "No secrets detected."
