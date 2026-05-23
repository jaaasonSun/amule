# SwiftEC Stateful Protocol Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make SwiftEC preserve original aMule EC persistent-client behavior so downloads, alternative names, sources, and rename refreshes stop regressing each other.

**Architecture:** Add a per-session EC model state layer that merges full snapshots and incremental update packets before data reaches macOS/iOS UI. Keep low-level packet parsing pure, then add stateful merge types for source-name IDs, part-file deltas, and client/source deltas.

**Tech Stack:** Swift 6, SwiftPM XCTest, `native-macos/AMuleNativeRemote/SwiftEC`, iOS shared package tests, Xcode iOS device build.

---

## Source References

- Protocol doc: `native-macos/AMuleNativeRemote/docs/original-amule-ec-protocol-notes.md`
- Original daemon delta encoder: `src/ExternalConn.cpp`
- Original remote GUI merge behavior: `src/amule-remote-gui.cpp`
- Swift protocol package: `native-macos/AMuleNativeRemote/SwiftEC/Sources`
- SwiftEC tests: `native-macos/AMuleNativeRemote/SwiftEC/Tests`

## Task 1: Add Source-Name Delta State Tests

**Files:**

- Create: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECDownloadStateStore.swift`
- Create: `native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECClientTests/ECDownloadStateStoreTests.swift`

- [ ] **Step 1: Create the failing tests**

Add tests that express original remote GUI behavior: new alternative names include a name and count, later count-only deltas keep the old name, and count zero removes the entry.

```swift
import XCTest
import AMuleECProtocol
@testable import AMuleECClient

final class ECDownloadStateStoreTests: XCTestCase {
    func testSourceNameDeltasPreserveNamesAcrossCountOnlyUpdates() throws {
        var store = ECDownloadStateStore()
        let full = Self.partFile(ecid: 42, hash: "00112233445566778899aabbccddeeff", name: "current.iso")
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(ECPacket(opcode: 0x1F, tags: [full])))

        let newNameDelta = Self.partFile(
            ecid: 42,
            hash: "00112233445566778899aabbccddeeff",
            name: "current.iso",
            sourceNameEntries: [
                Self.sourceNameEntry(id: 7, name: "better.iso", count: 3)
            ]
        )
        store.applyIncrementalUpdate(ECPacket(opcode: 0x22, tags: [newNameDelta]))
        XCTAssertEqual(store.downloads.first?.alternativeNames, [
            ECDownload.AlternativeName(name: "better.iso", count: 3)
        ])

        let countOnlyDelta = Self.partFile(
            ecid: 42,
            hash: "00112233445566778899aabbccddeeff",
            name: "current.iso",
            sourceNameEntries: [
                Self.sourceNameEntry(id: 7, name: nil, count: 5)
            ]
        )
        store.applyIncrementalUpdate(ECPacket(opcode: 0x22, tags: [countOnlyDelta]))
        XCTAssertEqual(store.downloads.first?.alternativeNames, [
            ECDownload.AlternativeName(name: "better.iso", count: 5)
        ])
    }

    func testSourceNameCountZeroRemovesCachedAlternativeName() throws {
        var store = ECDownloadStateStore()
        let full = Self.partFile(ecid: 42, hash: "00112233445566778899aabbccddeeff", name: "current.iso")
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(ECPacket(opcode: 0x1F, tags: [full])))
        store.applyIncrementalUpdate(ECPacket(opcode: 0x22, tags: [
            Self.partFile(ecid: 42, hash: "00112233445566778899aabbccddeeff", name: "current.iso", sourceNameEntries: [
                Self.sourceNameEntry(id: 7, name: "better.iso", count: 3)
            ])
        ]))
        store.applyIncrementalUpdate(ECPacket(opcode: 0x22, tags: [
            Self.partFile(ecid: 42, hash: "00112233445566778899aabbccddeeff", name: "current.iso", sourceNameEntries: [
                Self.sourceNameEntry(id: 7, name: nil, count: 0)
            ])
        ]))
        XCTAssertEqual(store.downloads.first?.alternativeNames, [])
    }

    private static func partFile(ecid: Int, hash: String, name: String, sourceNameEntries: [ECTag] = []) -> ECTag {
        var children = [
            ECTag(name: 0x0301, type: .string, value: .string(name)),
            ECTag(name: 0x031E, type: .hash16, value: .hash16(Data(hex: hash))),
            ECTag.integer(name: 0x0303, value: 100),
            ECTag.integer(name: 0x0306, value: 10),
            ECTag.integer(name: 0x0308, value: 7),
        ]
        if !sourceNameEntries.isEmpty {
            children.append(ECTag(name: 0x0315, type: .unknown, children: sourceNameEntries))
        }
        return ECTag.integer(name: 0x0300, value: UInt64(ecid), children: children)
    }

    private static func sourceNameEntry(id: Int, name: String?, count: Int) -> ECTag {
        var children = [ECTag.integer(name: 0x031C, value: UInt64(count))]
        if let name {
            children.append(ECTag(name: 0x0315, type: .string, value: .string(name)))
        }
        return ECTag.integer(name: 0x0315, value: UInt64(id), children: children)
    }
}

private extension Data {
    init(hex: String) {
        self.init()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            append(UInt8(hex[index..<next], radix: 16)!)
            index = next
        }
    }
}
```

- [ ] **Step 2: Run the failing tests**

Run:

```bash
cd /Users/jason/Repos.localized/amule/native-macos/AMuleNativeRemote/SwiftEC
swift test --filter ECDownloadStateStoreTests
```

Expected before implementation: build fails because `ECDownloadStateStore` does not exist.

## Task 2: Implement Download State Merge

**Files:**

- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECDownloadStateStore.swift`

- [ ] **Step 1: Implement state storage**

Implement a public `ECDownloadStateStore` with:

```swift
public struct ECDownloadStateStore: Sendable {
    public private(set) var downloads: [ECDownload] = []
    private var downloadsByECID: [Int: ECDownload] = [:]
    private var sourceNamesByECID: [Int: [Int: ECDownload.AlternativeName]] = [:]

    public init() {}

    public mutating func replaceDownloadSnapshot(_ snapshot: [ECDownload]) {
        let liveIDs = Set(snapshot.map(\.ecid))
        downloadsByECID = Dictionary(uniqueKeysWithValues: snapshot.map { download in
            let alternatives = sourceNamesByECID[download.ecid, default: [:]]
                .values
                .filter { $0.name != download.name && $0.count > 0 }
                .sorted { lhs, rhs in lhs.count == rhs.count ? lhs.name < rhs.name : lhs.count > rhs.count }
            return (download.ecid, download.replacingAlternativeNames(Array(alternatives.prefix(12))))
        })
        sourceNamesByECID = sourceNamesByECID.filter { liveIDs.contains($0.key) }
        downloads = snapshot.compactMap { downloadsByECID[$0.ecid] }
    }

    public mutating func applyIncrementalUpdate(_ packet: ECPacket) {
        for tag in packet.tags where tag.name == 0x0300 {
            applyPartFileDelta(tag)
        }
        downloads = downloads.map { downloadsByECID[$0.ecid] ?? $0 }
    }
}
```

Add focused private helpers for `applyPartFileDelta`, source-name parsing, and sorting. Add an internal `ECDownload.replacingAlternativeNames(_:)` helper in the same file.

- [ ] **Step 2: Run the state tests**

Run:

```bash
swift test --filter ECDownloadStateStoreTests
```

Expected: tests pass.

## Task 3: Wire State Into SwiftECBridgeAdapter

**Files:**

- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECBridgeAdapter/SwiftECBridgeAdapter.swift`
- Test: `native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECBridgeAdapterTests/AMuleECBridgeAdapterTests.swift`

- [ ] **Step 1: Add adapter test for merged downloads**

Add a test where the mock transport replies to auth, then `GET_DLOAD_QUEUE`, then `GET_UPDATE` with source-name delta. Assert `downloads()` returns the alternative name and that sent opcodes are `[0x02, 0x50, 0x0D, 0x52]`.

- [ ] **Step 2: Add state actor to adapter**

Add:

```swift
private actor ECBridgeModelState {
    private var downloads = ECDownloadStateStore()

    func replaceDownloads(_ snapshot: [ECDownload]) -> [ECDownload] {
        downloads.replaceDownloadSnapshot(snapshot)
        return downloads.downloads
    }

    func applyUpdate(_ packet: ECPacket) -> [ECDownload] {
        downloads.applyIncrementalUpdate(packet)
        return downloads.downloads
    }
}
```

Store `private let modelState = ECBridgeModelState()` in `SwiftECBridgeAdapter`.

- [ ] **Step 3: Merge snapshot plus update in downloads()**

Update `downloads(config:)` so it sends `ECOperations.downloads()` for the full snapshot, parses it, replaces state, then sends `ECOperations.sourcesUpdate()` once to apply incremental fields. If the update request fails, return the stable snapshot rather than clearing the list.

- [ ] **Step 4: Run adapter tests**

Run:

```bash
swift test --filter AMuleECBridgeAdapterTests
```

Expected: all adapter tests pass.

## Task 4: Fix Zlib Negotiation Guardrails

**Files:**

- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECConnection.swift`
- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECSession.swift`
- Test: `native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECClientTests/ECSessionTests.swift`

- [ ] **Step 1: Add test that unnegotiated sessions do not send zlib**

Use a mock transport to send a packet over `ECSession` with `advertisesZlib: false`; assert the sent packet header flags do not include `0x01` even for a large packet.

- [ ] **Step 2: Thread compression permission through transport send**

Change `ECConnectionTransport.send` to accept `compressionEnabled: Bool`, and have `ECSession` pass `configuration.advertisesZlib && (configuration.packetFlags & ECCompression.flag) != 0`.

- [ ] **Step 3: Run protocol/session tests**

Run:

```bash
swift test --filter ECSessionTests
swift test --filter ECCompressionTests
```

Expected: tests pass and existing compression roundtrip coverage still passes.

## Task 5: Add Invalid Flag Validation

**Files:**

- Modify: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECProtocol/ECPacket.swift`
- Test: `native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECProtocolTests/ECPacketHeaderTests.swift`

- [ ] **Step 1: Add invalid flag test**

Add assertions that `ECPacket.decode` rejects a header with `(flags & 0x60) != 0x20` and a header containing `0xff7f7f08` bits.

- [ ] **Step 2: Implement validation**

Add constants:

```swift
public static let requiredFlagMask: UInt32 = 0x60
public static let requiredFlagValue: UInt32 = 0x20
public static let unknownFlagMask: UInt32 = 0xff7f7f08
```

Validate in `ECPacket.decode` immediately after reading the header.

- [ ] **Step 3: Run packet tests**

Run:

```bash
swift test --filter ECPacket
```

Expected: packet/header tests pass.

## Task 6: Full Verification And Device Install

**Files:**

- No source edits.

- [ ] **Step 1: Run SwiftEC tests**

Run:

```bash
cd /Users/jason/Repos.localized/amule/native-macos/AMuleNativeRemote/SwiftEC
swift test
```

Expected: all SwiftEC tests pass.

- [ ] **Step 2: Run iOS shared tests**

Run:

```bash
cd /Users/jason/Repos.localized/amule/native-macos/AMuleNativeRemote/iOS
swift test
```

Expected: all iOS shared tests pass.

- [ ] **Step 3: Build and install on iPad**

Run:

```bash
cd /Users/jason/Repos.localized/amule/native-macos/AMuleNativeRemote
xcodebuild -project AMuleRemoteiOS.xcodeproj -scheme AMuleRemoteiOS -configuration Debug -destination "platform=iOS,id=E4E07D65-61B7-5009-BF61-808A229D6A94" -derivedDataPath /tmp/amule-ios-ipad-build build
xcrun devicectl device install app --device E4E07D65-61B7-5009-BF61-808A229D6A94 /tmp/amule-ios-ipad-build/Build/Products/Debug-iphoneos/AMuleRemoteiOS.app
```

Expected: build succeeds and the app installs.

- [ ] **Step 4: Manual protocol QA**

Verify on device:

- Download list remains populated after several refreshes.
- Alternative names remain visible after several refreshes.
- Source detail view remains populated after repeated opens.
- Rename failure, if any, shows daemon `EC_OP_FAILED` text instead of a generic connection error.
