#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="${AMULE_APP_NAME:-aMule Remote}"
APP_PATH="$ROOT_DIR/dist/${APP_NAME}.app"

echo "[1/3] Swift strict build"
cd "$ROOT_DIR"
swift build -Xswiftc -warnings-as-errors

echo "[2/3] Build release app bundle"
"$ROOT_DIR/scripts/build-app.sh"

echo "[3/3] Verify bundle contents"
test -x "$APP_PATH/Contents/MacOS/$APP_NAME"
plutil -lint "$APP_PATH/Contents/Info.plist" >/dev/null

echo "Release checks passed:"
echo "  $APP_PATH"
