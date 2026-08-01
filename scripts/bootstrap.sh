#!/usr/bin/env bash
# One-time developer setup.
set -euo pipefail

echo "Checking toolchain..."
for tool in flutter node docker terraform; do
  command -v "$tool" >/dev/null 2>&1 || { echo "  MISSING: $tool"; exit 1; }
  echo "  ok: $tool"
done

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo ""
  echo "Created .env from the example. Fill it in before running ./scripts/dev.sh"
fi

echo "Installing git hooks..."
cat > .git/hooks/pre-commit <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
./scripts/check_agpl_boundary.sh
./scripts/check_secrets.sh
HOOK
chmod +x .git/hooks/pre-commit

echo ""
echo "Done. Read docs/AGPL-BOUNDARY.md before writing any server-side code."
