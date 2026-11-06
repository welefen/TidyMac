#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
./build.sh
pkill -x Qingyu 2>/dev/null || true
open build/Qingyu.app
