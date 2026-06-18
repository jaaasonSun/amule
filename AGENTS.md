# AGENTS.md

This file is the starting point for coding agents working in this repository.

## Repository Shape

- `src/`: upstream aMule C++/wxWidgets application, daemon, EC bridge, webserver, and shared C++ libraries.
- `unittests/`: C++ unit tests for core aMule code.
- `native-macos/AMuleNativeRemote/`: Swift native remote GUI work for macOS, iOS, iPadOS, shared Swift UI, and pure Swift EC protocol work.
- `native-macos/AMuleNativeRemote/SwiftEC/`: pure Swift aMule External Connections implementation. Prefer this for Apple platform EC behavior.
- `native-macos/AMuleNativeRemote/SharedUI/`: SwiftUI components and classifiers shared by native Apple clients.
- `native-macos/AMuleNativeRemote/iOS/`: iOS/iPadOS app, SwiftPM shared package, and Xcode project glue.
- `.sisyphus/`: historical plans, evidence, and notes from prior agent work. This directory is ignored and may exist locally only.

## Worktree Rules

- The worktree may be dirty. Do not revert or delete existing changes unless the user explicitly asks.
- Treat generated build products as disposable, but do not remove them without user approval. Common local artifacts include `build/`, `build-filename/`, `native-macos/AMuleNativeRemote/.build/`, `native-macos/AMuleNativeRemote/iOS/.build/`, and `build-ios-bridge-probe/`.
- Use `rg`/`rg --files` for search. Exclude `.build` directories when scanning Swift code.
- Use `apply_patch` for manual edits.
- Keep macOS and iOS platform behavior separate. Do not make macOS adopt iPhone navigation, tab structure, or mobile-only chrome.

## Native Apple App Map

Read the detailed guide at `native-macos/AMuleNativeRemote/docs/coding-agent-field-guide.md` before making native macOS/iOS changes.

Key files:
- macOS app entry/model: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AMuleNativeRemoteApp.swift`, `AppModel.swift`, `ContentView.swift`, `SecondaryWindows.swift`
- macOS platform services: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/MacOSPlatformServices.swift`
- iOS app entry/model/views: `native-macos/AMuleNativeRemote/iOS/AMuleRemoteiOS/AMuleRemoteiOSApp.swift`, `ContentView.swift`, `IOSAppModel.swift`, `DownloadsView.swift`, `SearchView.swift`, `ServersView.swift`, `SettingsView.swift`
- iOS shared logic: `native-macos/AMuleNativeRemote/iOS/Sources/AMuleRemoteIOSShared/`
- shared SwiftUI/helpers: `native-macos/AMuleNativeRemote/SharedUI/Sources/SharedUI/`
- Swift EC protocol/client: `native-macos/AMuleNativeRemote/SwiftEC/Sources/`

## Build And Test Commands

From `native-macos/AMuleNativeRemote`:

```bash
swift test
swift build -Xswiftc -warnings-as-errors
./scripts/build-app.sh
```

From `native-macos/AMuleNativeRemote/SwiftEC`:

```bash
swift test
./Scripts/check-forbidden-deps.sh
```

For the iOS app test target, run from `native-macos/AMuleNativeRemote`:

```bash
xcodebuild -project AMuleRemoteiOS.xcodeproj -scheme AMuleRemoteiOS -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5" -derivedDataPath /tmp/amule-ios-sim-test test
```

For the iOS app target, build from `native-macos/AMuleNativeRemote`:

```bash
xcodebuild -project AMuleRemoteiOS.xcodeproj -scheme AMuleRemoteiOS -configuration Debug -destination "platform=iOS,id=00008150-001C48DE3C20401C" -derivedDataPath /tmp/amule-iphone-build build
```

Installed devices seen during current work:
- iPhone 17 Pro: `devicectl` id `2E94E375-C0E4-5B56-976C-BB889C3BEAC4`, Xcode destination id `00008150-001C48DE3C20401C`
- iPad Pro 11-inch M4: `devicectl` id `E4E07D65-61B7-5009-BF61-808A229D6A94`

Install current iOS build:

```bash
xcrun devicectl device install app --device <DEVICE_ID> /tmp/amule-iphone-build/Build/Products/Debug-iphoneos/AMuleRemoteiOS.app
```

## Current Native-App Priorities

See `docs/superpowers/plans/2026-05-20-native-macos-ios-stabilization.md`.

High-priority themes:
- consolidate duplicated macOS/iOS bridge contracts;
- reduce oversized SwiftUI/model files into focused units;
- add iOS URL-opening/HUD tests for `ed2k://` and `magnet:?` intake;
- add iPad compact/regular layout tests or documented manual QA;
- clean generated SwiftPM/Xcode build artifacts from source control noise;
- extend CI beyond C++/i18n to Swift packages and native app smoke builds.
