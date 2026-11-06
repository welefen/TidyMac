#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
if [[ ! -d "$SDK" ]]; then
  SDK="$(xcrun --show-sdk-path)"
fi

CACHE="${QINGYU_MODULE_CACHE:-$ROOT/.build/modulecache}"
TMP="${QINGYU_TMP:-$ROOT/.build/tmp}"
BUILD_DIR="${QINGYU_BUILD_DIR:-$ROOT/build}"
mkdir -p "$CACHE" "$TMP" "$BUILD_DIR"

APP="$BUILD_DIR/Qingyu.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi
printf 'APPL????' > "$APP/Contents/PkgInfo"

APP_SOURCES=()
while IFS= read -r file; do APP_SOURCES+=("$file"); done < <(find Sources/App Sources/Core Sources/UI -name '*.swift' -print | sort)

echo "▸ Compiling Qingyu.app (${#APP_SOURCES[@]} files)"
SWIFT_MODULE_CACHE_PATH="$CACHE" CLANG_MODULE_CACHE_PATH="$CACHE" TMPDIR="$TMP" \
  swiftc -sdk "$SDK" \
    -module-cache-path "$CACHE" \
    -target arm64-apple-macosx14.0 \
    -swift-version 5 \
    -parse-as-library \
    -O \
    -o "$APP/Contents/MacOS/Qingyu" \
    "${APP_SOURCES[@]}"

codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
echo "▸ Built $APP"

# Headless CLI for scanning, diagnostics and self-tests.
CORE_SOURCES=()
while IFS= read -r file; do CORE_SOURCES+=("$file"); done < <(find Sources/Core -name '*.swift' -print | sort)
SWIFT_MODULE_CACHE_PATH="$CACHE" CLANG_MODULE_CACHE_PATH="$CACHE" TMPDIR="$TMP" \
  swiftc -sdk "$SDK" \
    -module-cache-path "$CACHE" \
    -target arm64-apple-macosx14.0 \
    -swift-version 5 \
    -parse-as-library \
    -O \
    -o "$BUILD_DIR/qingyu-cli" \
    "${CORE_SOURCES[@]}" Sources/CLI/main.swift

echo "▸ Built $BUILD_DIR/qingyu-cli"
echo "▸ Done. Launch with: open $BUILD_DIR/Qingyu.app"
