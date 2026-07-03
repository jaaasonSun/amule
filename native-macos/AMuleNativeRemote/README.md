# aMule Remote (macOS)

Native macOS remote GUI for aMule, built with SwiftUI/AppKit and backed by the pure Swift EC client.

This app is entirely vibe coded.

## What This Branch Adds
- A new native macOS remote GUI under `native-macos/AMuleNativeRemote`
- A pure Swift EC client used by the app to talk to aMule External Connections
- macOS-first UI work (Tahoe-friendly glass/transparency styling, toolbar tuning, sidebar-driven navigation)

## Prerequisites
- macOS with Swift toolchain / Xcode Command Line Tools installed
- Running `amuled` or aMule core with **External Connections** enabled

## Local Development

Open `AMuleNativeRemote.xcworkspace` in Xcode for macOS and iOS development.
The workspace references `AMuleNativeRemote.xcodeproj` for macOS,
`iOS/AMuleRemoteiOS.xcodeproj` for iOS, and both local Swift packages
(`Packages/Shared` and `SwiftEC`).

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
- `AMULE_MIN_MACOS` (default `27.0`, derived from Xcode project `MACOSX_DEPLOYMENT_TARGET`)
- `AMULE_LSUIELEMENT` (`true` / `false`, default `false`)
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
- Swift strict build succeeds (`-warnings-as-errors`)
- release app bundle builds
- app executable and app plist are valid

Current status: this script passes on the current branch state.

## Sign and Notarize
```bash
AMULE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
AMULE_NOTARY_PROFILE="notarytool-profile-name" \
./scripts/sign-notarize.sh
```

If `AMULE_NOTARY_PROFILE` is omitted, signing is performed and notarization is skipped.

## Release Process

Bump version before cutting a release:

```bash
./scripts/bump-version.sh 0.2.0
```

This updates `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in both the macOS and iOS Xcode projects.

Then build and create the GitHub release:

```bash
# macOS
AMULE_APP_VERSION=0.2.0 ./scripts/build-app.sh

# iOS (unsigned for AltStore)
AMULE_IOS_CODE_SIGNING_ALLOWED=NO ./scripts/build-ios-altstore.sh

# Create release
gh release create v0.2.0 \
  --title "aMule Remote 0.2.0" \
  --notes "Release notes..." \
  dist/aMule\ Remote.app.zip \
  dist/ios-altstore/AMuleRemoteiOS-0.2.0-*.ipa
```

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
