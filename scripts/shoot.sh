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
# A direct binary launch can create its window on a non-active Space; bring it
# forward so CGWindowList can see the window for screenshot capture.
open -a "$APP" 2>/dev/null || true
sleep 1.2

if ! kill -0 "$PID" 2>/dev/null; then
  echo "TidyMac exited during startup; see .build/shoot.err.log" >&2
  exit 1
fi

# Capture the full screen and crop to the window. Capturing a window directly
# can return a stale surface after rebuilds, so this path is used first.
FULL="$ROOT/.build/shoot-full.png"
screencapture -x "$FULL"
BOUNDS="$(osascript -e 'tell application "System Events" to tell process "TidyMac" to get {position, size} of window 1' 2>/dev/null | tr -d ' ' || true)"
if [[ -n "$BOUNDS" ]]; then
  read -r X Y W H < <(printf '%s\n' "$BOUNDS" | tr ',' ' ')
  PIX_W="$(sips -g pixelWidth "$FULL" 2>/dev/null | awk '/pixelWidth/ { print $2; exit }')"
  SCREEN_W="$(osascript -e 'tell application "Finder" to get bounds of window of desktop' 2>/dev/null | awk -F', ' '{ print $3 }')"
  if [[ -n "$PIX_W" && -n "$SCREEN_W" && "$SCREEN_W" -gt 0 ]]; then
    SCALE=$((PIX_W / SCREEN_W))
    X2=$((X * SCALE)); Y2=$((Y * SCALE)); W2=$((W * SCALE)); H2=$((H * SCALE))
    if sips -c "$H2" "$W2" --cropOffset "$Y2" "$X2" "$FULL" --out "$OUT_DIR/$NAME.png" >/dev/null 2>&1; then
      :
    else
      cp "$FULL" "$OUT_DIR/$NAME.png"
    fi
  else
    cp "$FULL" "$OUT_DIR/$NAME.png"
  fi
else
  WID="$("$ROOT/.build/windowid" "$PID" || true)"
  if [[ -n "$WID" ]]; then
    screencapture -l "$WID" -o -x "$OUT_DIR/$NAME.png"
  else
    cp "$FULL" "$OUT_DIR/$NAME.png"
  fi
fi
rm -f "$FULL"

kill "$PID" 2>/dev/null || true
echo "$OUT_DIR/$NAME.png"
