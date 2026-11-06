#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
./build.sh
pkill -x TidyMac 2>/dev/null || true
open build/TidyMac.app
