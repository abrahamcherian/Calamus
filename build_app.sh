#!/bin/bash
# Builds "Calamus.app" into ./build with plain swiftc (no Swift Package Manager needed).
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Calamus"
APP="build/${APP_NAME}.app"
ARCH="$(uname -m)"          # x86_64 or arm64

if ! command -v swiftc >/dev/null 2>&1; then
  echo "swiftc was not found. Install the command-line tools first:  xcode-select --install" >&2
  exit 1
fi

SDK="$(xcrun --sdk macosx --show-sdk-path)"
echo "Compiler: $(swiftc --version 2>&1 | head -1)"
echo "SDK:      $SDK"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O \
  -sdk "$SDK" \
  -target "${ARCH}-apple-macos12.0" \
  -module-name Calamus \
  Sources/Calamus/*.swift \
  -o "$APP/Contents/MacOS/Calamus"

if [ ! -s Resources/Info.plist ]; then echo "Resources/Info.plist is empty - restore it before building." >&2; exit 1; fi
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Free, open-source coding fonts (see Resources/Fonts/LICENSES.md).
if [ -d Resources/Fonts ]; then
  mkdir -p "$APP/Contents/Resources/Fonts"
  cp Resources/Fonts/* "$APP/Contents/Resources/Fonts/"
fi

# App icon (Resources/Calamus.icns), referenced by Info.plist's CFBundleIconFile.
if [ -f Resources/Calamus.icns ]; then
  cp Resources/Calamus.icns "$APP/Contents/Resources/Calamus.icns"
fi

# Read Me note shown on first/empty launch (Help > Read Me reopens it any time).
if [ -f Resources/ReadMe.txt ]; then
  cp Resources/ReadMe.txt "$APP/Contents/Resources/ReadMe.txt"
fi

# Ad-hoc sign so macOS is happy launching a locally built app.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo ""
echo "Built: $(pwd)/$APP"
echo "Run it with:  open \"$APP\""
