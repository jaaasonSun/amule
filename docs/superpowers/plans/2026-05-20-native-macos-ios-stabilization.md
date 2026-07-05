# Native macOS/iOS Stabilization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stabilize and improve the native macOS/iOS aMule remote apps without changing the core user-facing product direction.

**Architecture:** Preserve native UI per platform while consolidating shared SwiftEC contracts, shared presentation logic, and verification gates. SwiftEC is the Apple-platform EC implementation.

**Tech Stack:** Swift 6.2/6.3, SwiftUI, AppKit, UIKit, SwiftPM, Xcode, Network.framework, XCTest.

---

## File Structure

- Modify: `.gitignore`
- Create or modify: `.github/workflows/native-apple.yml`
- Modify: `native-macos/AMuleNativeRemote/Package.swift`
- Modify: `native-macos/AMuleNativeRemote/README.md`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/BridgeProtocol.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/ContentView.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/SecondaryWindows.swift`
- Modify: `native-macos/AMuleNativeRemote/iOS/AMuleRemoteiOS/IOSAppModel.swift`
- Modify: `native-macos/AMuleNativeRemote/iOS/AMuleRemoteiOS/ContentView.swift`
- Modify: `native-macos/AMuleNativeRemote/iOS/AMuleRemoteiOS/DownloadsView.swift`
- Modify: `native-macos/AMuleNativeRemote/iOS/AMuleRemoteiOS/SearchView.swift`
- Modify: `native-macos/AMuleNativeRemote/iOS/Sources/AMuleRemoteIOSShared/`
- Modify: `native-macos/AMuleNativeRemote/SharedUI/Sources/SharedUI/`
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/`
- Add tests under matching `Tests/` directories.

## Task 1: Source-Control Hygiene For Native Build Artifacts

**Files:**
- Modify: `.gitignore`

- [x] Add ignore entries for nested SwiftPM/Xcode artifacts.

```gitignore
# Native iOS nested SwiftPM/Xcode artifacts
native-macos/AMuleNativeRemote/iOS/.build/
native-macos/AMuleNativeRemote/iOS/DerivedData/
build-ios-bridge-probe/
```

- [x] Run: `git status --short --ignored native-macos/AMuleNativeRemote/iOS/.build build-ios-bridge-probe`

Expected: existing artifacts are ignored after cleanup or no longer appear as normal untracked files.

## Task 2: Add Native Apple CI Gates

**Files:**
- Create: `.github/workflows/native-apple.yml`

- [x] Add a macOS workflow that runs SwiftEC, SharedUI, iOS app tests, native macOS tests, and a packaging smoke build.
- [x] Route SwiftPM CI commands through a shared build path with index-store disabled to avoid multi-GB duplicated `.build` trees in the repository.

```yaml
name: Native Apple CI

on:
  push:
    branches: ["*"]
  pull_request:
    branches: ["*"]

jobs:
  swift:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: SwiftEC tests
        run: native-macos/AMuleNativeRemote/scripts/swiftpm.sh test --package-path native-macos/AMuleNativeRemote/SwiftEC
      - name: SharedUI tests
        run: native-macos/AMuleNativeRemote/scripts/swiftpm.sh test --package-path native-macos/AMuleNativeRemote/SharedUI
      - name: iOS app tests
        run: cd native-macos/AMuleNativeRemote && xcodebuild -project AMuleRemoteiOS.xcodeproj -scheme AMuleRemoteiOS -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5" test SWIFT_ENABLE_EXPLICIT_MODULES=NO
      - name: Native macOS tests
        run: native-macos/AMuleNativeRemote/scripts/swiftpm.sh test --package-path native-macos/AMuleNativeRemote
      - name: Native macOS strict build
        run: native-macos/AMuleNativeRemote/scripts/swiftpm.sh build --package-path native-macos/AMuleNativeRemote -Xswiftc -warnings-as-errors
      - name: Packaging smoke
        run: cd native-macos/AMuleNativeRemote && ./scripts/build-app.sh && plutil -lint "dist/aMule Remote.app/Contents/Info.plist"
```

- [x] Run each command locally before relying on CI.

## Task 3: Consolidate Bridge Protocol Contracts

**Files:**
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/BridgeProtocol.swift`
- Modify: `native-macos/AMuleNativeRemote/iOS/Sources/AMuleRemoteIOSShared/BridgeProtocol.swift`
- Prefer creating shared definitions in either `SwiftEC` or a small shared package if package cycles can be avoided.

- [x] Inventory method differences. Current iOS shared protocol has rename/cancel/servers/server CRUD/sources/prefs operations that the macOS protocol file does not fully mirror.
- [x] Move shared payload/protocol definitions to one package consumed by both macOS and iOS, or add an explicit compatibility shim with tests proving both app adapters expose the same v1 operation set.
- [x] Add tests that fail when a v1 operation exists on iOS but is missing on macOS or SwiftEC adapter.

Run:

```bash
cd native-macos/AMuleNativeRemote && swift test --filter AMuleNativeRemoteTests
cd native-macos/AMuleNativeRemote && xcodebuild -project AMuleRemoteiOS.xcodeproj -scheme AMuleRemoteiOS -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5" -derivedDataPath /tmp/amule-ios-sim-test test
```

## Task 4: Split Oversized Model And Window Files

**Files:**
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/ContentView.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/SecondaryWindows.swift`
- Modify: `native-macos/AMuleNativeRemote/iOS/AMuleRemoteiOS/IOSAppModel.swift`

- [x] Extract link import/HUD behavior into a focused model/service shared by macOS and iOS.
- [ ] Extract server-management actions from `AppModel`/`IOSAppModel` into focused helpers with injectable bridge dependency.
- [x] Extract transfer-limit preference input parsing/validation into a small shared model used by macOS and iOS.
- [ ] Split `SecondaryWindows.swift` by surface: search, downloads detail, servers, diagnostics, preferences, deferred windows.
- [ ] Add tests before extraction for current behavior, then run them after each file split.

Run:

```bash
cd native-macos/AMuleNativeRemote && swift test
cd native-macos/AMuleNativeRemote && xcodebuild -project AMuleRemoteiOS.xcodeproj -scheme AMuleRemoteiOS -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5" -derivedDataPath /tmp/amule-ios-sim-test test
```

## Task 5: Harden iOS URL Intake And Add HUD Feedback

**Files:**
- Modify: `native-macos/AMuleNativeRemote/iOS/AMuleRemoteiOS/Info.plist`
- Modify: `native-macos/AMuleNativeRemote/iOS/AMuleRemoteiOS/ContentView.swift`
- Modify: `native-macos/AMuleNativeRemote/iOS/AMuleRemoteiOS/IOSAppModel.swift`
- Modify: `native-macos/AMuleNativeRemote/iOS/Sources/AMuleRemoteIOSShared/IOSPlatformServices.swift`
- Modify: `native-macos/AMuleNativeRemote/SharedUI/Sources/SharedUI/SharedEmptyState.swift`
- Add tests: `native-macos/AMuleNativeRemote/iOS/Tests/AMuleRemoteIOSTests/IOSIncomingLinksTests.swift`

- [x] Keep `ed2k` and `magnet` URL schemes registered.
- [x] Test that `IOSDeepLinkHandler.handleOpenURL` accepts percent-encoded `ed2k://%7C...` and `magnet:?xt=urn:ed2k:...`.
- [x] Test disconnected intake queues links and connected/foreground intake flushes links.
- [x] Surface add-link status in iOS using the same `AddLinksHUD` style as macOS or a native equivalent.
- [x] Show success and partial failure messages without blocking the user with an alert.

Run:

```bash
cd native-macos/AMuleNativeRemote && xcodebuild -project AMuleRemoteiOS.xcodeproj -scheme AMuleRemoteiOS -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5" -derivedDataPath /tmp/amule-ios-sim-test test
```

## Task 6: Formalize iPad/iPhone Layout Rules

**Files:**
- Modify: `native-macos/AMuleNativeRemote/iOS/AMuleRemoteiOS/ContentView.swift`
- Modify: `native-macos/AMuleNativeRemote/iOS/AMuleRemoteiOS/DownloadsView.swift`
- Add tests or static validation under `native-macos/AMuleNativeRemote/iOS/Tests/AMuleRemoteIOSTests/`

- [x] Keep iPhone/compact iPad downloads-first `TabView` layout with compact search/filter/sort reachable from Downloads.
- [x] Keep iPad regular width sidebar/detail layout with top `.searchable`.
- [x] Keep iPad compact width from stranding users in sidebar-only mode.
- [x] Add a static UI validation test for `DownloadsViewPresentation` rules and a manual QA checklist for real iPad resizing.

Run:

```bash
cd native-macos/AMuleNativeRemote && xcodebuild -project AMuleRemoteiOS.xcodeproj -scheme AMuleRemoteiOS -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5" -derivedDataPath /tmp/amule-ios-sim-test test
cd native-macos/AMuleNativeRemote && xcodebuild -project AMuleRemoteiOS.xcodeproj -scheme AMuleRemoteiOS -configuration Debug -destination "platform=iOS,id=00008150-001C48DE3C20401C" -derivedDataPath /tmp/amule-iphone-build build
```

## Task 7: Normalize Localization Ownership

**Files:**
- Modify: `native-macos/AMuleNativeRemote/Resources/*.lproj/Localizable.strings`
- Modify: `native-macos/AMuleNativeRemote/iOS/AMuleRemoteiOS/*.lproj/Localizable.strings`
- Modify Swift callsites with hard-coded strings only when covered by tests or clearly user-visible.

- [ ] Create a script or test that finds user-visible Swift string literals in iOS views not routed through `L`/`LF` or `LocalizedStringKey`.
- [ ] Decide whether iOS keeps copied `.strings` files or consumes a shared localization resource.
- [ ] Add missing keys for URL intake HUD/status messages and iPad layout labels.

Run:

```bash
cd native-macos/AMuleNativeRemote && xcodebuild -project AMuleRemoteiOS.xcodeproj -scheme AMuleRemoteiOS -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5" -derivedDataPath /tmp/amule-ios-sim-test test
```

## Task 8: SwiftEC Protocol Parity And Regression Coverage

**Files:**
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECOperations.swift`
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECResponseParser.swift`
- Modify tests under `native-macos/AMuleNativeRemote/SwiftEC/Tests/`

- [ ] Add fixture-backed tests for every app-exposed operation: add-link, rename, pause, resume, cancel, servers, server CRUD, sources, prefs get/set.
- [ ] Add regression tests for EC tag IDs that have previously caused daemon disconnects, especially rename.
- [ ] Keep `SwiftEC/Scripts/check-forbidden-deps.sh` passing.

Run:

```bash
cd native-macos/AMuleNativeRemote/SwiftEC && swift test
cd native-macos/AMuleNativeRemote/SwiftEC && ./Scripts/check-forbidden-deps.sh
```

## Final Verification

Run:

```bash
cd native-macos/AMuleNativeRemote/SwiftEC && swift test
cd native-macos/AMuleNativeRemote/SharedUI && swift test
cd native-macos/AMuleNativeRemote && xcodebuild -project AMuleRemoteiOS.xcodeproj -scheme AMuleRemoteiOS -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5" -derivedDataPath /tmp/amule-ios-sim-test test
cd native-macos/AMuleNativeRemote && swift test
cd native-macos/AMuleNativeRemote && swift build -Xswiftc -warnings-as-errors
cd native-macos/AMuleNativeRemote && ./scripts/build-app.sh
cd native-macos/AMuleNativeRemote && xcodebuild -project AMuleRemoteiOS.xcodeproj -scheme AMuleRemoteiOS -configuration Debug -destination "platform=iOS,id=00008150-001C48DE3C20401C" -derivedDataPath /tmp/amule-iphone-build build
```
