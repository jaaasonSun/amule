import XCTest
import Foundation
import AMuleECProtocol
import Fixtures
@testable import AMuleECClient

final class ECDownloadStateStoreTests: XCTestCase {
    func testSourceNameDeltasPreserveNamesAcrossCountOnlyUpdates() throws {
        var store = ECDownloadStateStore()
        let snapshot = try ECResponseParser.parseDownloads(ECDownloadPacketFixtures.snapshotPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "current.iso"),
        ]))
        store.replaceDownloadSnapshot(snapshot)

        store.applyIncrementalUpdate(ECDownloadPacketFixtures.incrementalPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "current.iso", sourceNameEntries: [
                ECDownloadPacketFixtures.sourceNameEntry(id: 7, name: "better.iso", count: 3),
            ]),
        ]))
        XCTAssertEqual(store.downloads.first?.alternativeNames, [
            ECDownload.AlternativeName(name: "better.iso", count: 3),
        ])

        store.applyIncrementalUpdate(ECDownloadPacketFixtures.incrementalPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "current.iso", sourceNameEntries: [
                ECDownloadPacketFixtures.sourceNameEntry(id: 7, name: nil, count: 5),
            ]),
        ]))
        XCTAssertEqual(store.downloads.first?.alternativeNames, [
            ECDownload.AlternativeName(name: "better.iso", count: 5),
        ])
    }

    func testSourceNameCountZeroRemovesCachedAlternativeName() throws {
        var store = ECDownloadStateStore()
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(ECDownloadPacketFixtures.snapshotPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "current.iso"),
        ])))
        store.applyIncrementalUpdate(ECDownloadPacketFixtures.incrementalPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "current.iso", sourceNameEntries: [
                ECDownloadPacketFixtures.sourceNameEntry(id: 7, name: "better.iso", count: 3),
            ]),
        ]))
        store.applyIncrementalUpdate(ECDownloadPacketFixtures.incrementalPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "current.iso", sourceNameEntries: [
                ECDownloadPacketFixtures.sourceNameEntry(id: 7, name: nil, count: 0),
            ]),
        ]))

        XCTAssertEqual(store.downloads.first?.alternativeNames, [])
    }

    func testSnapshotKeepsCachedAlternativeNamesAndDropsVanishedFiles() throws {
        var store = ECDownloadStateStore()
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(ECDownloadPacketFixtures.snapshotPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "current.iso"),
        ])))
        store.applyIncrementalUpdate(ECDownloadPacketFixtures.incrementalPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "current.iso", sourceNameEntries: [
                ECDownloadPacketFixtures.sourceNameEntry(id: 7, name: "better.iso", count: 3),
            ]),
        ]))
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(ECDownloadPacketFixtures.snapshotPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "renamed.iso"),
        ])))

        XCTAssertEqual(store.downloads.first?.name, "renamed.iso")
        XCTAssertEqual(store.downloads.first?.alternativeNames, [
            ECDownload.AlternativeName(name: "better.iso", count: 3),
        ])

        store.replaceDownloadSnapshot([])
        XCTAssertEqual(store.downloads, [])
    }

    func testFullSnapshotReplacesVisibleDownloadList() throws {
        var store = ECDownloadStateStore()
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(ECDownloadPacketFixtures.snapshotPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "current.iso"),
        ])))
        store.applyIncrementalUpdate(ECDownloadPacketFixtures.incrementalPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "current.iso", sourceNameEntries: [
                ECDownloadPacketFixtures.sourceNameEntry(id: 7, name: "better.iso", count: 3),
            ]),
        ]))

        let replacementHash = "ffeeddccbbaa99887766554433221100"
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(ECDownloadPacketFixtures.snapshotPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 99, hash: replacementHash, name: "replacement.iso"),
        ])))

        XCTAssertEqual(store.downloads.map(\.ecid), [99])
        XCTAssertEqual(store.downloads.first?.alternativeNames, [])
    }

    func testSnapshotSourcePacketSeedsIDsForCountOnlyUpdate() throws {
        var store = ECDownloadStateStore()
        let snapshotPacket = ECDownloadPacketFixtures.snapshotPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "current.iso", sourceNameEntries: [
                ECDownloadPacketFixtures.sourceNameEntry(id: 7, name: "better.iso", count: 3),
            ]),
        ])
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(snapshotPacket), sourcePacket: snapshotPacket)

        store.applyIncrementalUpdate(ECDownloadPacketFixtures.incrementalPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "current.iso", sourceNameEntries: [
                ECDownloadPacketFixtures.sourceNameEntry(id: 7, name: nil, count: 5),
            ]),
        ]))

        XCTAssertEqual(store.downloads.first?.alternativeNames, [
            ECDownload.AlternativeName(name: "better.iso", count: 5),
        ])
    }

    func testSnapshotWithDuplicateECIDsKeepsLastRowWithoutCrashing() throws {
        var store = ECDownloadStateStore()
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(ECDownloadPacketFixtures.snapshotPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "first.iso"),
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "second.iso"),
        ])))

        XCTAssertEqual(store.downloads.map(\.ecid), [42])
        XCTAssertEqual(store.downloads.first?.name, "second.iso")
        XCTAssertEqual(store.lifecycle(forECID: 42), .active)
    }

    func testStaleSnapshotOmissionRetainsCompletedButTombstonesActiveRows() throws {
        var store = ECDownloadStateStore()
        store.replaceDownloadSnapshot([
            Self.download(ecid: 42, hash: Self.hash, name: "active.iso"),
            Self.download(ecid: 43, hash: Self.otherHash, name: "done.iso", completed: true),
        ])

        store.replaceDownloadSnapshot([])

        XCTAssertEqual(store.downloads.map(\.ecid), [43])
        XCTAssertEqual(store.downloads.first?.name, "done.iso")
        XCTAssertEqual(store.lifecycle(forECID: 42), .tombstoned)
        XCTAssertEqual(store.lifecycle(forECID: 43), .tombstoned)
    }

    func testOutOfOrderIncrementalUpdateDoesNotResurrectTombstonedRows() throws {
        var store = ECDownloadStateStore()
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(ECDownloadPacketFixtures.snapshotPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "active.iso"),
        ])))
        store.replaceDownloadSnapshot([])

        store.applyIncrementalUpdate(ECDownloadPacketFixtures.incrementalPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "active.iso", sourceNameEntries: [
                ECDownloadPacketFixtures.sourceNameEntry(id: 7, name: "stale.iso", count: 4),
            ]),
        ]))

        XCTAssertEqual(store.downloads, [])
        XCTAssertEqual(store.lifecycle(forECID: 42), .tombstoned)
    }

    func testClearCompletedAcknowledgementHidesRowsUntilValidSnapshotReturnsThem() throws {
        var store = ECDownloadStateStore()
        store.replaceDownloadSnapshot([Self.download(ecid: 43, hash: Self.otherHash, name: "done.iso", completed: true)])

        store.acknowledgeClearCompleted(ecids: [43])
        XCTAssertEqual(store.downloads, [])
        XCTAssertEqual(store.lifecycle(forECID: 43), .cleared)

        store.applyIncrementalUpdate(ECDownloadPacketFixtures.incrementalPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 43, hash: Self.otherHash, name: "done.iso", sourceNameEntries: [
                ECDownloadPacketFixtures.sourceNameEntry(id: 8, name: "ghost.iso", count: 2),
            ]),
        ]))
        XCTAssertEqual(store.downloads, [])

        store.replaceDownloadSnapshot([Self.download(ecid: 43, hash: Self.otherHash, name: "done.iso", completed: true)])
        XCTAssertEqual(store.downloads.map(\.ecid), [43])
        XCTAssertEqual(store.lifecycle(forECID: 43), .completedRetained)
    }

    func testSparseIncrementalUpdateRetainsExistingActiveDownload() throws {
        var store = ECDownloadStateStore()
        let fullPacket = ECDownloadPacketFixtures.snapshotPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "active.iso", statusCode: 3),
        ])
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(fullPacket), sourcePacket: fullPacket)
        XCTAssertEqual(store.downloads.first?.name, "active.iso")
        XCTAssertEqual(store.downloads.first?.statusCode, 3)

        let sparsePacket = ECDownloadPacketFixtures.snapshotPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "active.iso", statusCode: 3, sourceNameEntries: [
                ECDownloadPacketFixtures.sourceNameEntry(id: 7, name: "better.iso", count: 2),
            ]),
        ])
        let sparseParsed = try ECResponseParser.parseDownloads(sparsePacket)
        store.replaceDownloadSnapshot(sparseParsed, sourcePacket: sparsePacket)

        XCTAssertEqual(store.downloads.first?.name, "active.iso")
        XCTAssertEqual(store.downloads.first?.statusCode, 3)
        XCTAssertEqual(store.downloads.first?.alternativeNames, [
            ECDownload.AlternativeName(name: "better.iso", count: 2),
        ])
    }

    func testSparseIncrementalUpdateWithStatusChangeUpdatesActiveDownload() throws {
        var store = ECDownloadStateStore()
        let fullPacket = ECDownloadPacketFixtures.snapshotPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "active.iso", statusCode: 3),
        ])
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(fullPacket), sourcePacket: fullPacket)

        let changedPacket = ECDownloadPacketFixtures.snapshotPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "active.iso", statusCode: 4),
        ])
        let changedParsed = try ECResponseParser.parseDownloads(changedPacket)
        store.replaceDownloadSnapshot(changedParsed, sourcePacket: changedPacket)

        XCTAssertEqual(store.downloads.first?.name, "active.iso")
        XCTAssertEqual(store.downloads.first?.statusCode, 4)
    }

    func testReconnectSnapshotReconcilesRetainedTombstoneBackToActive() throws {
        var store = ECDownloadStateStore()
        store.replaceDownloadSnapshot([Self.download(ecid: 43, hash: Self.otherHash, name: "done.iso", completed: true)])
        store.replaceDownloadSnapshot([])
        XCTAssertEqual(store.downloads.map(\.ecid), [43])
        XCTAssertEqual(store.lifecycle(forECID: 43), .tombstoned)

        store.replaceDownloadSnapshot([Self.download(ecid: 43, hash: Self.otherHash, name: "resumed.iso")])

        XCTAssertEqual(store.downloads.map(\.name), ["resumed.iso"])
        XCTAssertEqual(store.lifecycle(forECID: 43), .active)
    }

    func testSparseUpdateMergesNameChangeFromIncomingDownload() throws {
        var store = ECDownloadStateStore()
        let fullPacket = ECDownloadPacketFixtures.snapshotPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "old_name.iso", statusCode: 3),
        ])
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(fullPacket), sourcePacket: fullPacket)
        XCTAssertEqual(store.downloads.first?.name, "old_name.iso")
        XCTAssertEqual(store.downloads.first?.statusCode, 3)

        let sparsePacket = ECDownloadPacketFixtures.snapshotPacket(downloads: [
            try ECDownloadPacketFixtures.sparsePartFile(ecid: 42, hash: Self.hash, name: "new_name.iso"),
        ])
        let sparseParsed = try ECResponseParser.parseDownloads(sparsePacket)
        store.replaceDownloadSnapshot(sparseParsed, sourcePacket: sparsePacket)

        XCTAssertEqual(store.downloads.first?.name, "new_name.iso")
        XCTAssertEqual(store.downloads.first?.statusCode, 3)
    }

    func testSparseUpdateRetainsExistingNameWhenIncomingNameIsEmpty() throws {
        var store = ECDownloadStateStore()
        let fullPacket = ECDownloadPacketFixtures.snapshotPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "existing.iso", statusCode: 3),
        ])
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(fullPacket), sourcePacket: fullPacket)

        let sparseTag = ECTag.integer(name: 0x0300, value: UInt64(42), children: [
            ECTag.integer(name: 0x0303, value: 100),
        ])
        let sparsePacket = ECDownloadPacketFixtures.snapshotPacket(downloads: [sparseTag])
        let sparseParsed = try ECResponseParser.parseDownloads(sparsePacket)
        store.replaceDownloadSnapshot(sparseParsed, sourcePacket: sparsePacket)

        XCTAssertEqual(store.downloads.first?.name, "existing.iso")
        XCTAssertEqual(store.downloads.first?.statusCode, 3)
    }

    func testSharedOnlyAndMalformedLifecycleStatesAreRecorded() throws {
        var store = ECDownloadStateStore()
        let packet = ECDownloadPacketFixtures.snapshotPacket(downloads: [
            ECTag(name: 0x0300, type: .string, value: .string("not-an-ecid")),
        ])

        store.replaceDownloadSnapshot([Self.download(ecid: 44, hash: Self.thirdHash, name: "shared.iso", completed: true, sharedOnly: true)], sourcePacket: packet)

        XCTAssertEqual(store.downloads.map(\.ecid), [44])
        XCTAssertEqual(store.lifecycle(forECID: 44), .sharedOnly)
        XCTAssertEqual(store.lifecycle(forECID: 0), .malformedOmission)
    }

    private static let hash = "00112233445566778899aabbccddeeff"
    private static let otherHash = "ffeeddccbbaa99887766554433221100"
    private static let thirdHash = "11112222333344445555666677778888"

    private static func download(ecid: Int, hash: String, name: String, completed: Bool = false, sharedOnly: Bool = false) -> ECDownload {
        ECDownload(
            ecid: ecid,
            hash: hash,
            name: name,
            size: 100,
            done: completed ? 100 : 10,
            transferred: completed ? 100 : 10,
            progress: completed ? 100 : 10,
            sourcesCurrent: sharedOnly ? 0 : 1,
            sourcesTotal: sharedOnly ? 0 : 1,
            sourcesTransferring: 0,
            sourcesA4AF: 0,
            statusCode: completed ? 9 : 7,
            isCompleted: completed,
            status: completed ? "Completed" : "Waiting",
            speed: 0,
            priority: 0,
            category: 0,
            partMet: sharedOnly ? "" : "001.part.met",
            lastSeenComplete: 0,
            lastReceived: 0,
            activeSeconds: 0,
            availableParts: 0,
            shared: false
        )
    }
}
