# aMule Native Remote (macOS)

Native macOS remote GUI for aMule, built with SwiftUI/AppKit and backed by `amule-ec-bridge`.

## Features
- Native downloads window with sortable queue and context actions
- Separate Search / Servers / Details / Diagnostics windows
- External Connection login panel (host/port/password)
- Bundled `amule-ec-bridge` in app resources
- Menubar status item with optional Dock icon behavior at runtime

## Prerequisites
- macOS 13+
- Xcode command line tools (`swift`, `xcode-select --install`)
- Built bridge binary (`build/src/amule-ec-bridge`)
- Running `amuled`/aMule core with External Connections enabled

## Local Development
```bash
cd /path/to/amule/native-macos/AMuleNativeRemote
swift run
```

## Build App Bundle
```bash
cd /path/to/amule/native-macos/AMuleNativeRemote
./scripts/build-app.sh
open "dist/aMule Native Remote.app"
```

Useful build env vars:
- `AMULE_APP_VERSION` (default `0.1.0`)
- `AMULE_BUILD_NUMBER` (default: same as version)
- `AMULE_BUNDLE_ID` (default `org.amule.native.remote`)
- `AMULE_MIN_MACOS` (default `13.0`)
- `AMULE_LSUIELEMENT` (`true`/`false`, default `false`)
- `AMULE_EC_BRIDGE_PATH` (custom bridge path)
- `AMULE_ICON_PATH` (custom `.icns` path)

Example:
```bash
AMULE_APP_VERSION=0.2.0 \
AMULE_BUILD_NUMBER=200 \
AMULE_ICON_PATH=/path/to/amule.icns \
./scripts/build-app.sh
```

## Release Checklist
Run pre-release checks:
```bash
./scripts/release-check.sh
```

This script validates:
- bridge build succeeds
- Swift strict build succeeds (`-warnings-as-errors`)
- release app bundle builds
- bundled executables and plist are valid

## Sign and Notarize
```bash
AMULE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
AMULE_NOTARY_PROFILE="notarytool-profile-name" \
./scripts/sign-notarize.sh
```

If `AMULE_NOTARY_PROFILE` is omitted, signing is done but notarization is skipped.

## Icon Workflow
Create/import icon in macOS Icon Composer, export `.icns`, then build with:
```bash
AMULE_ICON_PATH=/absolute/path/to/amule.icns ./scripts/build-app.sh
```

An outline SVG starter asset is included at:
- `assets/icons/amule-download-icon.svg`
