import XCTest
import Foundation
import AMuleECProtocol
import Fixtures
@testable import AMuleECClient

final class ECResponseParserTests: XCTestCase {
    func testBlankNameKnownFileWithExplicitCompletionStatusCurrentBaseline() throws {
        let packet = ECPacket(opcode: 0x1F, tags: [
            try Self.knownFile(ecid: 99, hashData: Self.testHashData, name: "", size: 128, done: 128, explicitStatus: 9),
        ])

        let downloads = try ECResponseParser.parseDownloads(packet)

        XCTAssertEqual(downloads.map(\.ecid), [99])
        XCTAssertEqual(downloads.map(\.name), [""])
        XCTAssertTrue(downloads.allSatisfy(\.isCompleted))
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

    private static let testHashData = Data([
        0x00, 0x11, 0x22, 0x33,
        0x44, 0x55, 0x66, 0x77,
        0x88, 0x99, 0xAA, 0xBB,
        0xCC, 0xDD, 0xEE, 0xFF,
    ])

    private static func knownFile(ecid: Int, hashData: Data, name: String, size: UInt64, done: UInt64, explicitStatus: Int) throws -> ECTag {
        let children = [
            ECTag.integer(name: 0x000F, value: UInt64(ecid)),
            ECTag(name: 0x0301, type: .string, value: .string(name)),
            ECTag.integer(name: 0x0303, value: size),
            ECTag.integer(name: 0x0306, value: done),
            ECTag.integer(name: 0x0308, value: UInt64(explicitStatus)),
            ECTag(name: 0x031E, type: .hash16, value: .hash16(hashData)),
        ]
        return ECTag.integer(name: 0x0400, value: UInt64(ecid), children: children)
    }
}
