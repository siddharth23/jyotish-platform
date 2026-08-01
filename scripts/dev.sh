#!/usr/bin/env bash
# Starts the local development stack.
set -euo pipefail

[[ -f .env ]] || { echo "No .env found. Run ./scripts/bootstrap.sh first."; exit 1; }

echo "Starting local stack (Postgres, Redis, API)..."
# TODO: docker compose up -d && npm --prefix api run dev
echo "Not yet implemented."
