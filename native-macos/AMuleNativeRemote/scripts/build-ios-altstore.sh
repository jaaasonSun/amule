#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/AMuleRemoteiOS.xcodeproj"
SCHEME="${AMULE_IOS_SCHEME:-AMuleRemoteiOS}"
CONFIGURATION="${AMULE_IOS_CONFIGURATION:-Release}"
DERIVED_DATA_PATH="${AMULE_IOS_DERIVED_DATA:-/tmp/amule-ios-altstore-build}"
DIST_DIR="${AMULE_ALTSTORE_DIST_DIR:-$ROOT_DIR/dist/ios-altstore}"
CODE_SIGNING_ALLOWED="${AMULE_IOS_CODE_SIGNING_ALLOWED:-YES}"
CODE_SIGNING_REQUIRED="${AMULE_IOS_CODE_SIGNING_REQUIRED:-$CODE_SIGNING_ALLOWED}"
SWIFT_ENABLE_EXPLICIT_MODULES="${AMULE_SWIFT_ENABLE_EXPLICIT_MODULES:-NO}"
BASE_URL="${AMULE_ALTSTORE_BASE_URL:-}"
APP_NAME="${AMULE_ALTSTORE_APP_NAME:-aMule Remote}"
SOURCE_NAME="${AMULE_ALTSTORE_SOURCE_NAME:-aMule Remote}"
SOURCE_ID="${AMULE_ALTSTORE_SOURCE_ID:-org.amule.remote.source}"
DEVELOPER_NAME="${AMULE_ALTSTORE_DEVELOPER_NAME:-aMule Project}"
APP_SUBTITLE="${AMULE_ALTSTORE_APP_SUBTITLE:-Native remote client for aMule.}"
APP_DESCRIPTION="${AMULE_ALTSTORE_APP_DESCRIPTION:-A native iPhone and iPad remote client for controlling an aMule daemon over External Connections.}"
VERSION_DESCRIPTION="${AMULE_ALTSTORE_VERSION_DESCRIPTION:-AltStore build.}"
ICON_URL="${AMULE_ALTSTORE_ICON_URL:-}"
TINT_COLOR="${AMULE_ALTSTORE_TINT_COLOR:-#2F7D32}"

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-iphoneos/$SCHEME.app"

mkdir -p "$DIST_DIR"

echo "[1/4] Build $SCHEME ($CONFIGURATION, iphoneos)"
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED="$CODE_SIGNING_ALLOWED" \
  CODE_SIGNING_REQUIRED="$CODE_SIGNING_REQUIRED" \
  SWIFT_ENABLE_EXPLICIT_MODULES="$SWIFT_ENABLE_EXPLICIT_MODULES" \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: built app not found at $APP_PATH" >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Info.plist")"
BUILD_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Info.plist")"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist")"
MIN_OS_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$APP_PATH/Info.plist")"
LOCAL_NETWORK_REASON="$(/usr/libexec/PlistBuddy -c 'Print :NSLocalNetworkUsageDescription' "$APP_PATH/Info.plist")"
RELEASE_DATE="$(date -u +%Y-%m-%d)"
IPA_BASENAME="AMuleRemoteiOS-${VERSION}-${BUILD_VERSION}.ipa"
IPA_PATH="$DIST_DIR/$IPA_BASENAME"
SOURCE_PATH="$DIST_DIR/altstore-source.json"
ICON_PATH="$DIST_DIR/aMule.png"
rm -f "$IPA_PATH" "$SOURCE_PATH" "$ICON_PATH"

echo "[2/4] Package IPA"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
mkdir -p "$TMP_DIR/Payload"
ditto "$APP_PATH" "$TMP_DIR/Payload/$SCHEME.app"
if [[ -f "$APP_PATH/aMule76x76@2x~ipad.png" ]]; then
  cp "$APP_PATH/aMule76x76@2x~ipad.png" "$ICON_PATH"
elif [[ -f "$APP_PATH/aMule60x60@2x.png" ]]; then
  cp "$APP_PATH/aMule60x60@2x.png" "$ICON_PATH"
else
  echo "warning: no app icon PNG found to export for AltStore source icon." >&2
fi
(
  cd "$TMP_DIR"
  /usr/bin/zip -qry "$IPA_PATH" Payload
)

IPA_SIZE="$(stat -f%z "$IPA_PATH")"

echo "[3/4] Validate packaged metadata"
/usr/bin/unzip -p "$IPA_PATH" "Payload/$SCHEME.app/Info.plist" > "$TMP_DIR/Info.plist"
plutil -lint "$TMP_DIR/Info.plist" >/dev/null
/usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes' "$TMP_DIR/Info.plist" >/dev/null
/usr/libexec/PlistBuddy -c 'Print :NSLocalNetworkUsageDescription' "$TMP_DIR/Info.plist" >/dev/null

echo "[4/4] Generate AltStore source metadata"
if [[ -z "$BASE_URL" ]]; then
  echo "warning: AMULE_ALTSTORE_BASE_URL is not set; skipping $SOURCE_PATH generation."
  echo "         Set it to the HTTPS directory where the IPA and icon will be hosted."
else
  BASE_URL="${BASE_URL%/}"
  DOWNLOAD_URL="$BASE_URL/$IPA_BASENAME"
  if [[ -z "$ICON_URL" ]]; then
    ICON_URL="$BASE_URL/aMule.png"
  fi

  AMULE_ALTSTORE_SOURCE_NAME_VALUE="$SOURCE_NAME" \
  AMULE_ALTSTORE_SOURCE_ID_VALUE="$SOURCE_ID" \
  AMULE_ALTSTORE_BUNDLE_ID_VALUE="$BUNDLE_ID" \
  AMULE_ALTSTORE_APP_NAME_VALUE="$APP_NAME" \
  AMULE_ALTSTORE_DEVELOPER_NAME_VALUE="$DEVELOPER_NAME" \
  AMULE_ALTSTORE_APP_SUBTITLE_VALUE="$APP_SUBTITLE" \
  AMULE_ALTSTORE_APP_DESCRIPTION_VALUE="$APP_DESCRIPTION" \
  AMULE_ALTSTORE_ICON_URL_VALUE="$ICON_URL" \
  AMULE_ALTSTORE_TINT_COLOR_VALUE="$TINT_COLOR" \
  AMULE_ALTSTORE_VERSION_VALUE="$VERSION" \
  AMULE_ALTSTORE_BUILD_VERSION_VALUE="$BUILD_VERSION" \
  AMULE_ALTSTORE_RELEASE_DATE_VALUE="$RELEASE_DATE" \
  AMULE_ALTSTORE_VERSION_DESCRIPTION_VALUE="$VERSION_DESCRIPTION" \
  AMULE_ALTSTORE_DOWNLOAD_URL_VALUE="$DOWNLOAD_URL" \
  AMULE_ALTSTORE_IPA_SIZE_VALUE="$IPA_SIZE" \
  AMULE_ALTSTORE_MIN_OS_VERSION_VALUE="$MIN_OS_VERSION" \
  AMULE_ALTSTORE_LOCAL_NETWORK_REASON_VALUE="$LOCAL_NETWORK_REASON" \
  /usr/bin/python3 - "$SOURCE_PATH" <<'PY'
import json
import os
import sys

source_path = sys.argv[1]
source = {
    "name": os.environ["AMULE_ALTSTORE_SOURCE_NAME_VALUE"],
    "identifier": os.environ["AMULE_ALTSTORE_SOURCE_ID_VALUE"],
    "subtitle": "Native aMule remote client builds.",
    "featuredApps": [os.environ["AMULE_ALTSTORE_BUNDLE_ID_VALUE"]],
    "apps": [
        {
            "name": os.environ["AMULE_ALTSTORE_APP_NAME_VALUE"],
            "bundleIdentifier": os.environ["AMULE_ALTSTORE_BUNDLE_ID_VALUE"],
            "developerName": os.environ["AMULE_ALTSTORE_DEVELOPER_NAME_VALUE"],
            "subtitle": os.environ["AMULE_ALTSTORE_APP_SUBTITLE_VALUE"],
            "localizedDescription": os.environ["AMULE_ALTSTORE_APP_DESCRIPTION_VALUE"],
            "iconURL": os.environ["AMULE_ALTSTORE_ICON_URL_VALUE"],
            "tintColor": os.environ["AMULE_ALTSTORE_TINT_COLOR_VALUE"],
            "category": "utilities",
            "versions": [
                {
                    "version": os.environ["AMULE_ALTSTORE_VERSION_VALUE"],
                    "buildVersion": os.environ["AMULE_ALTSTORE_BUILD_VERSION_VALUE"],
                    "date": os.environ["AMULE_ALTSTORE_RELEASE_DATE_VALUE"],
                    "localizedDescription": os.environ["AMULE_ALTSTORE_VERSION_DESCRIPTION_VALUE"],
                    "downloadURL": os.environ["AMULE_ALTSTORE_DOWNLOAD_URL_VALUE"],
                    "size": int(os.environ["AMULE_ALTSTORE_IPA_SIZE_VALUE"]),
                    "minOSVersion": os.environ["AMULE_ALTSTORE_MIN_OS_VERSION_VALUE"],
                }
            ],
            "appPermissions": {
                "entitlements": [],
                "privacy": {
                    "NSLocalNetworkUsageDescription": os.environ["AMULE_ALTSTORE_LOCAL_NETWORK_REASON_VALUE"],
                },
            },
        }
    ],
    "news": [],
}

with open(source_path, "w", encoding="utf-8") as f:
    json.dump(source, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY

  /usr/bin/python3 -m json.tool "$SOURCE_PATH" >/dev/null
fi

echo "AltStore artifacts:"
echo "  IPA: $IPA_PATH"
if [[ -f "$SOURCE_PATH" ]]; then
  echo "  Source: $SOURCE_PATH"
fi
if [[ -f "$ICON_PATH" ]]; then
  echo "  Icon: $ICON_PATH"
fi
