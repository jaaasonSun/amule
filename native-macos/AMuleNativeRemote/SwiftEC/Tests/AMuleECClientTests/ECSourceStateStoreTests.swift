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
                    ECTag(name: 0x0610, type: .ipv4, value: .ipv4(ECIPv4Address(5, 6, 7, 8, port: 0))),
                    .integer(name: 0x0611, value: 4662),
                    .integer(name: 0x060C, value: 2),
                    ECTag(name: 0x060E, type: .double, value: .double(1.5)),
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
    }

    func testClientWithoutChildrenRemovesCachedSource() {
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

        XCTAssertEqual(store.sources(for: 42), [])
    }

    private static func client(id: Int, children: [ECTag]) -> ECTag {
        ECTag.integer(name: 0x0600, value: UInt64(id), children: children)
    }
}
