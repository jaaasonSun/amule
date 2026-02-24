#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="${AMULE_APP_NAME:-aMule Remote}"
APP_PATH="${AMULE_APP_PATH:-$ROOT_DIR/dist/${APP_NAME}.app}"
ZIP_PATH="${AMULE_ZIP_PATH:-$ROOT_DIR/dist/${APP_NAME}.zip}"
SIGN_IDENTITY="${AMULE_SIGN_IDENTITY:-}"
NOTARY_PROFILE="${AMULE_NOTARY_PROFILE:-}"

if [[ -z "$SIGN_IDENTITY" ]]; then
  echo "ERROR: AMULE_SIGN_IDENTITY is required (e.g. 'Developer ID Application: Your Name (TEAMID)')" >&2
  exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: app bundle not found at: $APP_PATH" >&2
  echo "Build first with ./scripts/build-app.sh" >&2
  exit 1
fi

APP_BIN="$APP_PATH/Contents/MacOS/$APP_NAME"
BRIDGE_BIN="$APP_PATH/Contents/Resources/amule-ec-bridge"

if [[ ! -x "$APP_BIN" ]]; then
  echo "ERROR: app executable not found: $APP_BIN" >&2
  exit 1
fi
if [[ ! -x "$BRIDGE_BIN" ]]; then
  echo "ERROR: bundled bridge not found: $BRIDGE_BIN" >&2
  exit 1
fi

echo "Signing binaries..."
codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY" "$BRIDGE_BIN"
codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY" "$APP_BIN"
codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY" "$APP_PATH"

echo "Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --type execute --verbose=2 "$APP_PATH"

echo "Creating archive..."
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

if [[ -n "$NOTARY_PROFILE" ]]; then
  echo "Submitting to Apple notarization..."
  xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  echo "Stapling ticket..."
  xcrun stapler staple "$APP_PATH"

  echo "Re-creating notarized archive..."
  rm -f "$ZIP_PATH"
  ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
else
  echo "Skipping notarization (AMULE_NOTARY_PROFILE not set)."
fi

echo "Done:"
echo "  App: $APP_PATH"
echo "  Zip: $ZIP_PATH"
