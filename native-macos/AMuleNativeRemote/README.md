# aMule Remote (macOS)

Native macOS remote GUI for aMule, built with SwiftUI/AppKit and backed by a bundled
`amule-ec-bridge`.

This app is entirely vibe coded.

## What This Branch Adds
- A new native macOS remote GUI under `native-macos/AMuleNativeRemote`
- A small EC bridge binary (`amule-ec-bridge`) used by the app to talk to aMule External Connections
- macOS-first UI work (Tahoe-friendly glass/transparency styling, toolbar tuning, sidebar-driven navigation)

## Prerequisites
- macOS with Swift toolchain / Xcode Command Line Tools installed
- Built bridge binary at `build/src/amule-ec-bridge` (or provide a custom path)
- Running `amuled` or aMule core with **External Connections** enabled

## Local Development
```bash
cd /path/to/amule/native-macos/AMuleNativeRemote
swift run
```

## Build App Bundle (Release)
`build-app.sh` builds the Swift app in **release mode** and packages the `.app`.

```bash
cd /path/to/amule/native-macos/AMuleNativeRemote
./scripts/build-app.sh
open "dist/aMule Remote.app"
```

### Rebuilding After Homebrew Upgrades

If you run `brew upgrade` and update packages like `wxwidgets` or `cryptopp`, the bundled `amule-ec-bridge` binary may fail to start with "library not found" errors. This happens because the binary was linked against specific versioned library paths that no longer exist after the upgrade.

To rebuild the bridge with updated library paths:

```bash
# From the repository root
cd /path/to/amule

# Clean CMake cache to force rediscovery of library paths
rm -rf build-native-bridge/CMakeCache.txt build-native-bridge/CMakeFiles

# Reconfigure and rebuild the bridge
cmake -B build-native-bridge -S . -DCMAKE_BUILD_TYPE=Release -DBUILD_AMULE_EC_BRIDGE=ON -DBUILD_MONOLITHIC=OFF -DBUILD_DAEMON=OFF -DBUILD_REMOTEGUI=OFF
cmake --build build-native-bridge --target amule-ec-bridge -j$(sysctl -n hw.ncpu)

# Rebuild the macOS app with the updated bridge
cd native-macos/AMuleNativeRemote
rm -rf "dist/aMule Remote.app"
AMULE_EC_BRIDGE_PATH=/path/to/amule/build-native-bridge/src/amule-ec-bridge ./scripts/build-app.sh
```

The rebuilt binary will use Homebrew's stable `/opt/homebrew/opt/` symlinks (e.g., `libwx_baseu-3.3.dylib` instead of `libwx_baseu-3.3.1.0.0.dylib`), making it resilient to minor version upgrades.

Useful build env vars:
- `AMULE_APP_VERSION` (default `0.1.0`)
- `AMULE_BUILD_NUMBER` (default: same as version)
- `AMULE_BUNDLE_ID` (default `org.amule.native.remote`)
- `AMULE_MIN_MACOS` (default `13.0`)
- `AMULE_LSUIELEMENT` (`true` / `false`, default `false`)
- `AMULE_EC_BRIDGE_PATH` (custom bridge path)
- `AMULE_ICON_PATH` (custom `.icns` file or Tahoe `.icon` bundle path)
- `AMULE_ICON_NAME` (icon set name when using a `.icon` bundle)

Example:
```bash
AMULE_APP_VERSION=0.2.0 \
AMULE_BUILD_NUMBER=200 \
AMULE_ICON_PATH=/path/to/aMule.icon \
./scripts/build-app.sh
```

## Release Checks
Run pre-release checks:
```bash
./scripts/release-check.sh
```

This validates:
- bridge build succeeds
- Swift strict build succeeds (`-warnings-as-errors`)
- release app bundle builds
- bundled executables and app plist are valid

Current status: this script passes on the current branch state.

## Sign and Notarize
```bash
AMULE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
AMULE_NOTARY_PROFILE="notarytool-profile-name" \
./scripts/sign-notarize.sh
```

If `AMULE_NOTARY_PROFILE` is omitted, signing is performed and notarization is skipped.

## Icon Workflow
This branch supports both:
- classic `.icns`
- Tahoe-style `.icon` bundles (compiled with `actool` when available)

Examples:
```bash
AMULE_ICON_PATH=/absolute/path/to/amule.icns ./scripts/build-app.sh
```

```bash
AMULE_ICON_PATH=/absolute/path/to/aMule.icon ./scripts/build-app.sh
```
