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

    func testStaleSnapshotOmissionDoesNotRetainCompletingRowsAsCompleted() throws {
        var store = ECDownloadStateStore()
        let completingPacket = ECDownloadPacketFixtures.snapshotPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "finishing.iso", size: 100, done: 100, statusCode: 8),
        ])
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(completingPacket), sourcePacket: completingPacket)

        store.replaceDownloadSnapshot([])

        XCTAssertEqual(store.downloads, [])
        XCTAssertEqual(store.lifecycle(forECID: 42), .tombstoned)
    }

    func testIncrementalUpdateOmissionRemovesRowsLikeOriginalRemoteGUI() throws {
        var store = ECDownloadStateStore()
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(ECDownloadPacketFixtures.snapshotPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "active.iso"),
        ])))

        let emptyUpdate = ECDownloadPacketFixtures.incrementalPacket(downloads: [])
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(emptyUpdate), sourcePacket: emptyUpdate)

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

    func testSparseProgressStatusUpdateRefreshesExistingProgressColorsWithoutStatusTag() throws {
        var store = ECDownloadStateStore()
        let partSize: UInt64 = 9_728_000
        let fullPacket = ECDownloadPacketFixtures.snapshotPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "active.iso", size: partSize * 2, done: 0, statusCode: 0),
        ])
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(fullPacket), sourcePacket: fullPacket)
        XCTAssertEqual(store.downloads.first?.progressColors, [])

        let sparseProgressTag = ECTag.integer(name: 0x0300, value: UInt64(42), children: [
            ECTag.integer(name: 0x0303, value: partSize * 2),
            ECTag(name: 0x0313, type: .custom, value: .custom(rleEncodedUInt64s([0, partSize]))),
            ECTag(name: 0x0314, type: .custom, value: .custom(rleEncodedUInt64s([partSize, partSize * 2]))),
        ])
        let sparsePacket = ECDownloadPacketFixtures.incrementalPacket(downloads: [sparseProgressTag])
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(sparsePacket), sourcePacket: sparsePacket)

        let colors = try XCTUnwrap(store.downloads.first?.progressColors)
        XCTAssertEqual(colors.count, 64)
        guard colors.count == 64 else { return }
        XCTAssertEqual(colors[0], Self.packedColor(r: 255, g: 0, b: 0))
        XCTAssertEqual(colors[32], Self.packedColor(r: 255, g: 208, b: 0))
        XCTAssertEqual(store.downloads.first?.statusCode, 0)
        XCTAssertEqual(store.downloads.first?.status, "Waiting")
    }

    func testApplyIncrementalUpdateMergesProgressStatusLikeOriginalPartFileUpdate() throws {
        var store = ECDownloadStateStore()
        let partSize: UInt64 = 9_728_000
        let fullPacket = ECDownloadPacketFixtures.snapshotPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "active.iso", size: partSize * 2, done: 0, statusCode: 0),
        ])
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(fullPacket), sourcePacket: fullPacket)
        XCTAssertEqual(store.downloads.first?.progressColors, [])

        store.applyIncrementalUpdate(ECDownloadPacketFixtures.incrementalPacket(downloads: [
            ECTag.integer(name: 0x0300, value: UInt64(42), children: [
                ECTag.integer(name: 0x0303, value: partSize * 2),
                ECTag(name: 0x0313, type: .custom, value: .custom(rleEncodedUInt64s([0, partSize]))),
                ECTag(name: 0x0314, type: .custom, value: .custom(rleEncodedUInt64s([partSize, partSize * 2]))),
            ]),
        ]))

        let colors = try XCTUnwrap(store.downloads.first?.progressColors)
        XCTAssertEqual(colors.count, 64)
        guard colors.count == 64 else { return }
        XCTAssertEqual(colors[0], Self.packedColor(r: 255, g: 0, b: 0))
        XCTAssertEqual(colors[32], Self.packedColor(r: 255, g: 208, b: 0))
    }

    func testIncrementalProgressRLEUsesPreviousPerFileStateLikeOriginalClient() throws {
        var store = ECDownloadStateStore()
        let partSize: UInt64 = 9_728_000
        let fullPacket = ECDownloadPacketFixtures.snapshotPacket(downloads: [
            ECTag.integer(name: 0x0300, value: UInt64(42), children: [
                ECTag(name: 0x0301, type: .string, value: .string("active.iso")),
                ECTag.integer(name: 0x0303, value: partSize * 2),
                ECTag.integer(name: 0x0306, value: 0),
                ECTag.integer(name: 0x0308, value: 0),
                ECTag(name: 0x031E, type: .hash16, value: .hash16(Self.hashData(Self.hash))),
                ECTag(name: 0x0313, type: .custom, value: .custom(rleEncodedUInt64s([0, partSize]))),
                ECTag(name: 0x0312, type: .custom, value: .custom(rleEncodedBytes([1, 0]))),
            ]),
        ])
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(fullPacket), sourcePacket: fullPacket)
        XCTAssertEqual(store.downloads.first?.progressColors.first, Self.packedColor(r: 0, g: 210, b: 255))

        store.applyIncrementalUpdate(ECDownloadPacketFixtures.incrementalPacket(downloads: [
            ECTag.integer(name: 0x0300, value: UInt64(42), children: [
                ECTag.integer(name: 0x0303, value: partSize * 2),
                ECTag(name: 0x0312, type: .custom, value: .custom(rleEncodedBytes([1 ^ 2, 0 ^ 0]))),
            ]),
        ]))

        let colors = try XCTUnwrap(store.downloads.first?.progressColors)
        XCTAssertEqual(colors.count, 64)
        XCTAssertEqual(colors.first, Self.packedColor(r: 0, g: 188, b: 255))
        XCTAssertEqual(colors[32], Self.packedColor(r: 104, g: 104, b: 104))
    }

    func testSparsePartFileUpdateMergesScalarFieldsWithoutStatusTag() throws {
        var store = ECDownloadStateStore()
        let fullPacket = ECDownloadPacketFixtures.snapshotPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "active.iso", size: 1_000, done: 100, statusCode: 0),
        ])
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(fullPacket), sourcePacket: fullPacket)

        let sparseScalarTag = ECTag.integer(name: 0x0300, value: UInt64(42), children: [
            ECTag.integer(name: 0x0303, value: 1_000),
            ECTag.integer(name: 0x0304, value: 700),
            ECTag.integer(name: 0x0306, value: 650),
            ECTag.integer(name: 0x0307, value: 12_345),
            ECTag.integer(name: 0x030A, value: 9),
            ECTag.integer(name: 0x030B, value: 2),
            ECTag.integer(name: 0x030C, value: 4),
            ECTag.integer(name: 0x030D, value: 3),
            ECTag.integer(name: 0x030F, value: 4),
            ECTag.integer(name: 0x0310, value: 111),
            ECTag.integer(name: 0x0311, value: 222),
            ECTag.integer(name: 0x031D, value: 12),
        ])
        let sparsePacket = ECDownloadPacketFixtures.incrementalPacket(downloads: [sparseScalarTag])
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(sparsePacket), sourcePacket: sparsePacket)

        let download = try XCTUnwrap(store.downloads.first)
        XCTAssertEqual(download.done, 650)
        XCTAssertEqual(download.transferred, 700)
        XCTAssertEqual(download.progress, 65)
        XCTAssertEqual(download.speed, 12_345)
        XCTAssertEqual(download.sourcesCurrent, 5)
        XCTAssertEqual(download.sourcesTotal, 9)
        XCTAssertEqual(download.sourcesTransferring, 3)
        XCTAssertEqual(download.sourcesA4AF, 2)
        XCTAssertEqual(download.statusCode, 0)
        XCTAssertEqual(download.status, "Downloading")
        XCTAssertEqual(download.category, 4)
        XCTAssertEqual(download.lastReceived, 111)
        XCTAssertEqual(download.lastSeenComplete, 222)
        XCTAssertEqual(download.availableParts, 12)
    }

    func testIncrementalStatusOnlyUpdatePreservesExistingIdentityLikeAmulegui() throws {
        var store = ECDownloadStateStore()
        let fullPacket = ECDownloadPacketFixtures.snapshotPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "active.iso", size: 1_000, done: 100, statusCode: 0),
        ])
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(fullPacket), sourcePacket: fullPacket)

        let statusOnlyPacket = ECDownloadPacketFixtures.incrementalPacket(downloads: [
            ECTag.integer(name: 0x0300, value: UInt64(42), children: [
                ECTag.integer(name: 0x0308, value: 7),
            ]),
        ])
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(statusOnlyPacket), sourcePacket: statusOnlyPacket)

        let download = try XCTUnwrap(store.downloads.first)
        XCTAssertEqual(download.name, "active.iso")
        XCTAssertEqual(download.hash, Self.hash)
        XCTAssertEqual(download.size, 1_000)
        XCTAssertEqual(download.statusCode, 7)
        XCTAssertEqual(download.status, "Paused")
    }

    func testPartFileCompleteStatusReconcilesCompletingPartFileToComplete() throws {
        var store = ECDownloadStateStore()
        let completingPacket = ECDownloadPacketFixtures.snapshotPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "finishing.iso", size: 100, done: 100, statusCode: 8),
        ])
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(completingPacket), sourcePacket: completingPacket)
        XCTAssertEqual(store.downloads.first?.status, "Completing")

        let completedPacket = ECDownloadPacketFixtures.incrementalPacket(downloads: [
            try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "finished.iso", size: 100, done: 100, statusCode: 9),
        ])
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(completedPacket), sourcePacket: completedPacket)

        let download = try XCTUnwrap(store.downloads.first)
        XCTAssertEqual(download.ecid, 42)
        XCTAssertEqual(download.name, "finished.iso")
        XCTAssertEqual(download.statusCode, 9)
        XCTAssertEqual(download.status, "Complete")
        XCTAssertTrue(download.isCompleted)
        XCTAssertEqual(download.done, 100)
        XCTAssertEqual(download.progress, 100)
    }

    func testKnownFileSnapshotDoesNotPromoteUnknownSharedFileToDownload() throws {
        var store = ECDownloadStateStore()
        let knownFilePacket = ECDownloadPacketFixtures.incrementalPacket(downloads: [
            try ECDownloadPacketFixtures.knownFile(ecid: 52, hash: Self.otherHash, name: "/Shared/shared.iso", size: 100),
        ])

        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(knownFilePacket), sourcePacket: knownFilePacket)

        XCTAssertEqual(store.downloads, [])
        XCTAssertEqual(store.lifecycle(forECID: 52), nil)
    }

    func testSparseKnownFileUpdateDoesNotRequestDownloadResync() throws {
        var store = ECDownloadStateStore()
        store.replaceDownloadSnapshot([
            Self.download(ecid: 42, hash: Self.hash, name: "active.iso"),
        ])

        let knownFileOnlyPacket = ECDownloadPacketFixtures.incrementalPacket(downloads: [
            ECTag.integer(name: 0x0400, value: 99),
        ])

        XCTAssertFalse(store.incrementalUpdateNeedsFullResync(knownFileOnlyPacket))
    }

    func testUnknownSparsePartFileWithoutStatusRequestsFullResync() throws {
        var store = ECDownloadStateStore()
        store.replaceDownloadSnapshot([
            Self.download(ecid: 42, hash: Self.hash, name: "active.iso"),
        ])

        let sparseUnknownPartFile = ECDownloadPacketFixtures.incrementalPacket(downloads: [
            try ECDownloadPacketFixtures.sparsePartFile(ecid: 99, hash: Self.otherHash, name: "unknown.iso"),
        ])

        XCTAssertTrue(store.incrementalUpdateNeedsFullResync(sparseUnknownPartFile))
    }

    func testIncrementalUpdateOmissionRemovesPreviouslyCompletedDownload() throws {
        var store = ECDownloadStateStore()
        store.replaceDownloadSnapshot([Self.download(ecid: 43, hash: Self.hash, name: "done.iso", completed: true)])

        let knownFilePacket = ECDownloadPacketFixtures.incrementalPacket(downloads: [
            try ECDownloadPacketFixtures.knownFile(ecid: 99, hash: Self.otherHash, name: "/Shared/done.iso", size: 100),
        ])
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(knownFilePacket), sourcePacket: knownFilePacket)

        XCTAssertEqual(store.downloads, [])
        XCTAssertEqual(store.lifecycle(forECID: 43), .tombstoned)
    }

    func testCompletedPartFileShapeWithNoSourcesUsesCompletedRetainedLifecycle() throws {
        var store = ECDownloadStateStore()
        let packet = ECDownloadPacketFixtures.snapshotPacket(downloads: [
            ECTag(name: 0x0300, type: .string, value: .string("not-an-ecid")),
        ])

        store.replaceDownloadSnapshot([Self.download(ecid: 44, hash: Self.thirdHash, name: "done-no-sources.iso", completed: true, withoutPartMetAndSources: true)], sourcePacket: packet)

        XCTAssertEqual(store.downloads.map(\.ecid), [44])
        XCTAssertEqual(store.lifecycle(forECID: 44), .completedRetained)
        XCTAssertEqual(store.lifecycle(forECID: 0), .malformedOmission)
    }

    private static let hash = "00112233445566778899aabbccddeeff"
    private static let otherHash = "ffeeddccbbaa99887766554433221100"
    private static let thirdHash = "11112222333344445555666677778888"

    private static func packedColor(r: Int, g: Int, b: Int) -> UInt32 {
        (UInt32(b & 0xff) << 16) | (UInt32(g & 0xff) << 8) | UInt32(r & 0xff)
    }

    private static func hashData(_ hex: String) -> Data {
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            data.append(UInt8(hex[index..<next], radix: 16) ?? 0)
            index = next
        }
        return data
    }

    private func rleEncodedUInt64s(_ values: [UInt64]) -> Data {
        var bytes = [UInt8](repeating: 0, count: values.count * 8)
        for (index, value) in values.enumerated() {
            var remaining = value
            for byteIndex in 0..<8 {
                bytes[index + byteIndex * values.count] = UInt8(remaining & 0xff)
                remaining >>= 8
            }
        }
        return rleEncodedBytes(bytes)
    }

    private func rleEncodedBytes(_ bytes: [UInt8]) -> Data {
        var encoded: [UInt8] = []
        var index = 0
        while index < bytes.count {
            let value = bytes[index]
            var runLength = 1
            while index + runLength < bytes.count, bytes[index + runLength] == value, runLength < 0xff {
                runLength += 1
            }
            if runLength > 1 {
                encoded.append(value)
                encoded.append(value)
                encoded.append(UInt8(runLength))
            } else {
                encoded.append(value)
            }
            index += runLength
        }
        return Data(encoded)
    }

    private static func download(ecid: Int, hash: String, name: String, completed: Bool = false, withoutPartMetAndSources: Bool = false) -> ECDownload {
        ECDownload(
            ecid: ecid,
            hash: hash,
            name: name,
            size: 100,
            done: completed ? 100 : 10,
            transferred: completed ? 100 : 10,
            progress: completed ? 100 : 10,
            sourcesCurrent: withoutPartMetAndSources ? 0 : 1,
            sourcesTotal: withoutPartMetAndSources ? 0 : 1,
            sourcesTransferring: 0,
            sourcesA4AF: 0,
            statusCode: completed ? 9 : 7,
            isCompleted: completed,
            status: completed ? "Completed" : "Waiting",
            speed: 0,
            priority: 0,
            category: 0,
            partMet: withoutPartMetAndSources ? "" : "001.part.met",
            lastSeenComplete: 0,
            lastReceived: 0,
            activeSeconds: 0,
            availableParts: 0,
            shared: false
        )
    }
}
