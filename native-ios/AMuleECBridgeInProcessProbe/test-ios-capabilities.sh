#!/bin/sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="$ROOT_DIR/build-ios-bridge-probe"
DERIVED_INCLUDE_DIR="$BUILD_DIR/include"
IOS_OBJECT="$BUILD_DIR/AMuleECBridgeCore-iossim.o"
IOS_LIB="$BUILD_DIR/libAMuleECBridgeCore-iossim.a"
HOST_PROBE="$BUILD_DIR/capabilities-probe"
JSON_OUT="$BUILD_DIR/capabilities.json"

mkdir -p "$BUILD_DIR" "$DERIVED_INCLUDE_DIR"

cat > "$DERIVED_INCLUDE_DIR/config.h" <<'CONFIG_EOF'
#ifndef AMULE_CONFIG_H
#define AMULE_CONFIG_H
#define VERSION "GIT"
#endif
CONFIG_EOF

IOS_SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"

xcrun --sdk iphonesimulator clang++ \
	-std=c++17 \
	-arch arm64 \
	-isysroot "$IOS_SDK" \
	-mios-simulator-version-min=17.0 \
	-I"$DERIVED_INCLUDE_DIR" \
	-I"$ROOT_DIR/src" \
	-c "$ROOT_DIR/src/AMuleECBridgeCore.cpp" \
	-o "$IOS_OBJECT"

xcrun --sdk iphonesimulator libtool -static "$IOS_OBJECT" -o "$IOS_LIB"

clang++ \
	-std=c++17 \
	-I"$DERIVED_INCLUDE_DIR" \
	-I"$ROOT_DIR/src" \
	"$ROOT_DIR/native-ios/AMuleECBridgeInProcessProbe/CapabilitiesProbe.cpp" \
	"$ROOT_DIR/src/AMuleECBridgeCore.cpp" \
	-o "$HOST_PROBE"

"$HOST_PROBE" > "$JSON_OUT"

python3 - "$JSON_OUT" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    payload = json.load(handle)

assert payload["ok"] is True
assert payload["schema_version"] == 1
capabilities = payload["capabilities"]
assert capabilities["client_name"] == "aMuleNativeBridge"
assert capabilities["default_host"] == "127.0.0.1"
assert capabilities["default_port"] == 4712
assert "capabilities" in capabilities["ops"]
assert "status" in capabilities["ops"]

print(json.dumps(payload, separators=(",", ":")))
PY

echo "iOS simulator static library: $IOS_LIB"
xcrun lipo -info "$IOS_LIB"
