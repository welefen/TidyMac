#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="1.0.0"
DIST="$ROOT/dist"

./build.sh

rm -rf "$DIST"
mkdir -p "$DIST/stage"

ditto "$ROOT/build/Qingyu.app" "$DIST/stage/Qingyu.app"
ln -s /Applications "$DIST/stage/Applications"

echo "▸ Creating DMG"
if hdiutil create \
  -volname "清羽" \
  -srcfolder "$DIST/stage" \
  -ov -format UDZO \
  "$DIST/Qingyu-$VERSION.dmg" >/dev/null 2>&1; then
  echo "  DMG ready"
else
  # hdiutil needs privileges that are unavailable in some sandboxed/CI
  # environments. The ZIP below is a fully functional alternative.
  rm -f "$DIST/Qingyu-$VERSION.dmg"
  echo "  DMG creation unavailable in this environment; ZIP only."
fi

echo "▸ Creating ZIP"
ditto -c -k --sequesterRsrc --keepParent "$ROOT/build/Qingyu.app" "$DIST/Qingyu-$VERSION.zip"

echo "▸ Checksums"
rm -f "$DIST/SHA256SUMS.txt"
(
  cd "$DIST"
  for file in Qingyu-"$VERSION".dmg Qingyu-"$VERSION".zip; do
    [[ -f "$file" ]] && shasum -a 256 "$file"
  done
) | tee "$DIST/SHA256SUMS.txt"
rm -rf "$DIST/stage"
echo "▸ Done: $DIST"
