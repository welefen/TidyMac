#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
if [[ ! -d "$SDK" ]]; then
  SDK="$(xcrun --show-sdk-path)"
fi

CACHE="$ROOT/.build/modulecache"
TMP="$ROOT/.build/tmp"
mkdir -p "$CACHE" "$TMP" "$ROOT/Resources" "$ROOT/.build/icon"

SWIFT_MODULE_CACHE_PATH="$CACHE" CLANG_MODULE_CACHE_PATH="$CACHE" TMPDIR="$TMP" \
  swiftc -sdk "$SDK" \
    -module-cache-path "$CACHE" \
    -target arm64-apple-macosx14.0 \
    -swift-version 5 \
    -O \
    -o "$ROOT/.build/icon/icongen" \
    "$ROOT/scripts/IconGen.swift"

"$ROOT/.build/icon/icongen" "$ROOT/.build/icon/AppIcon-1024.png"
cp "$ROOT/.build/icon/AppIcon-1024.png" "$ROOT/Resources/AppIcon.png"

ICONSET="$ROOT/.build/icon/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

sips -z 16 16     "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32     "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32     "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64     "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128   "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256   "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512   "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_512x512.png" >/dev/null
cp "$ROOT/Resources/AppIcon.png" "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o "$ROOT/Resources/AppIcon.icns"
echo "▸ Wrote Resources/AppIcon.icns"
sips -g pixelWidth -g pixelHeight "$ROOT/Resources/AppIcon.png" | tail -2
