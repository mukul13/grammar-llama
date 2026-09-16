#!/bin/zsh
# Builds "Grammar Llama.app" into ./build and (optionally) launches it.
#   ./scripts/build-app.sh          # build only
#   ./scripts/build-app.sh --run    # build, install to /Applications, launch
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG=release
APP="build/Grammar Llama.app"

swift build -c $CONFIG 2>&1 | grep -v '^\[' || true
BIN=$(swift build -c $CONFIG --show-bin-path)/GrammarLlama
[[ -x "$BIN" ]] || { echo "build failed"; exit 1; }

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/GrammarLlama"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[[ -f Resources/AppIcon.icns ]] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
echo -n 'APPL????' > "$APP/Contents/PkgInfo"

# Signing, best identity first:
#   1. Developer ID Application  -> hardened runtime + timestamp, ready for notarization
#   2. Apple Development         -> fine locally; downloads still trigger Gatekeeper
#   3. ad-hoc                    -> last resort
DEV_ID=$(security find-identity -v -p codesigning 2>/dev/null | grep -m1 "Developer ID Application" | awk '{print $2}' || true)
DEV_CERT=$(security find-identity -v -p codesigning 2>/dev/null | grep -m1 "Apple Development" | awk '{print $2}' || true)
if [[ -n "$DEV_ID" ]]; then
  codesign --force --deep --options runtime --timestamp --sign "$DEV_ID" --identifier com.sidepanda.GrammarLlama "$APP"
  echo "Signed with Developer ID (hardened runtime)"
elif [[ -n "$DEV_CERT" ]]; then
  codesign --force --deep --sign "$DEV_CERT" --identifier com.sidepanda.GrammarLlama "$APP" >/dev/null 2>&1
  echo "Signed with Apple Development identity (not notarizable)"
else
  codesign --force --deep --sign - --identifier com.sidepanda.GrammarLlama "$APP" >/dev/null 2>&1
  echo "Ad-hoc signed"
fi
echo "Built $APP"

# --run installs into /Applications and launches from there, so only one copy of the app is
# ever registered with Launch Services and the Accessibility grant stays stable.
if [[ "${1:-}" == "--run" ]]; then
  pkill -x GrammarLlama 2>/dev/null || true
  sleep 0.3
  rm -rf "/Applications/Grammar Llama.app"
  cp -R "$APP" /Applications/
  rm -rf "$APP"
  open "/Applications/Grammar Llama.app"
  echo "Installed and launched /Applications/Grammar Llama.app"
fi
