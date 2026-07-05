# Download List Semantics Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the native SwiftEC download list item lifecycle, status interpretation, source/progress display semantics, and completed-list membership with the original aMule client, without promoting shared/known files or malformed sparse updates into download rows.

**Architecture:** Keep `ECResponseParser.parseDownloads` scoped to `EC_TAG_PARTFILE`, and make `ECDownloadStateStore` treat only part-file lifecycle events as download-list authority. Preserve the existing persistent state merge for source-name deltas, but remove known-file/shared-only fallbacks from download resync, lifecycle, and completion semantics.

**Tech Stack:** Swift 6, SwiftPM XCTest, `native-macos/AMuleNativeRemote/SwiftEC`.

---

## Source References

- Original completed download storage: `src/DownloadQueue.cpp:185`, `src/DownloadQueue.cpp:801`, `src/DownloadQueue.cpp:817`
- Original completion transition: `src/PartFile.cpp:2123`
- Original remote update handling: `src/amule-remote-gui.cpp:1103`, `src/amule-remote-gui.cpp:1559`
- Original progress text and progress bar drawing: `src/DownloadListCtrl.cpp:1014`, `src/DownloadListCtrl.cpp:1048`, `src/DownloadListCtrl.cpp:1295`
- Original part-file status text: `src/PartFile.cpp:3701`
- Daemon EC part-file removal/update packets: `src/ExternalConn.cpp:1936`, `src/ExternalConn.cpp:2163`
- Daemon stopped/hash-progress EC tags: `src/ECSpecialCoreTags.cpp:158`
- Swift state store: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECDownloadStateStore.swift`
- Swift parser: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECResponseParser.swift`
- Swift tests: `native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECClientTests/ECDownloadStateStoreTests.swift`

## Task 1: Lock Original Download-Item Boundaries With Failing Tests

**Files:**
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECClientTests/ECDownloadStateStoreTests.swift`

- [x] **Step 1: Add tests for sparse known files and unknown sparse part files**

Add tests proving that `EC_TAG_KNOWNFILE` never drives download-list resync, and that an unknown sparse `EC_TAG_PARTFILE` without status is not accepted as a completed download fallback.

- [x] **Step 2: Run the focused state tests and observe failure**

Run:

```bash
cd /Users/jason/Repos.localized/amule/native-macos/AMuleNativeRemote/SwiftEC
swift test --filter ECDownloadStateStoreTests
```

Expected before implementation: tests fail because known-file sparse tags can request download resync, unknown sparse part files can avoid resync, and shared-only completed rows have their own lifecycle.

## Task 2: Remove Download-List Fallback Semantics

**Files:**
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECDownloadStateStore.swift`
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECResponseParser.swift`

- [x] **Step 1: Scope state resync to part-file tags**

Change `incrementalUpdateNeedsFullResync(_:)` and identity checks so only `EC_TAG_PARTFILE` can request a download-list resync. Require part-file status for unknown incoming part files to count as complete download state.

- [x] **Step 2: Remove `sharedOnly` download lifecycle**

Delete the `sharedOnly` lifecycle and classify completed rows as `completedRetained` solely from part-file completion state.

- [x] **Step 3: Stop defaulting missing status to complete**

In `ECResponseParser.parseDownloadTag`, use neutral missing-field defaults for sparse tags; the state store should merge sparse tags into existing rows or resync unknown rows, not invent completed rows.

- [x] **Step 4: Run focused tests**

Run:

```bash
cd /Users/jason/Repos.localized/amule/native-macos/AMuleNativeRemote/SwiftEC
swift test --filter ECDownloadStateStoreTests
swift test --filter ECResponseParserTests
```

Expected: state and parser tests pass with the original aMule download-list boundary.

## Task 3: Verify Adapter Behavior

**Files:**
- Test only: `native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECBridgeAdapterTests/AMuleECBridgeAdapterTests.swift`

- [x] **Step 1: Run adapter tests**

Run:

```bash
cd /Users/jason/Repos.localized/amule/native-macos/AMuleNativeRemote/SwiftEC
swift test --filter AMuleECBridgeAdapterTests
```

Expected: adapter still uses full download queue for baseline, incremental update for part-file changes, and clear-completed acknowledgement only for retained completed download rows.

## Task 4: Full SwiftEC Verification

**Files:**
- No additional code files.

- [x] **Step 1: Run the SwiftEC package test suite**

Run:

```bash
cd /Users/jason/Repos.localized/amule/native-macos/AMuleNativeRemote/SwiftEC
swift test
```

Expected: all SwiftEC tests pass.

## Task 5: Align Progress Bar State, Color, and Precision Semantics

**Files:**
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECModels.swift`
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECResponseParser.swift`
- Modify: `native-macos/AMuleNativeRemote/Packages/Shared/Sources/SharedModels/Models.swift`
- Modify: `native-macos/AMuleNativeRemote/Packages/Shared/Sources/SharedViews/DownloadClassification.swift`
- Modify tests in SwiftEC and Shared packages.

- [x] **Step 1: Carry original stopped and hashing progress tags into Swift models**

Add `isStopped`, `hashingProgressParts`, and `displayProgress`/`displayProgressValue` so the UI can represent EC stopped state and the original hashing progress percent separately from byte-progress sorting.

- [x] **Step 2: Match original progress text precision**

Use one-decimal rounding, cap non-complete displayed progress at `99.9%`, and let hashing progress display derive from `hashedPartCount * PARTSIZE / fileSize`.

- [x] **Step 3: Match original progress colors by semantic state**

Use full green for `PS_COMPLETING`/`PS_COMPLETE`, green/yellow split for hashing, red missing ranges, gray completed ranges, yellow requested ranges, blue/green availability intensity, and 50% dimmed missing/requested colors while stopped.

- [x] **Step 4: Match original source-count text**

Show total only when current sources equal total, otherwise `current/total`; append `+A4AF` and transferring count when present.

## Task 6: Align Completed-List Membership With `PS_COMPLETE`

**Files:**
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECResponseParser.swift`
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECDownloadStateStore.swift`
- Modify: `native-macos/AMuleNativeRemote/Packages/Shared/Sources/SharedModels/Models.swift`
- Modify: `native-macos/AMuleNativeRemote/Packages/Shared/Sources/SharedViews/DownloadClassification.swift`

- [x] **Step 1: Remove completed fallbacks**

Do not classify rows as completed from `statusCode >= 8`, status text, or `done >= size`. `PS_COMPLETING` can draw as full green, but it is not a completed download-list item.

- [x] **Step 2: Retain omitted rows only when they are completed part files**

State retention for omitted rows follows `PS_COMPLETE`/`is_completed`, not byte progress or shared-file shape.

## Task 7: Align Sparse Part-File Updates With Original Remote GUI

**Files:**
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECDownloadStateStore.swift`
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECResponseParser.swift`
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECClientTests/ECDownloadStateStoreTests.swift`

- [x] **Step 1: Parse part-file fields independently of status presence**

Read scalar tags such as size done/transferred, speed, source counts, category, timestamps, available parts, stopped, and hash progress whenever present.

- [x] **Step 2: Merge sparse updates tag-by-tag**

For known ECIDs, update only fields whose tags are present, preserving existing state for absent fields and recomputing status text/progress from the merged state.

## Task 8: Final Verification

- [x] `cd native-macos/AMuleNativeRemote/SwiftEC && swift test`
- [x] `cd native-macos/AMuleNativeRemote/Packages/Shared && swift test`
- [x] `cd native-macos/AMuleNativeRemote && swift test`
- [x] `cd native-macos/AMuleNativeRemote && swift build -Xswiftc -warnings-as-errors`
- [x] `cd native-macos/AMuleNativeRemote/SwiftEC && ./Scripts/check-forbidden-deps.sh`
