#!/bin/zsh
# Packs build/Grammar Llama.app into a drag-to-install DMG with an Applications shortcut.
#   ./scripts/make-dmg.sh build/Grammar-Llama-0.1.0.dmg
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:?usage: make-dmg.sh <output.dmg>}"
APP="build/Grammar Llama.app"
[[ -d "$APP" ]] || { echo "Build the app first: ./scripts/build-app.sh"; exit 1; }

STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp Resources/AppIcon.icns "$STAGE/.VolumeIcon.icns"

rm -f "$OUT"
hdiutil create -quiet -volname "Grammar Llama" -srcfolder "$STAGE" -ov -format UDZO -fs HFS+ "$OUT"
rm -rf "$STAGE"
# Deliberately left unsigned: a DMG signed with a non-Developer-ID certificate is refused outright
# by Gatekeeper ("Not Opened"), while an unsigned image opens and the app inside is checked on launch.
# Once you have a Developer ID, sign and notarize here instead.
echo "DMG written to $OUT ($(du -h "$OUT" | cut -f1))"
