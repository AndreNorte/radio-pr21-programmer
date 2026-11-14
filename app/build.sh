#!/bin/bash
# Build PR-21 Manager. Requires only Xcode Command Line Tools.
# Usage: ./build.sh            → Intel (x86_64)
#        ARCH=arm64 ./build.sh → Apple Silicon
#        UNIVERSAL=1 ./build.sh → both (untested)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/PR-21 Manager.app"
BIN="$APP/Contents/MacOS/PR21Manager"
SDK="$(xcrun --show-sdk-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

SOURCES=$(find "$ROOT/src/core" "$ROOT/src/ui" -name '*.swift' 2>/dev/null | sort)
SOURCES="$SOURCES $ROOT/src/main.swift"
if [ -z "$SOURCES" ]; then
  echo "нет исходников в src/"; exit 1
fi

ARCH="${ARCH:-x86_64}"
if [ "${UNIVERSAL:-0}" = "1" ]; then
  swiftc -O -parse-as-library -sdk "$SDK"     -target x86_64-apple-macos13.0 -target arm64-apple-macos13.0     -o "$BIN" $SOURCES
else
  swiftc -O -parse-as-library -sdk "$SDK" -target "${ARCH}-apple-macos13.0"     -o "$BIN" $SOURCES
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>PR21Manager</string>
<key>CFBundleIdentifier</key><string>org.radiokit.pr21manager</string>
<key>CFBundleName</key><string>PR-21 Manager</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "собрано: $APP"
