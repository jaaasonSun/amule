# Filename Prefix Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add configurable, case-insensitive literal filename prefix cleanup to the native Apple filename suggestion flow.

**Architecture:** Implement the transformation once in `AMuleECClient`, expose it through `SharedModels`, and pass UserDefaults-backed prefix rules from macOS and iOS UI. Existing rename actions remain manual and unchanged.

**Tech Stack:** Swift 6.2, SwiftPM, SwiftUI, XCTest, UserDefaults/AppStorage.

---

### Task 1: Core Filename Suggestion Policy

**Files:**
- Create: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/FileNameSuggestionPolicy.swift`
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECClientTests/FileNameEncodingRepairTests.swift`

- [x] **Step 1: Write failing tests**

Add tests for `FileNameSuggestionPolicy.suggestion(currentName:providedSuggestion:prefixes:)` covering:

```swift
XCTAssertEqual(FileNameSuggestionPolicy.suggestion(currentName: "ABCDED - Movie.mkv", prefixes: ["ABCDED - "]), "Movie.mkv")
XCTAssertEqual(FileNameSuggestionPolicy.suggestion(currentName: "abcded - Movie.mkv", prefixes: ["ABCDED - "]), "Movie.mkv")
XCTAssertNil(FileNameSuggestionPolicy.suggestion(currentName: "ABCDED- Movie.mkv", prefixes: ["ABCDED - "]))
XCTAssertEqual(FileNameSuggestionPolicy.suggestion(currentName: "ABCDED - FranÃ§ais.mkv", prefixes: ["ABCDED - "]), "Français.mkv")
XCTAssertEqual(FileNameSuggestionPolicy.suggestion(currentName: "ABCDED Extended - Movie.mkv", prefixes: ["ABCDED ", "ABCDED Extended - "]), "Movie.mkv")
XCTAssertNil(FileNameSuggestionPolicy.suggestion(currentName: "ABCDED - ", prefixes: ["ABCDED - "]))
```

- [x] **Step 2: Run failing tests**

Run:

```bash
cd native-macos/AMuleNativeRemote/SwiftEC && swift test --filter FileNameEncodingRepairTests
```

Expected: FAIL because `FileNameSuggestionPolicy` does not exist.

- [x] **Step 3: Implement policy**

Create a public enum that:

- trims current name and provided suggestion;
- prefers a meaningful provided suggestion, otherwise encoding repair;
- applies longest case-insensitive literal prefix match;
- falls back to prefix cleanup of current name when no encoding repair exists;
- returns nil for empty or unchanged results.

- [x] **Step 4: Run tests**

Run the same SwiftEC filtered test and expect PASS.

### Task 2: Shared Model Helpers

**Files:**
- Modify: `native-macos/AMuleNativeRemote/Packages/Shared/Sources/SharedModels/Models.swift`
- Modify: `native-macos/AMuleNativeRemote/Packages/Shared/Tests/SharedViewsTests/SharedUITests.swift`

- [x] **Step 1: Write failing tests**

Add assertions that `DownloadItem.meaningfulFilenameSuggestion(prefixes:)` and `DownloadAlternativeName.meaningfulFilenameSuggestion(prefixes:)` return prefix-cleaned suggestions and preserve existing encoding repair behavior.

- [x] **Step 2: Implement helpers**

Add public helpers that call `FileNameSuggestionPolicy`.

- [x] **Step 3: Run Shared tests**

Run:

```bash
cd native-macos/AMuleNativeRemote/Packages/Shared && swift test
```

Expected: PASS.

### Task 3: Prefix Storage Helper

**Files:**
- Create: `native-macos/AMuleNativeRemote/Packages/Shared/Sources/SharedModels/FilenameCleanupPreferences.swift`
- Add tests in the Shared package.

- [x] **Step 1: Write failing tests**

Test JSON encoding/decoding, bad JSON fallback to empty, empty prefix filtering, and exact duplicate removal.

- [x] **Step 2: Implement helper**

Expose:

```swift
public enum FilenameCleanupPreferences {
    public static let storageKey = "amule.filenameCleanup.prefixes"
    public static func decode(_ raw: String) -> [String]
    public static func encode(_ prefixes: [String]) -> String
    public static func normalized(_ prefixes: [String]) -> [String]
}
```

- [x] **Step 3: Run Shared tests**

Run:

```bash
cd native-macos/AMuleNativeRemote/Packages/Shared && swift test
```

Expected: PASS.

### Task 4: macOS UI Integration

**Files:**
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/ContentView.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/DownloadsPanel.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/DownloadDetailsWindowView.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Downloads.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/PreferencesWindowView.swift`

- [x] **Step 1: Add `@AppStorage` prefix JSON where suggestions are rendered or requested**

Decode prefixes with `FilenameCleanupPreferences.decode`.

- [x] **Step 2: Replace calls to `meaningfulNameEncodingSuggestion` for rename suggestions**

Use `meaningfulFilenameSuggestion(prefixes:)` for suggested rename actions. Keep diagnostic display behavior unchanged except for using the final suggestion value when available.

- [x] **Step 3: Add macOS Preferences controls**

Add a "Filename Cleanup" section with a text field, Add button, list of configured prefixes, and delete buttons.

- [ ] **Step 4: Run macOS package tests**

Run:

```bash
cd native-macos/AMuleNativeRemote && swift test
```

Expected: PASS.

### Task 5: iOS UI Integration

**Files:**
- Modify: `native-macos/AMuleNativeRemote/iOS/AMuleRemoteiOS/DownloadsView.swift`
- Modify: `native-macos/AMuleNativeRemote/iOS/AMuleRemoteiOS/DownloadDetailView.swift`
- Modify: `native-macos/AMuleNativeRemote/iOS/AMuleRemoteiOS/DownloadRowViews.swift`
- Modify: `native-macos/AMuleNativeRemote/iOS/AMuleRemoteiOS/SettingsView.swift`
- Modify: `native-macos/AMuleNativeRemote/iOS/AMuleRemoteiOS/zh-Hans.lproj/Localizable.strings`
- Modify: `native-macos/AMuleNativeRemote/iOS/AMuleRemoteiOS/zh_CN.lproj/Localizable.strings`

- [x] **Step 1: Decode configured prefixes in iOS views**

Use the same storage key and helper as macOS.

- [x] **Step 2: Update suggestion display and actions**

Use the new shared model helper for rows, detail view, and context menus.

- [x] **Step 3: Add Settings controls**

Add a "Filename Cleanup" section with add/delete prefix controls.

- [ ] **Step 4: Run iOS tests**

Run:

```bash
cd native-macos/AMuleNativeRemote && xcodebuild -project AMuleRemoteiOS.xcodeproj -scheme AMuleRemoteiOS -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0" -derivedDataPath /tmp/amule-ios-sim-test test
```

Expected: PASS if the simulator runtime is installed and available.

### Task 6: Final Verification

- [ ] Run:

```bash
cd native-macos/AMuleNativeRemote/SwiftEC && swift test
cd native-macos/AMuleNativeRemote/Packages/Shared && swift test
cd native-macos/AMuleNativeRemote && swift test
```

- [ ] Report any unavailable simulator or build environment issue explicitly.
