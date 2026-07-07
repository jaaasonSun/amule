import XCTest
import Foundation
import AMuleECProtocol
import Fixtures
@testable import AMuleECClient

final class ECResponseParserTests: XCTestCase {
    func testSourcesParserUsesRequestContextWhenRequestFileIDIsMissing() throws {
        let packet = ECPacket(opcode: 0x22, tags: [
            Self.client(id: 99, children: [
                ECTag(name: 0x0100, type: .string, value: .string("peer")),
                .integer(name: 0x060C, value: 2),
            ]),
        ])

        let sources = try ECResponseParser.parseSources(packet, requestFileID: 42)

        XCTAssertEqual(sources.map(\.clientID), [99])
        XCTAssertEqual(sources.first?.requestFileID, 42)
    }

    func testSourcesParserCombinesExplicitMatchingAndMissingRequestFileIDs() throws {
        let packet = ECPacket(opcode: 0x22, tags: [
            Self.client(id: 99, children: [
                .integer(name: 0x0620, value: 42),
                ECTag(name: 0x0100, type: .string, value: .string("peer-a")),
            ]),
            Self.client(id: 100, children: [
                ECTag(name: 0x0100, type: .string, value: .string("peer-b")),
            ]),
        ])

        let sources = try ECResponseParser.parseSources(packet, requestFileID: 42)

        XCTAssertEqual(sources.map(\.clientID), [99, 100])
        XCTAssertEqual(sources.map(\.requestFileID), [42, 42])
    }

    func testSourcesParserDoesNotAssignMissingRequestFileIDsWhenPacketContainsOtherFile() throws {
        let packet = ECPacket(opcode: 0x22, tags: [
            Self.client(id: 99, children: [
                ECTag(name: 0x0100, type: .string, value: .string("missing-file-id")),
            ]),
            Self.client(id: 100, children: [
                .integer(name: 0x0620, value: 77),
                ECTag(name: 0x0100, type: .string, value: .string("other-file")),
            ]),
        ])

        let sources = try ECResponseParser.parseSources(packet, requestFileID: 42)

        XCTAssertEqual(sources, [])
    }

    func testStandaloneKnownFileInDownloadsUpdateIsNotADownload() throws {
        let packet = ECDownloadPacketFixtures.incrementalPacket(downloads: [
            try ECDownloadPacketFixtures.knownFile(
                ecid: 42,
                hash: "00112233445566778899aabbccddeeff",
                name: "/Downloads/finished.iso",
                size: 100
            ),
        ])

        let downloads = try ECResponseParser.parseDownloads(packet)

        XCTAssertEqual(downloads, [])
    }

    func testSecondRefreshCompletedRefreshFixturePreservesSparseRowsInCurrentBaseline() throws {
        let downloads = try ECResponseParser.parseDownloads(ECJsonEnvelopeFixtures.TwoRefreshCorruption.refreshTwoPacket)

        XCTAssertEqual(downloads.map(\.name), ["", ECJsonEnvelopeFixtures.TwoRefreshCorruption.unrelatedSharedName, ECJsonEnvelopeFixtures.TwoRefreshCorruption.completedName])
        XCTAssertEqual(downloads.map(\.ecid), [4101, 4102, 4103])
        XCTAssertTrue(downloads.allSatisfy(\.isCompleted))
        XCTAssertTrue(downloads.contains { $0.name.isEmpty })
    }

    func testSecondRefreshCompletedRefreshFixtureRetainsMalformedRowsInCurrentBaseline() throws {
        let downloads = try ECResponseParser.parseDownloads(ECJsonEnvelopeFixtures.TwoRefreshCorruption.refreshTwoPacket)

        XCTAssertTrue(downloads.contains { $0.ecid == 4101 && $0.name.isEmpty })
        XCTAssertTrue(downloads.contains { $0.ecid == 4102 && $0.name == ECJsonEnvelopeFixtures.TwoRefreshCorruption.unrelatedSharedName })
    }

    private static func client(id: Int, children: [ECTag]) -> ECTag {
        ECTag.integer(name: 0x0600, value: UInt64(id), children: children)
    }

}
