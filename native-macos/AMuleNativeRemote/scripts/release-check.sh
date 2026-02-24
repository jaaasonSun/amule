#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
APP_NAME="${AMULE_APP_NAME:-aMule Remote}"
APP_PATH="$ROOT_DIR/dist/${APP_NAME}.app"

echo "[1/4] Build bridge (amule-ec-bridge)"
cmake --build "$REPO_ROOT/build" --target amule-ec-bridge -j8

echo "[2/4] Swift strict build"
swift build -Xswiftc -warnings-as-errors --package-path "$ROOT_DIR"

echo "[3/4] Build release app bundle"
"$ROOT_DIR/scripts/build-app.sh"

echo "[4/4] Verify bundle contents"
test -x "$APP_PATH/Contents/MacOS/$APP_NAME"
test -x "$APP_PATH/Contents/Resources/amule-ec-bridge"
plutil -lint "$APP_PATH/Contents/Info.plist" >/dev/null

echo "Release checks passed:"
echo "  $APP_PATH"
