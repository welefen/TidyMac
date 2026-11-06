#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/TidyMac.app"
DEST="/Applications/TidyMac.app"

if [[ ! -d "$APP" ]]; then
  echo "请先运行 ./build.sh 生成 $APP" >&2
  exit 1
fi

pkill -x TidyMac 2>/dev/null || true
sleep 0.3

if [[ -w /Applications ]]; then
  rm -rf "$DEST"
  ditto "$APP" "$DEST"
else
  osascript <<OSA
do shell script "rm -rf '$DEST' && ditto '$APP' '$DEST'" with administrator privileges
OSA
fi

open "$DEST"
echo "▸ 已安装到 $DEST"
echo "▸ 完全磁盘访问：系统设置 → 隐私与安全性 → 完全磁盘访问权限 → + → 选择 /Applications/TidyMac.app"
