#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP="${QINGYU_APP:-$ROOT/build/Qingyu.app}"
OUT_DIR="${QINGYU_SHOTS:-$ROOT/screenshots}"
PAGE="${1:-overview}"
STATE="${2:-}"
NAME="${3:-$PAGE}"

mkdir -p "$OUT_DIR" "$ROOT/.build"
if [[ ! -x "$ROOT/.build/windowid" || "$ROOT/scripts/windowid.swift" -nt "$ROOT/.build/windowid" ]]; then
  SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
  CACHE="$ROOT/.build/modulecache"
  TMP="$ROOT/.build/tmp"
  mkdir -p "$CACHE" "$TMP"
  SWIFT_MODULE_CACHE_PATH="$CACHE" CLANG_MODULE_CACHE_PATH="$CACHE" TMPDIR="$TMP" \
    swiftc -sdk "$SDK" -module-cache-path "$CACHE" -target arm64-apple-macosx14.0 \
      -swift-version 5 -O -o "$ROOT/.build/windowid" "$ROOT/scripts/windowid.swift"
fi

BINARY="$APP/Contents/MacOS/Qingyu"
if [[ ! -x "$BINARY" ]]; then
  echo "App not built: $APP" >&2
  exit 1
fi

ARGS=(--demo --page "$PAGE")
if [[ -n "$STATE" ]]; then
  ARGS+=(--demo-state "$STATE")
fi

pkill -f "$BINARY" 2>/dev/null || true
sleep 0.3
"$BINARY" "${ARGS[@]}" >"$ROOT/.build/shoot.log" 2>&1 &
PID=$!
trap 'kill "$PID" 2>/dev/null || true' EXIT
sleep 3.4

WID="$("$ROOT/.build/windowid" "$PID" || true)"
if [[ -z "$WID" ]]; then
  echo "Could not find Qingyu window; capturing full screen instead." >&2
  screencapture -x "$OUT_DIR/$NAME.png"
else
  screencapture -l "$WID" -o -x "$OUT_DIR/$NAME.png"
fi

echo "$OUT_DIR/$NAME.png"
