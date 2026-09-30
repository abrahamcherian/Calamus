#!/bin/bash
# Makes a timestamped zip of the whole project source in ./Backups (run it before/after any change).
set -euo pipefail
cd "$(dirname "$0")"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist 2>/dev/null || echo unknown)"
STAMP="$(date +%Y-%m-%d_%H%M%S)"
mkdir -p Backups
OUT="Backups/Calamus_v${VERSION}_${STAMP}.zip"
zip -rq "$OUT" . -x "Backups/*" ".build/*" "build/*" "Releases/*" ".git/*" "*.DS_Store"
echo "Backup created: $(pwd)/$OUT"
