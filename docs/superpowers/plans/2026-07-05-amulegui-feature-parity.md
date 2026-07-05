# aMuleGUI Feature Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the native macOS remote client to practical feature parity with upstream `amulegui`, the original aMule remote GUI.

**Architecture:** Treat upstream `src/amule-gui.cpp`, `src/amule-remote-gui.cpp`, `src/amule-remote-gui.h`, and the reused wxWidgets windows as the behavioral source of truth. Extend SwiftEC first, expose capability-gated bridge methods second, then add focused SwiftUI surfaces in the existing macOS app without changing it into the local full `amule` client.

**Tech Stack:** Swift 6.x, SwiftUI, AppKit, SwiftPM, XCTest, pure SwiftEC, aMule External Connections protocol, upstream C++ EC constants from `src/libs/ec/cpp/ECCodes.h`.

---

## Scope

This plan targets parity with the original **remote** client:

- In scope: features implemented by `CLIENT_GUI` / `amulegui`, remote models such as `CDownQueueRem`, `CSharedFilesRem`, `CSearchListRem`, `CFriendListRem`, `CServerListRem`, `CPreferencesRem`, and UI behavior available through EC.
- Out of scope: embedding or launching the full local aMule core, local listen sockets, local hashing lifecycle, local tray icon behavior, and `CPartFileConvertDlg`, which is explicitly excluded from `CLIENT_GUI`.
- Keep iOS separate. This plan is for `native-macos/AMuleNativeRemote` macOS first; shared packages can be extended only when the same model is already consumed by macOS and iOS.

## Upstream References

- `src/amule-gui.cpp`: remote GUI title, base window startup, and `CLIENT_GUI` divergence.
- `src/amule-remote-gui.h`: remote-side app model and remote containers.
- `src/amule-remote-gui.cpp`: concrete remote commands sent by original `amulegui`.
- `src/amuleDlg.cpp`: top-level windows reused by `amulegui`.
- `src/DownloadListCtrl.cpp`, `src/TransferWnd.cpp`: transfer context menus and category behavior.
- `src/SearchDlg.cpp`: advanced search, filters, and search tabs.
- `src/SharedFilesCtrl.cpp`, `src/SharedFilesWnd.cpp`: shared file commands and peer list behavior.
- `src/FriendListCtrl.cpp`, `src/ChatWnd.cpp`: friends and messages behavior.
- `src/ServerWnd.cpp`, `src/KadDlg.cpp`: eD2k server and Kad remote operations.
- `src/libs/ec/cpp/ECCodes.h`: opcode and tag constants.

## File Structure

- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECModels.swift`
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECOperations.swift`
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECResponseParser.swift`
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECProtocol/ECSupportedOps.swift`
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECBridgeAdapter/SwiftECBridgeAdapter.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Bridge.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Downloads.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Search.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Servers.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Preferences.swift`
- Create: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+SharedFiles.swift`
- Create: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+FriendsMessages.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/DownloadsPanel.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/DownloadDetailsWindowView.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/SearchWindowView.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/ServersWindowView.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/SharedFilesWindowView.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/FriendsWindowView.swift`
- Create: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/MessagesWindowView.swift`
- Create: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/ServerLogsWindowView.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/StatsWindowView.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/PreferencesWindowView.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AMuleNativeRemoteApp.swift`
- Modify: `native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/FakeBridgeAdapter.swift`
- Add tests under: `native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/`
- Add tests under: `native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECClientTests/`
- Add tests under: `native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECBridgeAdapterTests/`
- Create: `docs/superpowers/evidence/2026-07-05-amulegui-feature-parity-matrix.md`

## Delivery Waves

- P0: Create the parity matrix and protect the target operation surface with tests.
- P1: Add missing SwiftEC/bridge operations used by the original remote GUI.
- P2: Align transfers, search, shared files, servers, Kad, logs, and statistics.
- P3: Add friends and messages.
- P4: Expand remote preferences.
- P5: Final parity pass against upstream `amulegui`.

### Task 1: Parity Matrix And Operation Coverage Baseline

**Files:**
- Create: `docs/superpowers/evidence/2026-07-05-amulegui-feature-parity-matrix.md`
- Create: `native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECClientTests/AMuleGuiParityOperationCoverageTests.swift`

- [ ] **Step 1: Create the parity matrix document**

Write `docs/superpowers/evidence/2026-07-05-amulegui-feature-parity-matrix.md` with this structure:

```markdown
# aMuleGUI Feature Parity Matrix

Baseline: upstream `amulegui` / `CLIENT_GUI`.

| Area | Upstream source | Upstream capability | SwiftEC op | macOS UI surface | Status |
| --- | --- | --- | --- | --- | --- |
| Downloads | `src/DownloadListCtrl.cpp` | Pause/resume/cancel/stop | pause/resume/cancel/download-stop | Downloads context menu | stop missing |
| Downloads | `src/DownloadListCtrl.cpp` | A4AF swap to this/auto/others | download-a4af-this/download-a4af-auto/download-a4af-others | Details sources menu | missing |
| Downloads | `src/DownloadListCtrl.cpp` | Assign category | download-set-category | Downloads context menu | missing |
| Search | `src/SearchDlg.cpp` | Extended fields and filters | search with options | Search window | missing |
| Shared Files | `src/SharedFilesCtrl.cpp` | Upload priority/comment/rating/link variants | shared-file-priority/shared-file-comment-rating | Shared Files window | missing mutations |
| Servers | `src/amule-remote-gui.cpp` | Static server and priority | server-set-static/server-set-priority | eD2k window | missing mutations |
| Logs | `src/amule-remote-gui.cpp` | core/server log read and reset | log/debug-log/server-info/reset-log/clear-server-info | Diagnostics/Server Logs | partial |
| Friends | `src/FriendListCtrl.cpp` | add/remove/message/details/friend slot/shared list | friends/friend-add/friend-remove/friend-slot/friend-message | Friends/Messages windows | partial |
| Preferences | `src/amule-remote-gui.h` | remote preference load/apply | prefs-* | Preferences window | partial |
```

- [ ] **Step 2: Add a failing SwiftEC coverage test**

Create `native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECClientTests/AMuleGuiParityOperationCoverageTests.swift`:

```swift
import XCTest
@testable import AMuleECClient

final class AMuleGuiParityOperationCoverageTests: XCTestCase {
    func testP1AmuleGuiOperationsAreAdvertised() {
        let required = Set([
            "download-stop",
            "download-a4af-this",
            "download-a4af-auto",
            "download-a4af-others",
            "download-set-category",
            "category-update",
            "shared-file-priority",
            "shared-file-comment-rating",
            "server-set-static",
            "server-set-priority",
            "server-info",
            "clear-server-info",
            "reset-log"
        ])

        XCTAssertTrue(required.isSubset(of: Set(ECSupportedOps.allOperations)))
    }
}
```

- [ ] **Step 3: Run the coverage test and confirm it fails**

Run:

```bash
cd native-macos/AMuleNativeRemote/SwiftEC
swift test --filter AMuleGuiParityOperationCoverageTests
```

Expected: `XCTAssertTrue` fails because the new operation names are not advertised yet.

- [ ] **Step 4: Commit the baseline**

Run:

```bash
git add docs/superpowers/evidence/2026-07-05-amulegui-feature-parity-matrix.md native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECClientTests/AMuleGuiParityOperationCoverageTests.swift
git commit -m "test: capture amulegui parity operation baseline"
```

### Task 2: SwiftEC Builders For P1 Remote GUI Mutations

**Files:**
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECModels.swift`
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECOperations.swift`
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECProtocol/ECSupportedOps.swift`
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECClientTests/ECOperationsTests.swift`
- Test: `native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECClientTests/AMuleGuiParityOperationCoverageTests.swift`

- [ ] **Step 1: Add failing packet-builder tests**

Append tests to `ECOperationsTests.swift`:

```swift
func testAmuleGuiParityTransferMutationBuildersUseUpstreamOpcodes() throws {
    let hash = "00112233445566778899aabbccddeeff"

    XCTAssertEqual(try ECOperations.stop(hash: hash).opcode, 0x1B)
    XCTAssertEqual(try ECOperations.swapA4AF(hash: hash, mode: .toThis).opcode, 0x16)
    XCTAssertEqual(try ECOperations.swapA4AF(hash: hash, mode: .toThisAuto).opcode, 0x17)
    XCTAssertEqual(try ECOperations.swapA4AF(hash: hash, mode: .toAnyOther).opcode, 0x18)

    let setCategory = try ECOperations.downloadSetCategory(hash: hash, categoryID: 7)
    XCTAssertEqual(setCategory.opcode, 0x1E)
    XCTAssertEqual(setCategory.tags.first?.name, 0x0300)
    XCTAssertEqual(setCategory.tags.first?.children.first?.name, 0x030F)
}

func testAmuleGuiParitySharedServerAndLogBuildersUseUpstreamOpcodes() throws {
    let hash = "00112233445566778899aabbccddeeff"

    XCTAssertEqual(try ECOperations.sharedFilePriority(hash: hash, priority: 10).opcode, 0x11)
    XCTAssertEqual(try ECOperations.sharedFileCommentRating(hash: hash, comment: "clean", rating: 4).opcode, 0x55)
    XCTAssertEqual(try ECOperations.serverSetStatic(ecid: 42, isStatic: true).opcode, 0x56)
    XCTAssertEqual(try ECOperations.serverSetPriority(ecid: 42, priority: 2).opcode, 0x56)
    XCTAssertEqual(try ECOperations.serverInfo().opcode, 0x37)
    XCTAssertEqual(try ECOperations.clearServerInfo().opcode, 0x3D)
    XCTAssertEqual(try ECOperations.resetLog().opcode, 0x3B)
}
```

- [ ] **Step 2: Run the tests and confirm they fail to compile**

Run:

```bash
cd native-macos/AMuleNativeRemote/SwiftEC
swift test --filter ECOperationsTests/testAmuleGuiParity
```

Expected: compile errors for missing `stop`, `swapA4AF`, `downloadSetCategory`, `sharedFilePriority`, `sharedFileCommentRating`, `serverSetStatic`, `serverSetPriority`, `serverInfo`, `clearServerInfo`, and `resetLog`.

- [ ] **Step 3: Add operation names**

Modify `ECOperationName` in `ECModels.swift`:

```swift
case downloadStop = "download-stop"
case downloadA4AFThis = "download-a4af-this"
case downloadA4AFAuto = "download-a4af-auto"
case downloadA4AFOthers = "download-a4af-others"
case sharedFilePriority = "shared-file-priority"
case sharedFileCommentRating = "shared-file-comment-rating"
case serverSetStatic = "server-set-static"
case serverSetPriority = "server-set-priority"
case serverInfo = "server-info"
case clearServerInfo = "clear-server-info"
case resetLog = "reset-log"
```

- [ ] **Step 4: Advertise P1 operations**

Modify `ECSupportedOps.swift` by adding constants and appending them to `allOperations` after related existing operations:

```swift
public static let downloadStop = "download-stop"
public static let downloadA4AFThis = "download-a4af-this"
public static let downloadA4AFAuto = "download-a4af-auto"
public static let downloadA4AFOthers = "download-a4af-others"
public static let sharedFilePriority = "shared-file-priority"
public static let sharedFileCommentRating = "shared-file-comment-rating"
public static let serverSetStatic = "server-set-static"
public static let serverSetPriority = "server-set-priority"
public static let serverInfo = "server-info"
public static let clearServerInfo = "clear-server-info"
public static let resetLog = "reset-log"
```

Remove `"category-update"` and `"download-set-category"` from `unsupportedDisabledOperations` after their builders are implemented in this task.

- [ ] **Step 5: Add opcode and tag constants**

Modify `ECOperations.OpCode` and `ECOperations.TagName`:

```swift
public static let sharedSetPriority: UInt8 = 0x11
public static let partFileSwapA4AFThis: UInt8 = 0x16
public static let partFileSwapA4AFThisAuto: UInt8 = 0x17
public static let partFileSwapA4AFOthers: UInt8 = 0x18
public static let partFileStop: UInt8 = 0x1B
public static let getServerInfo: UInt8 = 0x37
public static let resetLog: UInt8 = 0x3B
public static let clearServerInfo: UInt8 = 0x3D
public static let sharedFileSetComment: UInt8 = 0x55
public static let serverSetStaticPriority: UInt8 = 0x56
```

```swift
public static let serverPriority: UInt16 = 0x0508
public static let serverStatic: UInt16 = 0x050A
```

- [ ] **Step 6: Add transfer builders**

Add this enum and methods to `ECOperations`:

```swift
public enum A4AFSwapMode: Sendable, Equatable {
    case toThis
    case toThisAuto
    case toAnyOther
}

public static func stop(hash: String, gate: ECCapabilityGate? = nil) throws -> ECPacket {
    try partFileAction(opcode: OpCode.partFileStop, operation: .downloadStop, hash: hash, gate: gate)
}

public static func swapA4AF(hash: String, mode: A4AFSwapMode, gate: ECCapabilityGate? = nil) throws -> ECPacket {
    let operation: ECOperationName
    let opcode: UInt8
    switch mode {
    case .toThis:
        operation = .downloadA4AFThis
        opcode = OpCode.partFileSwapA4AFThis
    case .toThisAuto:
        operation = .downloadA4AFAuto
        opcode = OpCode.partFileSwapA4AFThisAuto
    case .toAnyOther:
        operation = .downloadA4AFOthers
        opcode = OpCode.partFileSwapA4AFOthers
    }
    return try partFileAction(opcode: opcode, operation: operation, hash: hash, gate: gate)
}

public static func downloadSetCategory(hash: String, categoryID: Int, gate: ECCapabilityGate? = nil) throws -> ECPacket {
    try gate?.require(.downloadSetCategory)
    return ECPacket(opcode: OpCode.partFileSetCat, tags: [
        ECTag(name: TagName.partFile, type: .hash16, value: .hash16(try hashData(hash)), children: [
            ECTag.integer(name: TagName.partFileCategory, value: UInt64(max(0, categoryID)))
        ])
    ])
}
```

- [ ] **Step 7: Add category, shared-file, server, and log builders**

Add methods to `ECOperations`:

```swift
public static func categoryUpdate(id: Int, name: String, path: String, comment: String, color: Int, priority: Int, gate: ECCapabilityGate? = nil) throws -> ECPacket {
    try gate?.require(.categoryUpdate)
    return ECPacket(opcode: OpCode.updateCategory, tags: [
        categoryTag(id: id, name: name, path: path, comment: comment, color: color, priority: priority)
    ])
}

public static func sharedFilePriority(hash: String, priority: Int, gate: ECCapabilityGate? = nil) throws -> ECPacket {
    try gate?.require(.sharedFilePriority)
    return ECPacket(opcode: OpCode.sharedSetPriority, tags: [
        ECTag(name: TagName.partFile, type: .hash16, value: .hash16(try hashData(hash)), children: [
            ECTag.integer(name: TagName.partFilePriority, value: UInt64(max(0, priority)))
        ])
    ])
}

public static func sharedFileCommentRating(hash: String, comment: String, rating: Int, gate: ECCapabilityGate? = nil) throws -> ECPacket {
    try gate?.require(.sharedFileCommentRating)
    return ECPacket(opcode: OpCode.sharedFileSetComment, tags: [
        ECTag(name: TagName.knownFile, type: .hash16, value: .hash16(try hashData(hash))),
        ECTag(name: TagName.knownFileComment, type: .string, value: .string(comment)),
        ECTag.integer(name: TagName.knownFileRating, value: UInt64(max(0, rating)))
    ])
}

public static func serverSetStatic(ecid: Int, isStatic: Bool, gate: ECCapabilityGate? = nil) throws -> ECPacket {
    try gate?.require(.serverSetStatic)
    return ECPacket(opcode: OpCode.serverSetStaticPriority, tags: [
        ECTag.integer(name: TagName.server, value: UInt64(max(0, ecid))),
        ECTag.integer(name: TagName.serverStatic, value: isStatic ? 1 : 0)
    ])
}

public static func serverSetPriority(ecid: Int, priority: Int, gate: ECCapabilityGate? = nil) throws -> ECPacket {
    try gate?.require(.serverSetPriority)
    return ECPacket(opcode: OpCode.serverSetStaticPriority, tags: [
        ECTag.integer(name: TagName.server, value: UInt64(max(0, ecid))),
        ECTag.integer(name: TagName.serverPriority, value: UInt64(max(0, priority)))
    ])
}

public static func serverInfo(gate: ECCapabilityGate? = nil) throws -> ECPacket {
    try gate?.require(.serverInfo)
    return ECPacket(opcode: OpCode.getServerInfo)
}

public static func clearServerInfo(gate: ECCapabilityGate? = nil) throws -> ECPacket {
    try gate?.require(.clearServerInfo)
    return ECPacket(opcode: OpCode.clearServerInfo)
}

public static func resetLog(gate: ECCapabilityGate? = nil) throws -> ECPacket {
    try gate?.require(.resetLog)
    return ECPacket(opcode: OpCode.resetLog)
}
```

- [ ] **Step 8: Run SwiftEC tests**

Run:

```bash
cd native-macos/AMuleNativeRemote/SwiftEC
swift test --filter AMuleGuiParityOperationCoverageTests
swift test --filter ECOperationsTests/testAmuleGuiParity
./Scripts/check-forbidden-deps.sh
```

Expected: all commands pass.

- [ ] **Step 9: Commit**

Run:

```bash
git add native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECModels.swift native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECOperations.swift native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECProtocol/ECSupportedOps.swift native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECClientTests/ECOperationsTests.swift native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECClientTests/AMuleGuiParityOperationCoverageTests.swift
git commit -m "feat: add amulegui parity EC builders"
```

### Task 3: Bridge Adapter Contract For P1 Operations

**Files:**
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECBridgeAdapter/SwiftECBridgeAdapter.swift`
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Tests/Fixtures/ECJsonEnvelopeFixtures.swift`
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECBridgeAdapterTests/AMuleECBridgeAdapterTests.swift`
- Modify: `native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/FakeBridgeAdapter.swift`

- [ ] **Step 1: Add failing bridge adapter tests**

In `AMuleECBridgeAdapterTests.swift`, extend the mutation scenario table with:

```swift
("download-stop", [Self.salt, Self.authOK, ECPacket(opcode: 0x01)], { try await $0.stop(hash: hash, config: config) }, 0x1B),
("download-a4af-this", [Self.salt, Self.authOK, ECPacket(opcode: 0x01)], { try await $0.swapA4AF(hash: hash, mode: .toThis, config: config) }, 0x16),
("download-a4af-auto", [Self.salt, Self.authOK, ECPacket(opcode: 0x01)], { try await $0.swapA4AF(hash: hash, mode: .toThisAuto, config: config) }, 0x17),
("download-a4af-others", [Self.salt, Self.authOK, ECPacket(opcode: 0x01)], { try await $0.swapA4AF(hash: hash, mode: .toAnyOther, config: config) }, 0x18),
("download-set-category", [Self.salt, Self.authOK, ECPacket(opcode: 0x01)], { try await $0.downloadSetCategory(hash: hash, categoryID: 7, config: config) }, 0x1E),
("category-update", [Self.salt, Self.authOK, ECPacket(opcode: 0x01)], { try await $0.categoryUpdate(id: 7, name: "Video", path: "/downloads/video", comment: "media", color: 0x00aaff, priority: 2, config: config) }, 0x42),
("shared-file-priority", [Self.salt, Self.authOK, ECPacket(opcode: 0x01)], { try await $0.sharedFilePriority(hash: hash, priority: 10, config: config) }, 0x11),
("shared-file-comment-rating", [Self.salt, Self.authOK, ECPacket(opcode: 0x01)], { try await $0.sharedFileCommentRating(hash: hash, comment: "verified", rating: 4, config: config) }, 0x55),
("server-set-static", [Self.salt, Self.authOK, ECPacket(opcode: 0x01)], { try await $0.serverSetStatic(ecid: 42, isStatic: true, config: config) }, 0x56),
("server-set-priority", [Self.salt, Self.authOK, ECPacket(opcode: 0x01)], { try await $0.serverSetPriority(ecid: 42, priority: 2, config: config) }, 0x56),
("clear-server-info", [Self.salt, Self.authOK, ECPacket(opcode: 0x01)], { try await $0.clearServerInfo(config: config) }, 0x3D),
("reset-log", [Self.salt, Self.authOK, ECPacket(opcode: 0x01)], { try await $0.resetLog(config: config) }, 0x3B)
```

- [ ] **Step 2: Run and confirm compile failure**

Run:

```bash
cd native-macos/AMuleNativeRemote/SwiftEC
swift test --filter AMuleECBridgeAdapterTests
```

Expected: compile errors for missing bridge methods.

- [ ] **Step 3: Extend `BridgeProtocol`**

Add methods to the public `BridgeProtocol` in `SwiftECBridgeAdapter.swift`:

```swift
func stop(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
func swapA4AF(hash: String, mode: ECOperations.A4AFSwapMode, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
func downloadSetCategory(hash: String, categoryID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
func categoryUpdate(id: Int, name: String, path: String, comment: String, color: Int, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
func sharedFilePriority(hash: String, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
func sharedFileCommentRating(hash: String, comment: String, rating: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
func serverSetStatic(ecid: Int, isStatic: Bool, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
func serverSetPriority(ecid: Int, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
func serverInfo(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String)
func clearServerInfo(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
func resetLog(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
```

- [ ] **Step 4: Implement adapter methods**

Add methods to `SwiftECBridgeAdapter` using `mutation(...)` and `withAuthenticatedSession(...)`:

```swift
public func stop(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
    try await mutation(try ECOperations.stop(hash: hash, gate: capabilityGate), message: "Stop requested", config: config)
}

public func swapA4AF(hash: String, mode: ECOperations.A4AFSwapMode, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
    try await mutation(try ECOperations.swapA4AF(hash: hash, mode: mode, gate: capabilityGate), message: "A4AF swap requested", config: config)
}

public func downloadSetCategory(hash: String, categoryID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
    try await mutation(try ECOperations.downloadSetCategory(hash: hash, categoryID: categoryID, gate: capabilityGate), message: "Download category updated", config: config)
}

public func categoryUpdate(id: Int, name: String, path: String, comment: String, color: Int, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
    try await mutation(try ECOperations.categoryUpdate(id: id, name: name, path: path, comment: comment, color: color, priority: priority, gate: capabilityGate), message: "Category update requested", config: config)
}

public func sharedFilePriority(hash: String, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
    try await mutation(try ECOperations.sharedFilePriority(hash: hash, priority: priority, gate: capabilityGate), message: "Shared file priority updated", config: config)
}

public func sharedFileCommentRating(hash: String, comment: String, rating: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
    try await mutation(try ECOperations.sharedFileCommentRating(hash: hash, comment: comment, rating: rating, gate: capabilityGate), message: "Shared file comment updated", config: config)
}

public func serverSetStatic(ecid: Int, isStatic: Bool, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
    try await mutation(try ECOperations.serverSetStatic(ecid: ecid, isStatic: isStatic, gate: capabilityGate), message: "Server static flag updated", config: config)
}

public func serverSetPriority(ecid: Int, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
    try await mutation(try ECOperations.serverSetPriority(ecid: ecid, priority: priority, gate: capabilityGate), message: "Server priority updated", config: config)
}

public func clearServerInfo(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
    try await mutation(try ECOperations.clearServerInfo(gate: capabilityGate), message: "Server log cleared", config: config)
}

public func resetLog(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
    try await mutation(try ECOperations.resetLog(gate: capabilityGate), message: "Core log cleared", config: config)
}
```

- [ ] **Step 5: Implement `serverInfo` parser path**

Add a parser method in `ECResponseParser` if one does not exist:

```swift
public static func parseServerInfo(_ packet: ECPacket) throws -> ECCoreLog {
    try requireOpcode(packet, ECOperations.OpCode.serverInfo)
    let text = packet.tags.first { $0.name == ECOperations.TagName.string }?.stringValue ?? ""
    return ECCoreLog(kind: "server-info", lines: text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init))
}
```

Add `public static let serverInfo: UInt8 = 0x3A` to `ECOperations.OpCode`; upstream `EC_OP_SERVERINFO` is the response opcode for `EC_OP_GET_SERVERINFO`.

- [ ] **Step 6: Update fake bridge**

Add default implementations to `FakeBridgeAdapter.swift`, all returning `("ok", messageRaw)` except `serverInfo`, which returns `(BridgeCoreLogPayload(kind: "server-info", lines: ["server log"]), messageRaw)`.

- [ ] **Step 7: Run tests**

Run:

```bash
cd native-macos/AMuleNativeRemote/SwiftEC
swift test --filter AMuleECBridgeAdapterTests
cd ../
swift test --filter AMuleNativeRemoteTests
```

Expected: both commands pass.

- [ ] **Step 8: Commit**

Run:

```bash
git add native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECBridgeAdapter/SwiftECBridgeAdapter.swift native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECResponseParser.swift native-macos/AMuleNativeRemote/SwiftEC/Tests/Fixtures/ECJsonEnvelopeFixtures.swift native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECBridgeAdapterTests/AMuleECBridgeAdapterTests.swift native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/FakeBridgeAdapter.swift
git commit -m "feat: expose amulegui parity bridge actions"
```

### Task 4: Downloads Window Parity, Stop, A4AF, And Categories

**Files:**
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Downloads.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/DownloadsPanel.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/DownloadDetailsWindowView.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/CategoriesWindowView.swift`
- Create: `native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/DownloadParityActionTests.swift`

- [ ] **Step 1: Add failing AppModel action tests**

Create `DownloadParityActionTests.swift`:

```swift
import XCTest
@testable import AMuleNativeRemote
import SharedModels

@MainActor
final class DownloadParityActionTests: XCTestCase {
    func testStopDownloadRefreshesDownloadsAndStatus() async throws {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["download-stop", "downloads", "status"])
        let model = AppModel(bridge: bridge)
        let item = DownloadItem.fixture(hash: "00112233445566778899aabbccddeeff")

        model.stopDownload(item)
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(bridge.invokedOperations.contains("download-stop"))
    }

    func testAssignDownloadCategoryUsesSelectedCategoryID() async throws {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["download-set-category", "downloads", "status"])
        let model = AppModel(bridge: bridge)
        let item = DownloadItem.fixture(hash: "00112233445566778899aabbccddeeff")

        model.setDownloadCategory(item, categoryID: 7)
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(bridge.lastDownloadCategoryID, 7)
    }
}
```

Add small recording properties to `FakeBridgeAdapter` when this test is implemented:

```swift
var invokedOperations: [String] = []
var lastDownloadCategoryID: Int?
```

- [ ] **Step 2: Add AppModel methods**

Add to `AppModel+Downloads.swift`:

```swift
func stopDownload(_ item: DownloadItem) {
    run(label: "download-stop") {
        let (_, raw) = try await self.bridge.stop(hash: item.id, config: self.config)
        await MainActor.run {
            self.appendLog("$ download-stop \(item.id)\n\(raw)")
        }
        try await self.refreshDownloadsNow(logOutput: false)
        await self.refreshStatus(logOutput: false)
    }
}

func swapA4AF(_ item: DownloadItem, mode: ECOperations.A4AFSwapMode) {
    run(label: "download-a4af") {
        let (_, raw) = try await self.bridge.swapA4AF(hash: item.id, mode: mode, config: self.config)
        await MainActor.run {
            self.appendLog("$ download-a4af \(item.id)\n\(raw)")
        }
        try await self.refreshDownloadsNow(logOutput: false)
    }
}

func setDownloadCategory(_ item: DownloadItem, categoryID: Int) {
    run(label: "download-set-category") {
        let (_, raw) = try await self.bridge.downloadSetCategory(hash: item.id, categoryID: categoryID, config: self.config)
        await MainActor.run {
            self.appendLog("$ download-set-category \(item.id) \(categoryID)\n\(raw)")
        }
        try await self.refreshDownloadsNow(logOutput: false)
    }
}
```

- [ ] **Step 3: Add UI actions**

In `DownloadsPanel.swift`, extend the selected-download context menu:

```swift
Button("Stop") { model.stopDownload(item) }
    .disabled(model.isBusy || !model.isBridgeOpSupported("download-stop") || item.isCompletedLike)

Menu("Assign to Category") {
    Button("Unassign") { model.setDownloadCategory(item, categoryID: 0) }
    ForEach(model.categories, id: \.id) { category in
        Button(category.title) { model.setDownloadCategory(item, categoryID: category.id) }
    }
}
.disabled(model.isBusy || !model.isBridgeOpSupported("download-set-category"))
```

In `DownloadDetailsWindowView.swift`, add A4AF actions near the sources list:

```swift
Menu("A4AF") {
    Button("Swap to this file") { model.swapA4AF(item, mode: .toThis) }
    Button("Swap to this file automatically") { model.swapA4AF(item, mode: .toThisAuto) }
    Button("Swap to another file") { model.swapA4AF(item, mode: .toAnyOther) }
}
.disabled(model.isBusy || item.sourceA4AF == 0)
```

- [ ] **Step 4: Run focused tests**

Run:

```bash
cd native-macos/AMuleNativeRemote
swift test --filter DownloadParityActionTests
swift test --filter AMuleNativeRemoteTests
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
git add native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Downloads.swift native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/DownloadsPanel.swift native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/DownloadDetailsWindowView.swift native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/DownloadParityActionTests.swift native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/FakeBridgeAdapter.swift
git commit -m "feat: align download actions with amulegui"
```

### Task 5: Search Window Advanced Options And Filters

**Files:**
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECOperations.swift`
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECClientTests/ECOperationsTests.swift`
- Create: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/SearchOptions.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Search.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/SearchWindowView.swift`
- Create: `native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/SearchParityTests.swift`

- [ ] **Step 1: Add failing EC search option builder test**

Add to `ECOperationsTests.swift`:

```swift
func testSearchBuilderIncludesAmuleGuiExtendedCriteria() throws {
    let request = ECSearchRequest(
        scope: "global",
        query: "ubuntu",
        fileType: "Video",
        extension: "mkv",
        minSize: 1_000,
        maxSize: 2_000,
        availability: 3
    )

    let packet = try ECOperations.search(request: request)
    let root = try XCTUnwrap(packet.tags.first)

    XCTAssertEqual(root.child(named: 0x0702)?.stringValue, "ubuntu")
    XCTAssertEqual(root.child(named: 0x0705)?.stringValue, "Video")
    XCTAssertEqual(root.child(named: 0x0706)?.stringValue, "mkv")
    XCTAssertEqual(root.child(named: 0x0703)?.intValue, 1_000)
    XCTAssertEqual(root.child(named: 0x0704)?.intValue, 2_000)
    XCTAssertEqual(root.child(named: 0x0707)?.intValue, 3)
}
```

- [ ] **Step 2: Add EC search request model**

Add to `ECModels.swift`:

```swift
public struct ECSearchRequest: Equatable, Sendable {
    public let scope: String
    public let query: String
    public let fileType: String
    public let `extension`: String
    public let minSize: UInt64
    public let maxSize: UInt64
    public let availability: UInt64

    public init(scope: String, query: String, fileType: String = "", extension: String = "", minSize: UInt64 = 0, maxSize: UInt64 = 0, availability: UInt64 = 0) {
        self.scope = scope
        self.query = query
        self.fileType = fileType
        self.extension = `extension`
        self.minSize = minSize
        self.maxSize = maxSize
        self.availability = availability
    }
}
```

- [ ] **Step 3: Extend search builder**

Add to `ECOperations.TagName`:

```swift
public static let searchMinSize: UInt16 = 0x0703
public static let searchMaxSize: UInt16 = 0x0704
public static let searchExtension: UInt16 = 0x0706
public static let searchAvailability: UInt16 = 0x0707
```

Add overload:

```swift
public static func search(request: ECSearchRequest, gate: ECCapabilityGate? = nil) throws -> ECPacket {
    try gate?.require(.search)
    var children: [ECTag] = [
        ECTag(name: TagName.searchName, type: .string, value: .string(request.query)),
        ECTag(name: TagName.searchFileType, type: .string, value: .string(request.fileType))
    ]
    if !request.extension.isEmpty {
        children.append(ECTag(name: TagName.searchExtension, type: .string, value: .string(request.extension)))
    }
    if request.availability > 0 {
        children.append(ECTag.integer(name: TagName.searchAvailability, value: request.availability))
    }
    if request.minSize > 0 {
        children.append(ECTag.integer(name: TagName.searchMinSize, value: request.minSize))
    }
    if request.maxSize > 0 {
        children.append(ECTag.integer(name: TagName.searchMaxSize, value: request.maxSize))
    }
    return ECPacket(opcode: OpCode.searchStart, tags: [
        ECTag.integer(name: TagName.searchType, value: SearchScope(request.scope).rawValue, children: children)
    ])
}
```

Update the existing `search(scope:query:)` method to call the overload with default options.

- [ ] **Step 4: Add macOS search options model**

Create `SearchOptions.swift`:

```swift
import Foundation
import AMuleECClient

struct SearchOptions: Equatable {
    var fileType = ""
    var fileExtension = ""
    var minSizeText = ""
    var maxSizeText = ""
    var availabilityText = ""
    var filterText = ""
    var invertFilter = false
    var hideKnownResults = false
    var categoryID = 0

    func ecRequest(scope: String, query: String) throws -> ECSearchRequest {
        ECSearchRequest(
            scope: scope,
            query: query,
            fileType: fileType,
            extension: fileExtension,
            minSize: try Self.parseUInt64(minSizeText),
            maxSize: try Self.parseUInt64(maxSizeText),
            availability: try Self.parseUInt64(availabilityText)
        )
    }

    private static func parseUInt64(_ text: String) throws -> UInt64 {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        guard let value = UInt64(trimmed) else { throw SearchOptionsError.invalidNumber(trimmed) }
        return value
    }
}

enum SearchOptionsError: Error, Equatable {
    case invalidNumber(String)
}
```

- [ ] **Step 5: Use options in AppModel search**

Add `@Published var searchOptions = SearchOptions()` to `AppModel`.

In `performSearch()`, build the request:

```swift
let request = try self.searchOptions.ecRequest(scope: scope, query: query)
let (progress, payload, raw) = try await self.bridge.search(request: request, polls: 12, pollIntervalMs: 900, config: currentConfig)
```

Extend `BridgeProtocol` with `search(request:polls:pollIntervalMs:config:)`; keep the existing `search(scope:query:polls:pollIntervalMs:config:)` as a compatibility wrapper.

- [ ] **Step 6: Add UI controls and local filters**

In `SearchWindowView.swift`, add a compact advanced section above the outline:

```swift
DisclosureGroup("Advanced Search") {
    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 8) {
        GridRow {
            Text("Type")
            TextField("Any", text: $model.searchOptions.fileType)
            Text("Extension")
            TextField("mkv", text: $model.searchOptions.fileExtension)
        }
        GridRow {
            Text("Min Size")
            TextField("0", text: $model.searchOptions.minSizeText)
            Text("Max Size")
            TextField("0", text: $model.searchOptions.maxSizeText)
            Text("Availability")
            TextField("0", text: $model.searchOptions.availabilityText)
        }
        GridRow {
            Text("Filter")
            TextField("regex or text", text: $model.searchOptions.filterText)
            Toggle("Invert", isOn: $model.searchOptions.invertFilter)
            Toggle("Hide Known", isOn: $model.searchOptions.hideKnownResults)
        }
    }
}
.padding(12)
```

Filter `displayedSearchResults` using `filterText`, `invertFilter`, and `hideKnownResults`, matching upstream search filter semantics at a practical level.

- [ ] **Step 7: Run tests**

Run:

```bash
cd native-macos/AMuleNativeRemote/SwiftEC
swift test --filter ECOperationsTests/testSearchBuilderIncludesAmuleGuiExtendedCriteria
cd ../
swift test --filter SearchParityTests
swift test --filter AMuleNativeRemoteTests
```

Expected: all tests pass.

- [ ] **Step 8: Commit**

Run:

```bash
git add native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECModels.swift native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECOperations.swift native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECClientTests/ECOperationsTests.swift native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/SearchOptions.swift native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel.swift native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Search.swift native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/SearchWindowView.swift native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/SearchParityTests.swift
git commit -m "feat: add amulegui search options"
```

### Task 6: Shared Files Window Parity

**Files:**
- Create: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+SharedFiles.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/SharedFilesWindowView.swift`
- Create: `native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/SharedFilesParityTests.swift`

- [ ] **Step 1: Add AppModel shared-file tests**

Create `SharedFilesParityTests.swift`:

```swift
import XCTest
@testable import AMuleNativeRemote

@MainActor
final class SharedFilesParityTests: XCTestCase {
    func testSharedFilePriorityInvokesBridge() async throws {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["shared-file-priority", "shared-files"])
        let model = AppModel(bridge: bridge)

        model.setSharedFilePriority(hash: "00112233445566778899aabbccddeeff", priority: 10)
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(bridge.invokedOperations.contains("shared-file-priority"))
    }

    func testSharedFileCommentRatingInvokesBridge() async throws {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["shared-file-comment-rating", "shared-files"])
        let model = AppModel(bridge: bridge)

        model.setSharedFileCommentRating(hash: "00112233445566778899aabbccddeeff", comment: "verified", rating: 4)
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(bridge.lastSharedFileRating, 4)
    }
}
```

- [ ] **Step 2: Add AppModel shared-file methods**

Create `AppModel+SharedFiles.swift`:

```swift
import Foundation

extension AppModel {
    func setSharedFilePriority(hash: String, priority: Int) {
        guard isBridgeOpSupported("shared-file-priority") else { return }
        run(label: "shared-file-priority") {
            let (_, raw) = try await self.bridge.sharedFilePriority(hash: hash, priority: priority, config: self.config)
            await MainActor.run { self.appendLog("$ shared-file-priority \(hash) \(priority)\n\(raw)") }
            try await self.refreshSharedFilesNow(logOutput: false, suppressErrors: true)
        }
    }

    func setSharedFileCommentRating(hash: String, comment: String, rating: Int) {
        guard isBridgeOpSupported("shared-file-comment-rating") else { return }
        run(label: "shared-file-comment-rating") {
            let (_, raw) = try await self.bridge.sharedFileCommentRating(hash: hash, comment: comment, rating: rating, config: self.config)
            await MainActor.run { self.appendLog("$ shared-file-comment-rating \(hash)\n\(raw)") }
            try await self.refreshSharedFilesNow(logOutput: false, suppressErrors: true)
        }
    }
}
```

- [ ] **Step 3: Add Shared Files context menu**

In `SharedFilesWindowView.swift`, add row context actions:

```swift
Menu("Priority") {
    Button("Very Low") { model.setSharedFilePriority(hash: file.hash, priority: 1) }
    Button("Low") { model.setSharedFilePriority(hash: file.hash, priority: 2) }
    Button("Normal") { model.setSharedFilePriority(hash: file.hash, priority: 5) }
    Button("High") { model.setSharedFilePriority(hash: file.hash, priority: 7) }
    Button("Very High") { model.setSharedFilePriority(hash: file.hash, priority: 9) }
    Button("Auto") { model.setSharedFilePriority(hash: file.hash, priority: 10) }
}
.disabled(model.isBusy || !model.isBridgeOpSupported("shared-file-priority"))

Button("Edit Comment and Rating") {
    selectedSharedFileForComment = file
}
.disabled(model.isBusy || !model.isBridgeOpSupported("shared-file-comment-rating"))

Button("Copy eD2k Link") {
    model.pasteboardShare.writeString(file.ed2kLink)
}
```

Use an edit sheet with a text field and rating picker from 0 through 5. On Apply, call `model.setSharedFileCommentRating(hash:comment:rating:)`.

- [ ] **Step 4: Run tests**

Run:

```bash
cd native-macos/AMuleNativeRemote
swift test --filter SharedFilesParityTests
swift test --filter AMuleNativeRemoteTests
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
git add native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+SharedFiles.swift native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/SharedFilesWindowView.swift native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/SharedFilesParityTests.swift native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/FakeBridgeAdapter.swift
git commit -m "feat: align shared files with amulegui"
```

### Task 7: Servers, Kad, And Server Logs Parity

**Files:**
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Servers.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/ServersWindowView.swift`
- Create: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/ServerLogsWindowView.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/DiagnosticsWindowView.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AMuleNativeRemoteApp.swift`
- Create: `native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/ServersParityTests.swift`

- [ ] **Step 1: Add tests for server static/priority/log methods**

Create `ServersParityTests.swift`:

```swift
import XCTest
@testable import AMuleNativeRemote

@MainActor
final class ServersParityTests: XCTestCase {
    func testServerStaticAndPriorityInvokeBridge() async throws {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["server-set-static", "server-set-priority", "servers"])
        let model = AppModel(bridge: bridge)

        model.setServerStatic(ecid: 42, isStatic: true)
        model.setServerPriority(ecid: 42, priority: 2)
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(bridge.invokedOperations.contains("server-set-static"))
        XCTAssertEqual(bridge.lastServerPriority, 2)
    }

    func testServerLogRefreshStoresLines() async throws {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["server-info"])
        let model = AppModel(bridge: bridge)

        model.refreshServerInfo()
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(model.serverInfoLines, ["server log"])
    }
}
```

- [ ] **Step 2: Add AppModel state and actions**

Add to `AppModel.swift`:

```swift
@Published var serverInfoLines: [String] = []
@Published var lastServerInfoRawOutput = ""
```

Add to `AppModel+Servers.swift`:

```swift
func setServerStatic(ecid: Int, isStatic: Bool) {
    guard isBridgeOpSupported("server-set-static") else { return }
    run(label: "server-set-static") {
        let (_, raw) = try await self.bridge.serverSetStatic(ecid: ecid, isStatic: isStatic, config: self.config)
        await MainActor.run { self.appendLog("$ server-set-static \(ecid) \(isStatic)\n\(raw)") }
        try await self.refreshServersNow(logOutput: false, suppressErrors: true)
    }
}

func setServerPriority(ecid: Int, priority: Int) {
    guard isBridgeOpSupported("server-set-priority") else { return }
    run(label: "server-set-priority") {
        let (_, raw) = try await self.bridge.serverSetPriority(ecid: ecid, priority: priority, config: self.config)
        await MainActor.run { self.appendLog("$ server-set-priority \(ecid) \(priority)\n\(raw)") }
        try await self.refreshServersNow(logOutput: false, suppressErrors: true)
    }
}

func refreshServerInfo() {
    guard isBridgeOpSupported("server-info") else { return }
    run(label: "server-info") {
        let (payload, raw) = try await self.bridge.serverInfo(config: self.config)
        await MainActor.run {
            self.serverInfoLines = payload.lines
            self.lastServerInfoRawOutput = raw
            self.appendLog("$ server-info\n\(raw)")
        }
    }
}

func clearServerInfo() {
    guard isBridgeOpSupported("clear-server-info") else { return }
    run(label: "clear-server-info") {
        let (_, raw) = try await self.bridge.clearServerInfo(config: self.config)
        await MainActor.run {
            self.serverInfoLines = []
            self.appendLog("$ clear-server-info\n\(raw)")
        }
    }
}
```

- [ ] **Step 3: Add server UI actions**

In `ServersWindowView.swift`, extend `serverContextMenu(_:)`:

```swift
Button(item.isStatic ? "Remove Static Flag" : "Mark Static") {
    model.setServerStatic(ecid: item.id, isStatic: !item.isStatic)
}
.disabled(!model.isBridgeOpSupported("server-set-static"))

Menu("Priority") {
    Button("Low") { model.setServerPriority(ecid: item.id, priority: 1) }
    Button("Normal") { model.setServerPriority(ecid: item.id, priority: 0) }
    Button("High") { model.setServerPriority(ecid: item.id, priority: 2) }
}
.disabled(!model.isBridgeOpSupported("server-set-priority"))
```

- [ ] **Step 4: Add server log window**

Create `ServerLogsWindowView.swift`:

```swift
import SwiftUI

struct ServerLogsWindowView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Refresh") { model.refreshServerInfo() }
                    .disabled(model.isBusy || !model.isBridgeOpSupported("server-info"))
                Button("Clear") { model.clearServerInfo() }
                    .disabled(model.isBusy || !model.isBridgeOpSupported("clear-server-info"))
                Spacer()
            }
            .padding(10)
            Divider()
            ScrollView {
                Text(model.serverInfoLines.joined(separator: "\n"))
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .textSelection(.enabled)
            }
        }
        .frame(minWidth: 720, minHeight: 420)
        .task { model.refreshServerInfo() }
    }
}
```

Add a `WindowGroup("Server Logs", id: "server-logs-window")` in `AMuleNativeRemoteApp.swift`.

- [ ] **Step 5: Run tests**

Run:

```bash
cd native-macos/AMuleNativeRemote
swift test --filter ServersParityTests
swift test --filter AMuleNativeRemoteTests
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

Run:

```bash
git add native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel.swift native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Servers.swift native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/ServersWindowView.swift native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/ServerLogsWindowView.swift native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/DiagnosticsWindowView.swift native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AMuleNativeRemoteApp.swift native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/ServersParityTests.swift
git commit -m "feat: align server controls with amulegui"
```

### Task 8: Statistics And Kad Presentation Parity

**Files:**
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/StatsWindowView.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/ServersWindowView.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/ConnectionSheet.swift`
- Create: `native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/StatsKadParityTests.swift`

- [ ] **Step 1: Add static presentation tests**

Create `StatsKadParityTests.swift`:

```swift
import XCTest
@testable import AMuleNativeRemote

final class StatsKadParityTests: XCTestCase {
    func testKadStatusSummaryKeepsEd2kAndKadSeparate() {
        let summary = NetworkStatusSummary(ed2k: "Connected HighID", kad: "Connected")
        XCTAssertEqual(summary.ed2k, "Connected HighID")
        XCTAssertEqual(summary.kad, "Connected")
    }
}
```

Create `NetworkStatusSummary` as a small value type in a focused file or inside an existing status helper when implementing the test.

- [ ] **Step 2: Improve Stats window layout**

Update `StatsWindowView.swift` to show:

- stats tree in an outline-style hierarchy;
- graph sample columns for download, upload, connections, and Kad;
- a refresh control for tree and graph independently;
- a compact status header for eD2k and Kad using `model.status`.

- [ ] **Step 3: Improve Kad controls**

Keep existing Kad start/stop/bootstrap/nodes.dat actions in `ConnectionSheet.swift` and make them reachable from the eD2k/Servers window toolbar through a `Kad` menu.

- [ ] **Step 4: Run tests**

Run:

```bash
cd native-macos/AMuleNativeRemote
swift test --filter StatsKadParityTests
swift test --filter AMuleNativeRemoteTests
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
git add native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/StatsWindowView.swift native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/ServersWindowView.swift native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/ConnectionSheet.swift native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/StatsKadParityTests.swift
git commit -m "feat: improve statistics and kad parity"
```

### Task 9: Friends And Messages Remote Surface

**Files:**
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECModels.swift`
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECOperations.swift`
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECBridgeAdapter/SwiftECBridgeAdapter.swift`
- Create: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+FriendsMessages.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/FriendsWindowView.swift`
- Create: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/MessagesWindowView.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AMuleNativeRemoteApp.swift`
- Add tests under: `native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECClientTests/`
- Add tests under: `native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/`

- [ ] **Step 1: Verify upstream EC support before coding**

Read `src/amule-remote-gui.cpp` methods for `CFriendListRem::AddFriend`, `RemoveFriend`, `RequestSharedFileList`, and `SetFriendSlot`, plus `ChatWnd.cpp` and `FriendListCtrl.cpp`. Record the exact supported remote commands in the parity matrix before adding SwiftEC operations.

- [ ] **Step 2: Add friend-add builder tests**

Add tests only for commands verified in upstream remote code. The minimum set is:

```swift
func testFriendAddByHashUsesFriendOpcode() throws {
    let packet = try ECOperations.friendAdd(hash: "00112233445566778899aabbccddeeff", ip: "1.2.3.4", port: 4662, name: "Alice")
    XCTAssertEqual(packet.opcode, 0x57)
}
```

- [ ] **Step 3: Implement verified friend operations**

Implement friend add by hash and friend add by client ECID if supported by the upstream request shape. Keep existing `friend-remove` and `friend-slot` behavior.

- [ ] **Step 4: Add messages window only for supported message flow**

If upstream remote chat send/receive is backed by EC messages in this branch, add `MessagesWindowView` with:

- conversation list;
- transcript;
- message input;
- send button;
- add/remove friend from conversation.

If the branch lacks a remote message send opcode, create `MessagesWindowView` as a read-only placeholder-free unavailable state that explains through disabled controls only; do not advertise unsupported capabilities.

- [ ] **Step 5: Run tests**

Run:

```bash
cd native-macos/AMuleNativeRemote/SwiftEC
swift test --filter Friend
cd ../
swift test --filter Friends
```

Expected: supported friend operations pass; unsupported chat operations are not advertised.

- [ ] **Step 6: Commit**

Run:

```bash
git add native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECModels.swift native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECOperations.swift native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECBridgeAdapter/SwiftECBridgeAdapter.swift native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+FriendsMessages.swift native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/FriendsWindowView.swift native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/MessagesWindowView.swift native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AMuleNativeRemoteApp.swift native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECClientTests native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests
git commit -m "feat: add friends and messages parity surface"
```

### Task 10: Remote Preferences Expansion

**Files:**
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECModels.swift`
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECOperations.swift`
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECResponseParser.swift`
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECBridgeAdapter/SwiftECBridgeAdapter.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Preferences.swift`
- Modify: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/PreferencesWindowView.swift`
- Add tests under: `native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECClientTests/`
- Add tests under: `native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/`

- [ ] **Step 1: Expand preferences by groups**

Implement groups in this order:

1. Connection: existing max download/upload plus TCP/UDP ports and network enable flags.
2. Directories and files: incoming/temp directories and shared directories if exposed by remote preferences.
3. Servers: server.met URL, auto-update flags, retry behavior.
4. Security: IPFilter level, filter clients/servers, crypt layer flags.
5. Remote controls: external connection enabled state, EC port, EC auth metadata only when safe to expose.
6. Statistics: graph update interval and display limits.

- [ ] **Step 2: Add parser fixture tests per group**

For every group, add a fixture-backed parser test in `ECResponseParserTests.swift`. Use `CEC_Prefs_Packet` tag IDs from `src/libs/ec/cpp/ECCodes.h`; do not infer tag IDs from labels.

- [ ] **Step 3: Add UI sections**

Add grouped sections in `PreferencesWindowView.swift`. Each section must:

- show current daemon values after reload;
- validate inputs before sending;
- use bridge capability checks;
- write through only the changed group;
- refresh after apply.

- [ ] **Step 4: Run tests**

Run:

```bash
cd native-macos/AMuleNativeRemote/SwiftEC
swift test --filter Preferences
cd ../
swift test --filter Preferences
```

Expected: parser and AppModel preference tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
git add native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECModels.swift native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECOperations.swift native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECResponseParser.swift native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECBridgeAdapter/SwiftECBridgeAdapter.swift native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Preferences.swift native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/PreferencesWindowView.swift native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECClientTests native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests
git commit -m "feat: expand remote preferences parity"
```

### Task 11: Manual Parity QA Against Upstream `amulegui`

**Files:**
- Create: `docs/superpowers/evidence/2026-07-05-amulegui-parity-qa.md`
- Modify: `docs/superpowers/evidence/2026-07-05-amulegui-feature-parity-matrix.md`

- [ ] **Step 1: Build or run upstream remote GUI**

Run the available upstream remote GUI build for this repo. If it is already available, record the command used. If not available, record the local reason in the QA file and compare against source-level menus and EC commands.

- [ ] **Step 2: Create QA checklist**

Create `docs/superpowers/evidence/2026-07-05-amulegui-parity-qa.md`:

```markdown
# aMuleGUI Parity QA

Daemon/core endpoint:
- Host:
- Port:
- Version:

Checks:
- [ ] Connect/disconnect behaves like upstream remote GUI.
- [ ] Downloads list columns and context actions cover pause, resume, stop, cancel, priority, clear completed, category assignment, copy links, details, and A4AF.
- [ ] Search supports local/global/Kad, extended fields, filtering, stop, clear, and download.
- [ ] eD2k server list supports add, remove, connect, disconnect, server.met URL, static flag, priority, and server log.
- [ ] Kad controls support start, stop, bootstrap IP/port, and nodes.dat URL update.
- [ ] Shared files support reload, priority, comments/ratings, link copy, and visible transfer stats.
- [ ] Uploads show current upload clients and totals.
- [ ] Friends support list refresh, remove, friend slot, and all supported add/message actions.
- [ ] Statistics tree and graphs load and refresh.
- [ ] Preferences reload/apply supported remote groups without corrupting unrelated settings.
```

- [ ] **Step 3: Update matrix statuses**

Update each row status in `2026-07-05-amulegui-feature-parity-matrix.md` to one of:

- `matched`;
- `matched with native UI`;
- `unsupported by daemon EC`;
- `deferred with reason`.

- [ ] **Step 4: Commit**

Run:

```bash
git add docs/superpowers/evidence/2026-07-05-amulegui-parity-qa.md docs/superpowers/evidence/2026-07-05-amulegui-feature-parity-matrix.md
git commit -m "docs: record amulegui parity qa"
```

### Task 12: Final Verification

**Files:**
- No source changes expected.

- [ ] **Step 1: Run SwiftEC verification**

Run:

```bash
cd native-macos/AMuleNativeRemote/SwiftEC
swift test
./Scripts/check-forbidden-deps.sh
```

Expected: all tests pass and forbidden dependency check exits with status 0.

- [ ] **Step 2: Run shared package verification**

Run:

```bash
cd native-macos/AMuleNativeRemote/Packages/Shared
swift test
```

Expected: all tests pass.

- [ ] **Step 3: Run macOS app tests and strict build**

Run:

```bash
cd native-macos/AMuleNativeRemote
swift test
swift build -Xswiftc -warnings-as-errors
```

Expected: both commands pass.

- [ ] **Step 4: Run app bundle smoke**

Run:

```bash
cd native-macos/AMuleNativeRemote
./scripts/build-app.sh
plutil -lint "dist/aMule Remote.app/Contents/Info.plist"
```

Expected: app bundle builds and `plutil` reports `OK`.

- [ ] **Step 5: Commit verification evidence if docs changed**

Run:

```bash
git status --short
```

If only QA or evidence docs changed during verification, commit them:

```bash
git add docs/superpowers/evidence
git commit -m "docs: update amulegui parity verification"
```

## Risk Notes

- Keep remote GUI parity distinct from local full `amule` parity. The native macOS app remains an EC remote client.
- For every new operation, verify the upstream opcode and tag shape from `src/libs/ec/cpp/ECCodes.h` and `src/amule-remote-gui.cpp`.
- Do not advertise a bridge capability until builder, adapter method, parser or mutation response handling, AppModel method, fake bridge, and at least one test exist.
- Preserve the persistent SwiftEC session and state stores for download/source update semantics.
- Avoid moving iOS navigation or iPhone UI patterns into macOS while extending shared models.
