#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
APP_NAME="aMule Native Remote"
BUNDLE_ID="org.amule.native.remote"
BUILD_COMMIT="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo dev)"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$ROOT_DIR/dist/${APP_NAME}.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"
PLIST_PATH="$APP_DIR/Contents/Info.plist"
DEFAULT_BRIDGE_SRC="$REPO_ROOT/build/src/amule-ec-bridge"
BRIDGE_SRC="${AMULE_EC_BRIDGE_PATH:-${AMULECMD_PATH:-$DEFAULT_BRIDGE_SRC}}"
DEFAULT_ICON_SRC="$REPO_ROOT/build/src/aMuleGUI.app/Contents/Resources/amule.icns"
ICON_SRC="${AMULE_ICON_PATH:-$DEFAULT_ICON_SRC}"

mkdir -p "$ROOT_DIR/dist"
swift build -c release --package-path "$ROOT_DIR"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"
cp "$BUILD_DIR/AMuleNativeRemote" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

if [[ ! -x "$BRIDGE_SRC" ]]; then
  echo "ERROR: amule-ec-bridge executable not found at: $BRIDGE_SRC" >&2
  echo "Build bridge first (cmake --build \"$REPO_ROOT/build\" --target amule-ec-bridge) or set AMULE_EC_BRIDGE_PATH." >&2
  exit 1
fi
cp "$BRIDGE_SRC" "$RES_DIR/amule-ec-bridge"
chmod +x "$RES_DIR/amule-ec-bridge"

cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleVersion</key>
  <string>0.1.0</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>AMuleBuildCommit</key>
  <string>${BUILD_COMMIT}</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

if [[ -f "$ICON_SRC" ]]; then
  cp "$ICON_SRC" "$RES_DIR/amule.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string amule.icns" "$PLIST_PATH" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile amule.icns" "$PLIST_PATH"
fi

echo "Built: $APP_DIR"
