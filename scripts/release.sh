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
APP="build/Grammar Llama.app"
ZIP="build/Grammar-Llama-$VERSION.zip"
DMG="build/Grammar-Llama-$VERSION.dmg"
rm -f "$ZIP" "$DMG"

# Notarize when a Developer ID and a stored notarytool profile named "grammar-llama" exist.
# Set up once with:  xcrun notarytool store-credentials grammar-llama --apple-id <id> --team-id <team> --password <app-specific>
NOTARIZE=0
if security find-identity -v -p codesigning | grep -q "Developer ID Application" \
   && xcrun notarytool history --keychain-profile grammar-llama >/dev/null 2>&1; then
  NOTARIZE=1
fi

if [[ $NOTARIZE -eq 1 ]]; then
  echo "Notarizing app…"
  ditto -c -k --keepParent "$APP" "$ZIP"
  xcrun notarytool submit "$ZIP" --keychain-profile grammar-llama --wait
  xcrun stapler staple "$APP"
  rm -f "$ZIP"
fi
ditto -c -k --keepParent "$APP" "$ZIP"
echo "Zipped $ZIP"

./scripts/make-dmg.sh "$DMG"
if [[ $NOTARIZE -eq 1 ]]; then
  echo "Notarizing disk image…"
  xcrun notarytool submit "$DMG" --keychain-profile grammar-llama --wait
  xcrun stapler staple "$DMG"
  spctl -a -t open --context context:primary-signature -v "$DMG" && echo "Gatekeeper accepts $DMG"
else
  echo "Not notarized: no Developer ID certificate or 'grammar-llama' notarytool profile found."
fi

gh release create "v$VERSION" "$DMG" "$ZIP" \
  --title "Grammar Llama $VERSION" \
  --notes "$( [[ $NOTARIZE -eq 1 ]] && echo "Open the **.dmg** and drag **Grammar Llama** onto the Applications folder next to it. Notarized by Apple: it opens without warnings. Then allow Accessibility and add your Anthropic or OpenAI API key." || echo "Open the **.dmg** and drag **Grammar Llama** onto the Applications folder next to it. First launch (not notarized yet): double-click once, dismiss the dialog, then System Settings → Privacy & Security → **Open Anyway**. Then allow Accessibility and add your Anthropic or OpenAI API key." )"
