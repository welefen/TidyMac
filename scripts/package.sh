#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="1.0.17"
DIST="$ROOT/dist"

./build.sh

rm -rf "$DIST"
mkdir -p "$DIST/stage"

ditto "$ROOT/build/TidyMac.app" "$DIST/stage/TidyMac.app"
ln -s /Applications "$DIST/stage/Applications"

echo "▸ Creating DMG"
if hdiutil create \
  -volname "TidyMac" \
  -srcfolder "$DIST/stage" \
  -ov -format UDZO \
  "$DIST/TidyMac-$VERSION.dmg" >/dev/null 2>&1; then
  echo "  DMG ready"
else
  # hdiutil needs privileges that are unavailable in some sandboxed/CI
  # environments. The ZIP below is a fully functional alternative.
  rm -f "$DIST/TidyMac-$VERSION.dmg"
  echo "  DMG creation unavailable in this environment; ZIP only."
fi

echo "▸ Creating ZIP"
COPYFILE_DISABLE=1 ditto -c -k --norsrc --keepParent "$ROOT/build/TidyMac.app" "$DIST/TidyMac-$VERSION.zip"

echo "▸ Checksums"
rm -f "$DIST/SHA256SUMS.txt"
(
  cd "$DIST"
  for file in TidyMac-"$VERSION".dmg TidyMac-"$VERSION".zip; do
    [[ -f "$file" ]] && shasum -a 256 "$file"
  done
) | tee "$DIST/SHA256SUMS.txt"
rm -rf "$DIST/stage"
echo "▸ Done: $DIST"
