#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP="${TIDYMAC_APP:-$ROOT/build/TidyMac.app}"
OUT_DIR="${TIDYMAC_SHOTS:-$ROOT/screenshots}"
PAGE="${1:-overview}"
STATE="${2:-}"
NAME="${3:-$PAGE}"
APPEARANCE="${4:-}"
LANGUAGE="${5:-}"

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

BINARY="$APP/Contents/MacOS/TidyMac"
if [[ ! -x "$BINARY" ]]; then
  echo "App not built: $APP" >&2
  exit 1
fi

# Kill any previous instance (including ones started with a relative path) so
# the new process owns the window we are about to capture.
pkill -x TidyMac 2>/dev/null || true
pkill -f "$BINARY" 2>/dev/null || true
sleep 0.5

export TIDYMAC_DEMO=1
export TIDYMAC_PAGE="$PAGE"
if [[ -n "$STATE" ]]; then
  export TIDYMAC_DEMO_STATE="$STATE"
fi
if [[ -n "$APPEARANCE" ]]; then
  export TIDYMAC_APPEARANCE="$APPEARANCE"
fi

if [[ -n "$LANGUAGE" ]]; then
  "$BINARY" -AppleLanguages "($LANGUAGE)" >"$ROOT/.build/shoot.out.log" 2>"$ROOT/.build/shoot.err.log" &
else
  "$BINARY" >"$ROOT/.build/shoot.out.log" 2>"$ROOT/.build/shoot.err.log" &
fi
PID=$!
sleep 3.4

if ! kill -0 "$PID" 2>/dev/null; then
  echo "TidyMac exited during startup; see .build/shoot.err.log" >&2
  exit 1
fi

WID="$("$ROOT/.build/windowid" "$PID" || true)"
if [[ -z "$WID" ]]; then
  sleep 1.2
  WID="$("$ROOT/.build/windowid" "$PID" || true)"
fi
if [[ -z "$WID" ]]; then
  echo "Could not find TidyMac window; capturing full screen instead." >&2
  screencapture -x "$OUT_DIR/$NAME.png"
else
  screencapture -l "$WID" -o -x "$OUT_DIR/$NAME.png"
fi

kill "$PID" 2>/dev/null || true
echo "$OUT_DIR/$NAME.png"
