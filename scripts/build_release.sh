#!/usr/bin/env bash
# Builds a release artefact with the debug symbols needed to read its crashes
# (US-008 AC2).
#
# A release build is obfuscated, so a crash report from it is unreadable without
# the matching symbol files. Those files exist only at build time and cannot be
# regenerated later: a stack trace from a build whose symbols were lost stays
# unreadable forever. This script refuses to hand back an artefact without them.
#
#   ./scripts/build_release.sh apk     # Android
#   ./scripts/build_release.sh ipa     # iOS, macOS host only
set -euo pipefail

TARGET="${1:-apk}"
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../app" && pwd)"
SYMBOL_DIR="$APP_DIR/build/symbols"

cd "$APP_DIR"

VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}')"
echo "Building $TARGET for version $VERSION"

rm -rf "$SYMBOL_DIR"
mkdir -p "$SYMBOL_DIR"

case "$TARGET" in
  apk)
    flutter build apk --release --obfuscate --split-debug-info="$SYMBOL_DIR"
    ARTEFACT="build/app/outputs/flutter-apk/app-release.apk"
    ;;
  appbundle)
    flutter build appbundle --release --obfuscate --split-debug-info="$SYMBOL_DIR"
    ARTEFACT="build/app/outputs/bundle/release/app-release.aab"
    ;;
  ipa)
    flutter build ipa --release --obfuscate --split-debug-info="$SYMBOL_DIR"
    ARTEFACT="build/ios/ipa"
    ;;
  *)
    echo "Unknown target: $TARGET (expected apk, appbundle or ipa)" >&2
    exit 1
    ;;
esac

# The check that gives this script a reason to exist. A silent flag change or a
# Flutter upgrade that moves the output would otherwise produce a shippable
# artefact whose crashes can never be read.
SYMBOL_COUNT="$(find "$SYMBOL_DIR" -name '*.symbols' | wc -l | tr -d ' ')"
if [ "$SYMBOL_COUNT" -eq 0 ]; then
  echo "ERROR: no symbol files in $SYMBOL_DIR" >&2
  echo "Crashes from this build could never be symbolicated. Not shipping it." >&2
  exit 1
fi

echo
echo "Artefact: $ARTEFACT"
echo "Symbols:  $SYMBOL_DIR ($SYMBOL_COUNT files)"
echo
echo "NEXT: upload the symbols to the crash reporter before releasing."
echo "They cannot be regenerated. Retain them for as long as the version is"
echo "installed on any device, which is longer than it is on the store."
