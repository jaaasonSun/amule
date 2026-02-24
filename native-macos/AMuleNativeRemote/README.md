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
