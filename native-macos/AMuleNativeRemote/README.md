# aMule Remote (macOS)

Native macOS remote GUI for aMule, built with SwiftUI/AppKit and backed by a bundled
`amule-ec-bridge`.

This app is entirely vibe coded.

## What This Branch Adds
- A new native macOS remote GUI under `native-macos/AMuleNativeRemote`
- A small EC bridge binary (`amule-ec-bridge`) used by the app to talk to aMule External Connections
- macOS-first UI work (Tahoe-friendly glass/transparency styling, toolbar tuning, sidebar-driven navigation)

## Current App Layout (Main Window)
- **Sidebar** contains:
  - download filters:
  - All
  - Downloading
  - Pending
  - Paused
  - Completed
  - Search page (embedded in the main content pane)
- **Footer status bar (content pane only, right of sidebar)** contains:
  - aMule Server button (opens connection/login panel)
  - eD2k button + reconnect action (native two-part control; opens eD2k / server management window)
  - Kad button (opens Kad popup panel)
  - Download / Upload speed readouts

## Current Features
- Native downloads table with:
  - sortable columns (`Name`, `Progress`, `Speed`, `Src`)
  - multi-selection
  - context actions (pause/resume/remove/copy eD2k link)
  - toolbar filter search (name matching)
  - eMule-style progress rendering in progress column
- Single shared **Download Details** window that follows the current download selection
- Download details include:
  - rename (when allowed)
  - eD2k link copy
  - transfer/source info
  - source list embedded in the details window
  - eMule-style segmented progress bar
- Search page:
  - native SwiftUI toolbar search field (`.searchable`)
  - separate scope selector toolbar menu (`Kad`, `Global`, `Local`)
  - multi-select results
  - download selected results
  - stop in-progress search
- eD2k (servers) **window**:
  - sortable server table
  - connect / disconnect / remove
  - add server sheet
  - import server list from remote `.met` URL
- Kad popup panel:
  - Kad status display + inline refresh button
  - download/update `nodes.dat` from URL
- Connection panel for EC login (host / port / password)
- Add-links panel (multi-line `ed2k://` links)
- Menubar item + menu, with dynamic Dock icon visibility behavior
- Bundled `amule-ec-bridge` inside the app bundle
- Simplified Chinese localization (`zh-Hans`, `zh_CN`) for app UI strings

## Extra Windows / Panels
- Search and eD2k standalone windows are still available (alternate workflow / debugging)
- Diagnostics window
- Connection panel, Add Links panel, Kad panel

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
