#!/bin/zsh
# Builds "Grammar Llama.app" into ./build and (optionally) launches it.
#   ./scripts/build-app.sh          # build only
#   ./scripts/build-app.sh --run    # build and launch
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

# Sign with an Apple Development identity when one exists so the Accessibility grant
# survives rebuilds. Falls back to ad-hoc signing (grant may need re-adding after rebuilds).
SIGN_ID=$(security find-identity -v -p codesigning 2>/dev/null | grep -m1 "Apple Development" | awk '{print $2}')
if [[ -n "$SIGN_ID" ]]; then
  codesign --force --deep --sign "$SIGN_ID" --identifier com.sidepanda.GrammarLlama "$APP" >/dev/null 2>&1 \
    && echo "Signed with Apple Development identity" \
    || codesign --force --deep --sign - --identifier com.sidepanda.GrammarLlama "$APP" >/dev/null 2>&1
else
  codesign --force --deep --sign - --identifier com.sidepanda.GrammarLlama "$APP" >/dev/null 2>&1
fi
echo "Built $APP"

if [[ "${1:-}" == "--run" ]]; then
  pkill -x GrammarLlama 2>/dev/null || true; pkill -x Polish 2>/dev/null || true
  sleep 0.3
  open "$APP"
fi
