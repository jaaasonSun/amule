#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
APP_NAME="${AMULE_APP_NAME:-aMule Remote}"
BUNDLE_ID="${AMULE_BUNDLE_ID:-org.amule.remote}"
APP_VERSION="${AMULE_APP_VERSION:-0.1.0}"
BUILD_NUMBER="${AMULE_BUILD_NUMBER:-$APP_VERSION}"
MIN_MACOS_VERSION="${AMULE_MIN_MACOS:-13.0}"
LS_UI_ELEMENT="${AMULE_LSUIELEMENT:-false}"
BUILD_COMMIT="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo dev)"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$ROOT_DIR/dist/${APP_NAME}.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"
PLIST_PATH="$APP_DIR/Contents/Info.plist"
DEFAULT_BRIDGE_SRC="$REPO_ROOT/build/src/amule-ec-bridge"
BRIDGE_SRC="${AMULE_EC_BRIDGE_PATH:-${AMULECMD_PATH:-$DEFAULT_BRIDGE_SRC}}"
DEFAULT_TAHOE_ICON_SRC="$ROOT_DIR/aMule.icon"
DEFAULT_ICON_SRC="$REPO_ROOT/build/src/aMuleGUI.app/Contents/Resources/amule.icns"
LOCALIZATION_SRC_DIR="$ROOT_DIR/Resources"
ICON_SRC="${AMULE_ICON_PATH:-}"
if [[ -z "$ICON_SRC" && -d "$DEFAULT_TAHOE_ICON_SRC" ]]; then
  ICON_SRC="$DEFAULT_TAHOE_ICON_SRC"
fi
if [[ -z "$ICON_SRC" ]]; then
  ICON_SRC="$DEFAULT_ICON_SRC"
fi

LS_UI_ELEMENT_NORMALIZED="$(printf '%s' "$LS_UI_ELEMENT" | tr '[:upper:]' '[:lower:]')"

case "$LS_UI_ELEMENT_NORMALIZED" in
  1|true|yes|on) LS_UI_ELEMENT_PLIST="<true/>" ;;
  0|false|no|off) LS_UI_ELEMENT_PLIST="<false/>" ;;
  *)
    echo "ERROR: invalid AMULE_LSUIELEMENT value: $LS_UI_ELEMENT (expected true/false)" >&2
    exit 1
    ;;
esac

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
  <string>${BUILD_NUMBER}</string>
  <key>CFBundleShortVersionString</key>
  <string>${APP_VERSION}</string>
  <key>AMuleBuildCommit</key>
  <string>${BUILD_COMMIT}</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>LSMinimumSystemVersion</key>
  <string>${MIN_MACOS_VERSION}</string>
  <key>LSUIElement</key>
  ${LS_UI_ELEMENT_PLIST}
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

if [[ -f "$ICON_SRC" ]]; then
  cp "$ICON_SRC" "$RES_DIR/amule.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string amule" "$PLIST_PATH" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile amule" "$PLIST_PATH"
elif [[ -d "$ICON_SRC" && "$ICON_SRC" == *.icon ]]; then
  if command -v xcrun >/dev/null 2>&1; then
    ICON_NAME="${AMULE_ICON_NAME:-$(basename "$ICON_SRC" .icon)}"
    PARTIAL_ICON_PLIST="$ROOT_DIR/.build/icon-partial.plist"
    rm -f "$PARTIAL_ICON_PLIST"
    xcrun actool \
      --compile "$RES_DIR" \
      --platform macosx \
      --minimum-deployment-target "$MIN_MACOS_VERSION" \
      --app-icon "$ICON_NAME" \
      --output-partial-info-plist "$PARTIAL_ICON_PLIST" \
      "$ICON_SRC" >/dev/null

    if [[ -f "$PARTIAL_ICON_PLIST" ]]; then
      ICON_FILE_VALUE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$PARTIAL_ICON_PLIST" 2>/dev/null || true)"
      ICON_NAME_VALUE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$PARTIAL_ICON_PLIST" 2>/dev/null || true)"
      if [[ -n "$ICON_FILE_VALUE" ]]; then
        /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string $ICON_FILE_VALUE" "$PLIST_PATH" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile $ICON_FILE_VALUE" "$PLIST_PATH"
      fi
      if [[ -n "$ICON_NAME_VALUE" ]]; then
        /usr/libexec/PlistBuddy -c "Add :CFBundleIconName string $ICON_NAME_VALUE" "$PLIST_PATH" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Set :CFBundleIconName $ICON_NAME_VALUE" "$PLIST_PATH"
      fi
    fi
  else
    echo "WARNING: xcrun not found; cannot compile .icon bundle at $ICON_SRC" >&2
  fi
fi

if [[ -d "$LOCALIZATION_SRC_DIR" ]]; then
  while IFS= read -r -d '' lproj_dir; do
    cp -R "$lproj_dir" "$RES_DIR/"
  done < <(find "$LOCALIZATION_SRC_DIR" -maxdepth 1 -type d -name '*.lproj' -print0)
fi

echo "Built: $APP_DIR"
