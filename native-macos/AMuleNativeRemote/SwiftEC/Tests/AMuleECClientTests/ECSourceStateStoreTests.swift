import XCTest
import Foundation
import AMuleECProtocol
@testable import AMuleECClient

final class ECSourceStateStoreTests: XCTestCase {
    func testClientDeltasPreserveRequestFileAndIdentityFields() {
        var store = ECSourceStateStore()

        store.applyIncrementalUpdate(ECPacket(opcode: 0x22, tags: [
            Self.client(
                id: 99,
                children: [
                    .integer(name: 0x0620, value: 42),
                    ECTag(name: 0x0100, type: .string, value: .string("peer")),
                    ECTag(name: 0x0603, type: .hash16, value: .hash16(Data((0..<16).map(UInt8.init)))),
                    .integer(name: 0x0602, value: 75),
                    .integer(name: 0x0604, value: 1),
                    .integer(name: 0x0609, value: 4_096),
                    ECTag(name: 0x0610, type: .ipv4, value: .ipv4(ECIPv4Address(5, 6, 7, 8, port: 0))),
                    .integer(name: 0x0611, value: 4662),
                    .integer(name: 0x061E, value: 0x05060708),
                    .integer(name: 0x060C, value: 2),
                    .integer(name: 0x061C, value: 2),
                    .integer(name: 0x0617, value: 1),
                    .integer(name: 0x060D, value: 512),
                    ECTag(name: 0x060E, type: .double, value: .double(1.5)),
                    .integer(name: 0x0622, value: 13),
                    .integer(name: 0x0616, value: 4),
                    .integer(name: 0x0623, value: 4672),
                    ECTag(name: 0x0624, type: .custom, value: .custom(Data([0xaa, 0xbb]))),
                    .integer(name: 0x0625, value: 7),
                    .integer(name: 0x0626, value: 8),
                    ECTag(name: 0x0621, type: .custom, value: .custom(Data([0x01, 0x02]))),
                    .integer(name: 0x060A, value: 2_048),
                    .integer(name: 0x060B, value: 1_024),
                    ECTag(name: 0x0615, type: .string, value: .string("1.0")),
                    ECTag(name: 0x0628, type: .string, value: .string("Mod")),
                    ECTag(name: 0x0629, type: .string, value: .string("macOS")),
                    ECTag(name: 0x062B, type: .custom, value: .custom(Data([0xcc, 0xdd]))),
                    .integer(name: 0x061B, value: 0),
                ]
            ),
        ]))
        store.applyIncrementalUpdate(ECPacket(opcode: 0x22, tags: [
            Self.client(
                id: 99,
                children: [
                    .integer(name: 0x060C, value: 3),
                    ECTag(name: 0x060E, type: .double, value: .double(12.5)),
                ]
            ),
        ]))

        let sources = store.sources(for: 42)
        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources[0].clientID, 99)
        XCTAssertEqual(sources[0].requestFileID, 42)
        XCTAssertEqual(sources[0].clientName, "peer")
        XCTAssertEqual(sources[0].userIP, "5.6.7.8")
        XCTAssertEqual(sources[0].downloadState, 3)
        XCTAssertEqual(sources[0].downSpeedKBps, 12.5)
        XCTAssertEqual(sources[0].downloadedTotal, 1_024)
        XCTAssertEqual(sources[0].uploadedTotal, 2_048)
        XCTAssertEqual(sources[0].versionString, "1.0 - Mod")
        XCTAssertEqual(sources[0].sharesFileList, true)
        XCTAssertEqual(sources[0].clientHash, Data((0..<16).map(UInt8.init)))
        XCTAssertEqual(sources[0].score, 75)
        XCTAssertEqual(sources[0].friendSlot, true)
        XCTAssertEqual(sources[0].uploadSession, 4_096)
        XCTAssertEqual(sources[0].uploadState, 2)
        XCTAssertEqual(sources[0].identState, 1)
        XCTAssertEqual(sources[0].uploadSpeed, 512)
        XCTAssertEqual(sources[0].oldRemoteQueueRank, 13)
        XCTAssertEqual(sources[0].waitingPosition, 4)
        XCTAssertEqual(sources[0].userID, 0x05060708)
        XCTAssertEqual(sources[0].kadPort, 4672)
        XCTAssertEqual(sources[0].osInfo, "macOS")
        XCTAssertEqual(sources[0].partStatus, Data([0xaa, 0xbb]))
        XCTAssertEqual(sources[0].nextRequestedPart, 7)
        XCTAssertEqual(sources[0].lastDownloadingPart, 8)
        XCTAssertEqual(sources[0].a4afFiles, Data([0x01, 0x02]))
        XCTAssertEqual(sources[0].uploadPartStatus, Data([0xcc, 0xdd]))
    }

    func testClientWithoutChildrenPreservesCachedSource() {
        var store = ECSourceStateStore()

        store.applyIncrementalUpdate(ECPacket(opcode: 0x22, tags: [
            Self.client(id: 99, children: [
                .integer(name: 0x0620, value: 42),
                ECTag(name: 0x0100, type: .string, value: .string("peer")),
            ]),
        ]))
        store.applyIncrementalUpdate(ECPacket(opcode: 0x22, tags: [
            Self.client(id: 99, children: []),
        ]))

        XCTAssertEqual(store.sources(for: 42).map(\.clientID), [99])
        XCTAssertEqual(store.sources(for: 42).first?.clientName, "peer")
    }

    func testClientContainerRemovesCachedSourceAbsentFromCoreUpdate() {
        var store = ECSourceStateStore()

        store.applyIncrementalUpdate(ECPacket(opcode: 0x22, tags: [
            Self.client(id: 99, children: [
                .integer(name: 0x0620, value: 42),
                ECTag(name: 0x0100, type: .string, value: .string("peer")),
            ]),
        ]))
        store.applyIncrementalUpdate(ECPacket(opcode: 0x22, tags: [
            Self.client(id: 0, children: []),
        ]), contextRequestFileID: 42)

        XCTAssertEqual(store.sources(for: 42), [])
    }

    func testNestedClientContainerAppliesAllSourceDeltas() {
        var store = ECSourceStateStore()

        store.applyIncrementalUpdate(ECPacket(opcode: 0x22, tags: [
            Self.client(id: 0, children: [
                Self.client(id: 99, children: [
                    .integer(name: 0x0620, value: 42),
                    ECTag(name: 0x0100, type: .string, value: .string("peer-a")),
                ]),
                Self.client(id: 100, children: [
                    .integer(name: 0x0620, value: 42),
                    ECTag(name: 0x0100, type: .string, value: .string("peer-b")),
                ]),
            ]),
        ]))

        XCTAssertEqual(store.sources(for: 42).map(\.clientID), [99, 100])
    }

    func testClientRequestFileDeltaMovesSourceBetweenDownloads() {
        var store = ECSourceStateStore()

        store.applyIncrementalUpdate(ECPacket(opcode: 0x22, tags: [
            Self.client(id: 99, children: [
                .integer(name: 0x0620, value: 42),
                ECTag(name: 0x0100, type: .string, value: .string("peer")),
            ]),
        ]))
        store.applyIncrementalUpdate(ECPacket(opcode: 0x22, tags: [
            Self.client(id: 99, children: [
                .integer(name: 0x0620, value: 77),
            ]),
        ]))

        XCTAssertEqual(store.sources(for: 42), [])
        XCTAssertEqual(store.sources(for: 77).map(\.clientID), [99])
        XCTAssertEqual(store.sources(for: 77).first?.clientName, "peer")
    }

    func testContextRequestFileIDDoesNotInventOwnerWhenEveryClientIsMissingRequestFile() {
        var store = ECSourceStateStore()

        store.applyIncrementalUpdate(ECPacket(opcode: 0x22, tags: [
            Self.client(id: 99, children: [
                ECTag(name: 0x0100, type: .string, value: .string("peer")),
            ]),
        ]), contextRequestFileID: 42)

        XCTAssertEqual(store.sources(for: 42), [])
    }

    func testMissingRequestFileDeltaKeepsExistingOwner() {
        var store = ECSourceStateStore()

        store.applyIncrementalUpdate(ECPacket(opcode: 0x22, tags: [
            Self.client(id: 99, children: [
                .integer(name: 0x0620, value: 42),
                ECTag(name: 0x0100, type: .string, value: .string("peer")),
            ]),
        ]))
        store.applyIncrementalUpdate(ECPacket(opcode: 0x22, tags: [
            Self.client(id: 99, children: [
                .integer(name: 0x060C, value: 3),
            ]),
        ]), contextRequestFileID: 77)

        XCTAssertEqual(store.sources(for: 42).map(\.clientID), [99])
        XCTAssertEqual(store.sources(for: 42).first?.downloadState, 3)
        XCTAssertEqual(store.sources(for: 77), [])
    }

    func testContextRequestFileIDDoesNotAssociateMissingRequestFileWhenPacketContainsOtherFile() {
        var store = ECSourceStateStore()

        store.applyIncrementalUpdate(ECPacket(opcode: 0x22, tags: [
            Self.client(id: 99, children: [
                ECTag(name: 0x0100, type: .string, value: .string("missing-file-id")),
            ]),
            Self.client(id: 100, children: [
                .integer(name: 0x0620, value: 77),
                ECTag(name: 0x0100, type: .string, value: .string("other-file")),
            ]),
        ]), contextRequestFileID: 42)

        XCTAssertEqual(store.sources(for: 42), [])
        XCTAssertEqual(store.sources(for: 77).map(\.clientID), [100])
    }

    func testExplicitZeroRequestFileRemovesCachedSource() {
        var store = ECSourceStateStore()

        store.applyIncrementalUpdate(ECPacket(opcode: 0x22, tags: [
            Self.client(id: 99, children: [
                .integer(name: 0x0620, value: 42),
                ECTag(name: 0x0100, type: .string, value: .string("peer")),
            ]),
        ]))
        store.applyIncrementalUpdate(ECPacket(opcode: 0x22, tags: [
            Self.client(id: 99, children: [
                .integer(name: 0x0620, value: 0),
            ]),
        ]), contextRequestFileID: 42)

        XCTAssertEqual(store.sources(for: 42), [])
    }

    private static func client(id: Int, children: [ECTag]) -> ECTag {
        ECTag.integer(name: 0x0600, value: UInt64(id), children: children)
    }
}
