import Foundation

public enum ECAuthPacket {
    public static let opAuthReq: UInt8 = 0x02
    public static let opAuthSalt: UInt8 = 0x4f
    public static let opAuthOK: UInt8 = 0x04
    public static let opFailed: UInt8 = 0x05
    public static let opAuthPassword: UInt8 = 0x50

    public static let baseFlags: UInt32 = 0x0000_0020
    public static let nativeBridgeFlags: UInt32 = baseFlags | ECPacket.utf8NumbersFlag

    public static let tagString: UInt16 = 0x0000
    public static let tagPasswordHash: UInt16 = 0x0001
    public static let tagProtocolVersion: UInt16 = 0x0002
    public static let tagPasswordSalt: UInt16 = 0x000b
    public static let tagCanZlib: UInt16 = 0x000c
    public static let tagCanUTF8Numbers: UInt16 = 0x000d
    public static let tagCanNotify: UInt16 = 0x000e
    public static let tagClientName: UInt16 = 0x0100
    public static let tagClientVersion: UInt16 = 0x0101
    public static let tagServerVersion: UInt16 = 0x050b

    public static let currentProtocolVersion: UInt64 = 0x0204

    public static func authRequest(
        clientName: String,
        version: String,
        protocolVersion: UInt64 = currentProtocolVersion,
        canZlib: Bool = false,
        canUTF8Numbers: Bool = false,
        canNotify: Bool = false,
        flags: UInt32 = baseFlags
    ) -> ECPacket {
        var tags = [
            ECTag(name: tagClientName, type: .string, value: .string(clientName)),
            ECTag(name: tagClientVersion, type: .string, value: .string(version)),
            ECTag.integer(name: tagProtocolVersion, value: protocolVersion),
        ]
        if canZlib {
            tags.append(ECTag(name: tagCanZlib, type: .unknown))
        }
        if canUTF8Numbers {
            tags.append(ECTag(name: tagCanUTF8Numbers, type: .unknown))
        }
        if canNotify {
            tags.append(ECTag(name: tagCanNotify, type: .unknown))
        }

        return ECPacket(
            flags: flags,
            opcode: opAuthReq,
            tags: tags
        )
    }

    public static func authPassword(hashHex: String, flags: UInt32 = baseFlags) throws -> ECPacket {
        ECPacket(
            flags: flags,
            opcode: opAuthPassword,
            tags: [
                ECTag(name: tagPasswordHash, type: .hash16, value: .hash16(try ECLegacyAuth.bytes(fromMD5Hex: hashHex))),
            ]
        )
    }

    public static func authPassword(password: String, salt: UInt64, flags: UInt32 = baseFlags) throws -> ECPacket {
        try authPassword(hashHex: ECLegacyAuth.responseHashHex(password: password, salt: salt), flags: flags)
    }
}
