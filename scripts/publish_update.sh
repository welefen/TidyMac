#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
./scripts/package.sh

mkdir -p updates
ZIP="updates/TidyMac-$VERSION.zip"
DMG="updates/TidyMac-$VERSION.dmg"
cp "dist/TidyMac-$VERSION.zip" "$ZIP"
if [[ -f "dist/TidyMac-$VERSION.dmg" ]]; then
  cp "dist/TidyMac-$VERSION.dmg" "$DMG"
fi

SHA="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
cat > updates/latest.json <<JSON
{
  "version": "$VERSION",
  "downloadURL": "https://raw.githubusercontent.com/welefen/ai_TidyMac/main/$ZIP",
  "sha256": "$SHA",
  "releaseNotes": "TidyMac $VERSION"
}
JSON

echo "▸ Published update manifest"
echo "  version: $VERSION"
echo "  sha256:  $SHA"
echo "  file:    $ZIP"
echo
echo "Next:"
echo "  git add updates scripts/publish_update.sh && git commit -m 'release: TidyMac $VERSION' && git push origin main"
echo "The GitHub repository must be public for the in-app updater to download the asset."

if [[ "${1:-}" == "--push" ]]; then
  git add updates scripts/publish_update.sh
  if ! git diff --cached --quiet; then
    git -c user.name='Qingyu' -c user.email='dev@qingyu.local' commit -m "release: TidyMac $VERSION"
  fi
  git push origin main
  git tag -f "v$VERSION"
  git push origin "v$VERSION"
fi
