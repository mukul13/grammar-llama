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
rm -f "$ZIP"
ditto -c -k --keepParent "build/Grammar Llama.app" "$ZIP"
echo "Zipped $ZIP"

gh release create "v$VERSION" "$ZIP" \
  --title "Grammar Llama $VERSION" \
  --notes "Download, unzip, drag **Grammar Llama.app** to Applications. First launch: right-click the app and choose Open (the build is not yet notarized). Then allow Accessibility and add your Anthropic or OpenAI API key."
