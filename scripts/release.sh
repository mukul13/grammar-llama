#!/bin/zsh
# Builds Grammar Llama, zips it, and publishes a GitHub Release.
#   ./scripts/release.sh 0.1.0
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:?usage: release.sh <version>}"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Resources/Info.plist
BUILD_NUM=$(( $(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Resources/Info.plist) + 1 ))
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUM" Resources/Info.plist

./scripts/build-app.sh
ZIP="build/Grammar-Llama-$VERSION.zip"
DMG="build/Grammar-Llama-$VERSION.dmg"
rm -f "$ZIP" "$DMG"
ditto -c -k --keepParent "build/Grammar Llama.app" "$ZIP"
echo "Zipped $ZIP"
./scripts/make-dmg.sh "$DMG"

gh release create "v$VERSION" "$DMG" "$ZIP" \
  --title "Grammar Llama $VERSION" \
  --notes "Open the **.dmg** and drag **Grammar Llama** onto the Applications folder next to it. First launch (not notarized yet): double-click once, dismiss the dialog, then System Settings → Privacy & Security → **Open Anyway**. Then allow Accessibility and add your Anthropic or OpenAI API key."
