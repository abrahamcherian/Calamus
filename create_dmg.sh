#!/bin/bash
# Packages the already-built Calamus.app into a distributable .dmg installer (drag Calamus.app
# into the Applications shortcut inside it). Run this AFTER building - it does not build the app
# itself. Usage:
#   bash create_dmg.sh
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Calamus"
APP="build/${APP_NAME}.app"
VOL_NAME="${APP_NAME}"

if [ ! -d "$APP" ]; then
  echo "build/${APP_NAME}.app not found. Build it first:  ./build_app.sh" >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || echo unknown)"
STAMP="$(date +%Y-%m-%d_%H%M%S)"

DEST_DIR="Releases"
mkdir -p "$DEST_DIR"
DMG_PATH="${DEST_DIR}/${APP_NAME}_v${VERSION}_${STAMP}.dmg"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

echo "Staging DMG contents..."
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

# A short note that lives inside the DMG itself (separate from the app's own Help > Read Me),
# since this is the first thing someone sees before they've even installed the app.
cat > "$STAGE/Read Before Installing.txt" <<EOF
Calamus ${VERSION}

To install: drag Calamus into the Applications folder shown here.

Calamus is unsigned - it doesn't have an Apple Developer ID yet. The first
time you open it, macOS will say it's from an "unidentified developer" and
refuse to launch it normally. To get past that (only needed once):

  1. Open the Applications folder and find Calamus.
  2. Right-click (or Control-click) Calamus and choose "Open."
  3. In the dialog that appears, click "Open" again to confirm.

After that first time, Calamus opens normally, including by double-click.
EOF

rm -f "$DMG_PATH"

echo "Building ${DMG_PATH} ..."
hdiutil create -volname "$VOL_NAME" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DMG_PATH"

echo ""
echo "Created: $(pwd)/${DMG_PATH}"
echo "Open it with:  open \"${DMG_PATH}\""
