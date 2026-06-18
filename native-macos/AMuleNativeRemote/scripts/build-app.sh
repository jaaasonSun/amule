#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
APP_NAME="${AMULE_APP_NAME:-aMule Remote}"
APP_VERSION="${AMULE_APP_VERSION:-0.1.1}"
BUILD_NUMBER="${AMULE_BUILD_NUMBER:-$APP_VERSION}"
BUILD_COMMIT="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo dev)"
XCODE_DERIVED_DATA_PATH="${AMULE_XCODE_DERIVED_DATA:-${TMPDIR:-/tmp}/amule-xcodebuild}"
APP_DIR="$ROOT_DIR/dist/${APP_NAME}.app"

mkdir -p "$ROOT_DIR/dist"

xcodebuild \
  -project "$ROOT_DIR/AMuleNativeRemote.xcodeproj" \
  -scheme AMuleNativeRemote \
  -configuration Release \
  -destination "platform=macOS" \
  -derivedDataPath "$XCODE_DERIVED_DATA_PATH" \
  build

XCODE_PRODUCTS_DIR="$XCODE_DERIVED_DATA_PATH/Build/Products/Release"
BUILT_APP="$XCODE_PRODUCTS_DIR/${APP_NAME}.app"

rm -rf "$APP_DIR"
cp -R "$BUILT_APP" "$APP_DIR"

echo "Built: $APP_DIR"
