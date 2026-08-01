#!/usr/bin/env bash
#
# Fails the build if server-side code references the AGPL-licensed calculation engine.
#
# WHY THIS EXISTS
#   The engine embeds Swiss Ephemeris under AGPL-3.0. If any server-side component
#   links to or invokes it, AGPL section 13 obliges us to publish the source of this
#   entire platform.
#
#   See docs/AGPL-BOUNDARY.md.
#
# DO NOT delete, skip or weaken this check. If it blocks something you believe is
# legitimate, escalate to the Tech Lead rather than editing this file.
#
set -euo pipefail

# Directories that run on a server.
SERVER_PATHS=("api" "infra" "scripts")

# Markers indicating the engine or Swiss Ephemeris is being used.
FORBIDDEN_PATTERNS=(
  "jyotish_engine"
  "jyotish-engine"
  "@jyotish/engine-wasm"
  "swisseph"
  "swe_calc"
  "swe_houses"
  "swe_set_sid_mode"
  "libswisseph"
)

failed=0

echo "Checking the AGPL boundary..."

for path in "${SERVER_PATHS[@]}"; do
  [[ -d "$path" ]] || continue
  for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
    # Exclude this script and documentation, which necessarily name the patterns.
    if matches=$(grep -rn --binary-files=without-match \
                   --exclude-dir=node_modules \
                   --exclude-dir=.git \
                   --exclude="check_agpl_boundary.sh" \
                   --exclude="*.md" \
                   -F "$pattern" "$path" 2>/dev/null); then
      echo ""
      echo "AGPL BOUNDARY VIOLATION"
      echo "  Pattern '$pattern' found in server-side path '$path':"
      echo "$matches" | sed 's/^/    /'
      failed=1
    fi
  done
done

echo ""
if [[ $failed -ne 0 ]]; then
  cat <<'MESSAGE'
================================================================================
The build has been stopped.

Server-side code appears to reference the AGPL-licensed calculation engine.
If merged, this would place the entire platform under AGPL-3.0 and oblige us to
publish its source.

Charts are computed on the CLIENT:
  - Flutter app  -> Dart FFI     -> on the user's device
  - Web console  -> WebAssembly  -> in the user's browser
The backend receives computed chart JSON. It never computes.

Read docs/AGPL-BOUNDARY.md, then talk to the Tech Lead.
Do not work around this check.
================================================================================
MESSAGE
  exit 1
fi

echo "AGPL boundary intact: no server-side engine usage detected."
