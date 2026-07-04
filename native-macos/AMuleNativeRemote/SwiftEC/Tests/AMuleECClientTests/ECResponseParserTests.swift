import XCTest
import Foundation
import AMuleECProtocol
import Fixtures
@testable import AMuleECClient

final class ECResponseParserTests: XCTestCase {
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

}
