import Foundation
import AMuleECProtocol

public enum ECDownloadPacketFixtures {
    public static let defaultHash = "00112233445566778899aabbccddeeff"

    public static func snapshotPacket(downloads: [ECTag]) -> ECPacket {
        ECPacket(opcode: 0x1F, tags: downloads)
    }

    public static func incrementalPacket(downloads: [ECTag]) -> ECPacket {
        ECPacket(opcode: 0x22, tags: downloads)
    }

    public static func partFile(
        ecid: Int,
        hash: String,
        name: String,
        size: UInt64 = 100,
        done: UInt64 = 10,
        statusCode: Int = 7,
        sourceNameEntries: [ECTag] = []
    ) throws -> ECTag {
        let hashData = try hashData(from: hash)
        var children = [
            ECTag(name: 0x0301, type: .string, value: .string(name)),
            ECTag.integer(name: 0x0303, value: size),
            ECTag.integer(name: 0x0306, value: done),
            ECTag.integer(name: 0x0308, value: UInt64(statusCode)),
            ECTag(name: 0x031E, type: .hash16, value: .hash16(hashData)),
        ]
        if !sourceNameEntries.isEmpty {
            children.append(ECTag(name: 0x0315, type: .unknown, children: sourceNameEntries))
        }
        return ECTag.integer(name: 0x0300, value: UInt64(ecid), children: children)
    }

    public static func sparsePartFile(
        ecid: Int,
        hash: String,
        name: String,
        size: UInt64 = 100
    ) throws -> ECTag {
        let hashData = try hashData(from: hash)
        return ECTag.integer(name: 0x0300, value: UInt64(ecid), children: [
            ECTag(name: 0x0301, type: .string, value: .string(name)),
            ECTag.integer(name: 0x0303, value: size),
            ECTag(name: 0x031E, type: .hash16, value: .hash16(hashData)),
        ])
    }

    public static func knownFile(ecid: Int, hash: String, name: String, size: UInt64 = 100) throws -> ECTag {
        let hashData = try hashData(from: hash)
        return ECTag.integer(name: 0x0400, value: UInt64(ecid), children: [
            ECTag(name: 0x0301, type: .string, value: .string(name)),
            ECTag.integer(name: 0x0303, value: size),
            ECTag(name: 0x031E, type: .hash16, value: .hash16(hashData)),
        ])
    }

    public static func sourceNameEntry(id: Int, name: String?, count: Int) -> ECTag {
        var children = [ECTag.integer(name: 0x031C, value: UInt64(count))]
        if let name {
            children.append(ECTag(name: 0x0315, type: .string, value: .string(name)))
        }
        return ECTag.integer(name: 0x0315, value: UInt64(id), children: children)
    }

    public static func client(id: Int, children: [ECTag]) -> ECTag {
        ECTag.integer(name: 0x0600, value: UInt64(id), children: children)
    }

    public static func friendContainer(_ friends: [ECTag]) -> ECTag {
        ECTag(name: 0x0800, type: .unknown, children: friends)
    }

    public static func friend(id: Int, name: String, hash: String, ip: UInt64, port: Int, clientID: Int) throws -> ECTag {
        let hashData = try hashData(from: hash)
        return ECTag.integer(name: 0x0800, value: UInt64(id), children: [
            ECTag(name: 0x0801, type: .string, value: .string(name)),
            ECTag(name: 0x0802, type: .hash16, value: .hash16(hashData)),
            ECTag.integer(name: 0x0803, value: ip),
            ECTag.integer(name: 0x0804, value: UInt64(port)),
            ECTag.integer(name: 0x0805, value: UInt64(clientID)),
        ])
    }

    private static func hashData(from hash: String) throws -> Data {
        guard let data = Data(hex: hash) else {
            throw FixtureError.invalidHex(hash)
        }
        return data
    }

    private enum FixtureError: Error {
        case invalidHex(String)
    }
}

private extension Data {
    init?(hex: String) {
        self.init()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            append(byte)
            index = next
        }
    }
}
