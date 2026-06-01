# Native Apple App Coding Agent Field Guide

This guide summarizes the native macOS/iOS app area for future coding agents.

## Architecture Overview

The native Apple work is split into three layers:

- `AMuleNativeRemote`: macOS SwiftUI/AppKit remote GUI package.
- `AMuleRemoteiOS`: iOS/iPadOS SwiftUI app target, containing app-specific models, platform services, and UI.
- `SharedUI` + `SharedModels` + `SharedServices` + `SwiftEC`: cross-platform shared packages used by both macOS and iOS apps.

The original C++ aMule code remains under `src/`. The native apps should use shared contracts and parsers where practical, but must keep platform-native UI/navigation.

## macOS Native Remote

Package root: `native-macos/AMuleNativeRemote`.

Important files:
- `Package.swift`: executable package, currently macOS v26 in manifest.
- `Sources/AMuleNativeRemote/AppModel.swift`: main `@MainActor` model. It owns connection state, downloads, search, servers, preferences, HUD state, and bridge calls. It is large and should be split carefully.
- `Sources/AMuleNativeRemote/ContentView.swift`: primary downloads window/sidebar and macOS toolbar/footer behavior.
- `Sources/AMuleNativeRemote/SecondaryWindows.swift`: search, details, servers, diagnostics, uploads/shared/categories/friends/stats/preferences windows. This file is very large.
- `Sources/AMuleNativeRemote/MacOSPlatformServices.swift`: pasteboard, deep-link Apple Event handler, credentials, file import/export, lifecycle helpers.
- `Sources/AMuleNativeRemote/AMuleECBridgeClient.swift`: legacy process-based `amule-ec-bridge` invoker.
- `Sources/AMuleNativeRemote/BridgeAdapterFactory.swift`: bridge selection/adaptation between legacy CLI bridge and SwiftEC.

macOS app notes:
- The packaged app registers `ed2k://` in `scripts/build-app.sh`.
- `ContentView` displays an add-links HUD using `AddLinksHUD` when `AppModel.showHUD` is true.
- Keep existing macOS scene/window structure. Do not port iOS navigation back to macOS.
- Preserve `@AppStorage` keys unless adding migration code.

## iOS/iPadOS App

App target root: `native-macos/AMuleNativeRemote/iOS/AMuleRemoteiOS`.

Important files:
- `AMuleRemoteiOSApp.swift`: app entry point.
- `ContentView.swift`: chooses iPhone vs iPad layout. iPad regular uses `NavigationSplitView`; compact width falls back to iPhone-style layout.
- `IOSAppModel.swift`: iOS `@MainActor` model for connection, lifecycle reconnect, downloads, search, servers, rename, URL intake, transfer limits, and sharing.
- `DownloadsView.swift`: download list, filters/sorts, iPhone bottom toolbar, iPad top search via `.searchable`.
- `DownloadDetailView.swift`: download detail/source/rename UI.
- `SearchView.swift`: search form/results and download feedback.
- `ServersView.swift`: local bookmarks and daemon server management.
- `SettingsView.swift`: status, transfer limits, capabilities, URL scheme info.
- `Info.plist`: registers `ed2k` and `magnet` URL schemes, local network usage, single-scene iPad behavior.

iOS/iPadOS app notes:
- iPhone is single-window and uses downloads as home.
- iPad v1 is single-scene. Regular width should use sidebar/detail. Compact width should not strand the user in sidebar-only mode.
- `ed2k://` and `magnet:?` intake flows through `ContentView.onOpenURL` -> `IOSAppModel.handleOpenURL` -> `IOSDeepLinkHandler` -> `PendingIncomingLinkInbox` -> `addLinks`.
- Password is stored via iOS Keychain; macOS currently stores in user defaults.

## SwiftEC

Package root: `native-macos/AMuleNativeRemote/SwiftEC`.

Layering:
- `AMuleECProtocol`: packet/header/tag/compression/auth wire protocol.
- `AMuleECClient`: session, connection, request pipeline, operation builders, response parsing, JSON envelope formatting.
- `AMuleECBridgeAdapter`: conforms SwiftEC to the app bridge protocol style.

Important files:
- `Sources/AMuleECClient/ECOperations.swift`: EC op builders. Be careful with tag IDs; original daemon rename uses `EC_TAG_KNOWNFILE` for the MD4 hash plus `EC_TAG_PARTFILE_NAME` for the new name.
- `Sources/AMuleECClient/ECResponseParser.swift`: tag-to-model parsing.
- `Sources/AMuleECClient/FileNameEncodingRepair.swift`: filename mojibake/percent/entity repair used by macOS and iOS suggestion UI.
- `Docs/Architecture.md`, `Docs/Operations.md`, `Docs/SwiftECV1Contract.md`: protocol and operation references.
- `docs/original-amule-ec-protocol-notes.md`: source-derived notes from the original aMule EC implementation, including daemon-side and original remote-GUI behavior. Use this before treating any bridge wrapper as protocol truth.
- `docs/superpowers/plans/2026-05-23-swiftec-stateful-protocol-repair.md`: repair plan for SwiftEC stateful merge behavior. Use it before changing download, alternative-name, source, or rename refresh behavior.

Run:

```bash
cd native-macos/AMuleNativeRemote/SwiftEC && swift test
cd native-macos/AMuleNativeRemote/SwiftEC && ./Scripts/check-forbidden-deps.sh
```

## Shared Packages

Package root: `native-macos/AMuleNativeRemote/Packages/Shared`.

Targets:
- `SharedModels`: domain models (`DownloadItem`, `ServerItem`, `SearchResult`), formatters, status parser, download source item.
- `SharedViews`: reusable SwiftUI components (`DownloadClassification`, `SharedEmptyState`, `SharedDownloadRow`, `DownloadProgressViews`, `SharedStatusBadge`).
- `SharedServices`: platform abstraction protocols (`PasteboardShare`, `DeepLinkHandling`).

## Known Maintenance Risks

- Several core Swift files are large: `SecondaryWindows.swift` ~2464 lines, `ContentView.swift` ~1390 lines, `AppModel.swift` ~1330 lines, `IOSAppModel.swift` ~821 lines.
- iOS URL handling has Info.plist registration, model plumbing, shared tests for encoded `ed2k`/magnet intake, and HUD feedback. Safari cold-start behavior still deserves manual device QA.
- Build and package artifacts under `native-macos/AMuleNativeRemote/build/`, `dist/`, `.build/`, and `.swiftpm/` are ignored and should stay out of source control.
- Native Swift package checks are covered by `.github/workflows/native-apple.yml`; keep it aligned with the verification checklist.
- macOS README and package/script platform defaults have drifted historically; verify before changing release docs.

## Manual QA Checklist

- iPhone: launch to the downloads list, confirm search/filter/sort stay in the bottom toolbar, and confirm Search/Servers/Settings open as sheets from the downloads toolbar.
- iPad regular width: confirm the sidebar/detail layout shows downloads in the detail area, Search/Servers/Settings live in the sidebar, and downloads search appears in the top toolbar.
- iPad compact-width window: resize the app to phone-like width and confirm it switches to downloads-first navigation rather than showing only the sidebar.
- Incoming links: from Safari, open a percent-encoded `ed2k://%7Cfile...` URL and a `magnet:?xt=urn:ed2k:...` URL; confirm the app opens, queues/imports the link, and shows the add-link HUD without blocking interaction.

## Verification Checklist

Use the smallest relevant set, then expand before claiming completion:

```bash
cd native-macos/AMuleNativeRemote/SwiftEC && swift test
cd native-macos/AMuleNativeRemote/Packages/Shared && swift test
cd native-macos/AMuleNativeRemote && swift test
```

For macOS Release build check:

```bash
cd native-macos/AMuleNativeRemote
xcodebuild -project AMuleNativeRemote.xcodeproj -scheme AMuleNativeRemote -configuration Release -destination "platform=macOS" build
```

For iOS app builds:

```bash
cd native-macos/AMuleNativeRemote
xcodebuild -project AMuleRemoteiOS.xcodeproj -scheme AMuleRemoteiOS -configuration Debug -destination "platform=iOS,id=00008150-001C48DE3C20401C" -derivedDataPath /tmp/amule-iphone-build build
```

For macOS packaging smoke:

```bash
cd native-macos/AMuleNativeRemote
AMULE_EC_BRIDGE_PATH=/usr/bin/true ./scripts/build-app.sh
plutil -lint "dist/aMule Remote.app/Contents/Info.plist"
```
