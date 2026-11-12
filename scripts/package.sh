#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
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
  # Some sandboxed/CI environments cannot create UDZO images directly; build a
  # hybrid HFS image first and compress it instead. The ZIP is still produced.
  rm -f "$DIST/TidyMac-$VERSION.dmg"
  HYBRID="$DIST/TidyMac-$VERSION-hybrid.dmg"
  rm -f "$HYBRID"
  if hdiutil makehybrid -o "$HYBRID" "$DIST/stage" -hfs -default-volume-name "TidyMac" >/dev/null 2>&1 \
     && hdiutil convert "$HYBRID" -format UDZO -o "$DIST/TidyMac-$VERSION.dmg" >/dev/null 2>&1; then
    rm -f "$HYBRID"
    echo "  DMG ready (hybrid fallback)"
  else
    rm -f "$HYBRID" "$DIST/TidyMac-$VERSION.dmg"
    echo "  DMG creation unavailable in this environment; ZIP only."
  fi
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
