import XCTest
import Foundation
import AMuleECProtocol
@testable import AMuleECClient

final class ECDownloadStateStoreTests: XCTestCase {
    func testSourceNameDeltasPreserveNamesAcrossCountOnlyUpdates() throws {
        var store = ECDownloadStateStore()
        let snapshot = try ECResponseParser.parseDownloads(ECPacket(opcode: 0x1F, tags: [
            Self.partFile(ecid: 42, hash: Self.hash, name: "current.iso"),
        ]))
        store.replaceDownloadSnapshot(snapshot)

        store.applyIncrementalUpdate(ECPacket(opcode: 0x22, tags: [
            Self.partFile(ecid: 42, hash: Self.hash, name: "current.iso", sourceNameEntries: [
                Self.sourceNameEntry(id: 7, name: "better.iso", count: 3),
            ]),
        ]))
        XCTAssertEqual(store.downloads.first?.alternativeNames, [
            ECDownload.AlternativeName(name: "better.iso", count: 3),
        ])

        store.applyIncrementalUpdate(ECPacket(opcode: 0x22, tags: [
            Self.partFile(ecid: 42, hash: Self.hash, name: "current.iso", sourceNameEntries: [
                Self.sourceNameEntry(id: 7, name: nil, count: 5),
            ]),
        ]))
        XCTAssertEqual(store.downloads.first?.alternativeNames, [
            ECDownload.AlternativeName(name: "better.iso", count: 5),
        ])
    }

    func testSourceNameCountZeroRemovesCachedAlternativeName() throws {
        var store = ECDownloadStateStore()
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(ECPacket(opcode: 0x1F, tags: [
            Self.partFile(ecid: 42, hash: Self.hash, name: "current.iso"),
        ])))
        store.applyIncrementalUpdate(ECPacket(opcode: 0x22, tags: [
            Self.partFile(ecid: 42, hash: Self.hash, name: "current.iso", sourceNameEntries: [
                Self.sourceNameEntry(id: 7, name: "better.iso", count: 3),
            ]),
        ]))
        store.applyIncrementalUpdate(ECPacket(opcode: 0x22, tags: [
            Self.partFile(ecid: 42, hash: Self.hash, name: "current.iso", sourceNameEntries: [
                Self.sourceNameEntry(id: 7, name: nil, count: 0),
            ]),
        ]))

        XCTAssertEqual(store.downloads.first?.alternativeNames, [])
    }

    func testSnapshotKeepsCachedAlternativeNamesAndDropsVanishedFiles() throws {
        var store = ECDownloadStateStore()
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(ECPacket(opcode: 0x1F, tags: [
            Self.partFile(ecid: 42, hash: Self.hash, name: "current.iso"),
        ])))
        store.applyIncrementalUpdate(ECPacket(opcode: 0x22, tags: [
            Self.partFile(ecid: 42, hash: Self.hash, name: "current.iso", sourceNameEntries: [
                Self.sourceNameEntry(id: 7, name: "better.iso", count: 3),
            ]),
        ]))
        store.replaceDownloadSnapshot(try ECResponseParser.parseDownloads(ECPacket(opcode: 0x1F, tags: [
            Self.partFile(ecid: 42, hash: Self.hash, name: "renamed.iso"),
        ])))

        XCTAssertEqual(store.downloads.first?.name, "renamed.iso")
        XCTAssertEqual(store.downloads.first?.alternativeNames, [
            ECDownload.AlternativeName(name: "better.iso", count: 3),
        ])

        store.replaceDownloadSnapshot([])
        XCTAssertEqual(store.downloads, [])
    }

    private static let hash = "00112233445566778899aabbccddeeff"

    private static func partFile(ecid: Int, hash: String, name: String, sourceNameEntries: [ECTag] = []) -> ECTag {
        var children = [
            ECTag(name: 0x0301, type: .string, value: .string(name)),
            ECTag.integer(name: 0x0303, value: 100),
            ECTag.integer(name: 0x0306, value: 10),
            ECTag.integer(name: 0x0308, value: 7),
            ECTag(name: 0x031E, type: .hash16, value: .hash16(Data(hex: hash))),
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
