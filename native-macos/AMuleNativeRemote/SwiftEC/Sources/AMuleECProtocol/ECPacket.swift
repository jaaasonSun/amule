import Foundation

public struct ECPacket: Equatable, Sendable {
    public static let protocolBaseFlags: UInt32 = 0x0000_0020
    public static let utf8NumbersFlag: UInt32 = 0x0000_0002
    public static let requiredProtocolFlagMask: UInt32 = 0x0000_0060
    public static let requiredProtocolFlagValue: UInt32 = protocolBaseFlags
    public static let unknownFlagMask: UInt32 = 0xff7f_7f08

    public let flags: UInt32
    public let opcode: UInt8
    public var tags: [ECTag]

    public init(flags: UInt32 = Self.protocolBaseFlags, opcode: UInt8, tags: [ECTag] = []) {
        self.flags = flags
        self.opcode = opcode
        self.tags = tags
    }

    public func encodeBody(utf8Numbers: Bool = false) throws -> Data {
        guard tags.count <= Int(UInt16.max) else {
            throw ECProtocolError.invalidLength(field: "packet tag count", expected: Int(UInt16.max), actual: tags.count)
        }

        var data = Data()
        data.ecAppendNumber(opcode, utf8Numbers: utf8Numbers)
        data.ecAppendNumber(UInt16(tags.count), utf8Numbers: utf8Numbers)
        for tag in tags {
            data.append(try tag.encode(utf8Numbers: utf8Numbers))
        }
        return data
    }

    public func encode() throws -> Data {
        try encode(compressionEnabled: false)
    }

    public func encode(compressionEnabled: Bool, compressionThreshold: Int = ECCompression.threshold) throws -> Data {
        let body = try encodeBody(utf8Numbers: (flags & Self.utf8NumbersFlag) != 0)
        let shouldCompress = compressionEnabled && body.count > compressionThreshold
        let payload: Data
        let headerFlags: UInt32

        if shouldCompress {
            payload = try ECCompression.compress(body)
            headerFlags = flags | ECCompression.flag
        } else {
            payload = body
            headerFlags = flags & ~ECCompression.flag
        }

        guard payload.count <= Int(UInt32.max) else {
            throw ECProtocolError.invalidLength(field: "packet body", expected: Int(UInt32.max), actual: payload.count)
        }

        let header = ECPacketHeader(flags: headerFlags, bodyLength: UInt32(payload.count))
        var data = header.encode()
        data.append(payload)
        return data
    }

    public func compressedBody(compressionThreshold: Int = ECCompression.threshold) throws -> Data? {
        let body = try encodeBody(utf8Numbers: (flags & Self.utf8NumbersFlag) != 0)
        guard body.count > compressionThreshold else { return nil }
        return try ECCompression.compress(body)
    }

    public static func decodeCompressedBody(_ data: Data, flags: UInt32) throws -> ECPacket {
        try decodeBody(ECCompression.decompress(data), flags: flags)
    }

    public func encodeUncompressed() throws -> Data {
        let body = try encodeBody(utf8Numbers: (flags & Self.utf8NumbersFlag) != 0)
        guard body.count <= Int(UInt32.max) else {
            throw ECProtocolError.invalidLength(field: "packet body", expected: Int(UInt32.max), actual: body.count)
        }

        let header = ECPacketHeader(flags: flags & ~ECCompression.flag, bodyLength: UInt32(body.count))
        var data = header.encode()
        data.append(body)
        return data
    }

    public static func decodeBody(_ data: Data, flags: UInt32 = 0) throws -> ECPacket {
        var cursor = ECByteCursor(data, utf8Numbers: (flags & Self.utf8NumbersFlag) != 0)
        let opcode = try cursor.readUInt8()
        let count = Int(try cursor.readUInt16())
        var tags: [ECTag] = []
        tags.reserveCapacity(count)
        for _ in 0..<count {
            tags.append(try ECTag.decode(from: &cursor))
        }
        guard cursor.isAtEnd else { throw ECProtocolError.invalidPacketBody }
        return ECPacket(flags: flags, opcode: opcode, tags: tags)
    }

    public static func decode(_ data: Data) throws -> ECPacket {
        guard data.count >= ECPacketHeader.byteCount else {
            throw ECProtocolError.malformedHeader(expected: ECPacketHeader.byteCount, actual: data.count)
        }

        let header = try ECPacketHeader.decode(data.prefix(ECPacketHeader.byteCount))
        try validateHeaderFlags(header.flags)
        let body = data.dropFirst(ECPacketHeader.byteCount)
        guard body.count == Int(header.bodyLength) else {
            throw ECProtocolError.invalidLength(field: "packet body", expected: Int(header.bodyLength), actual: body.count)
        }

        if (header.flags & ECCompression.flag) != 0 {
            return try decodeCompressedBody(Data(body), flags: header.flags)
        }
        return try decodeBody(Data(body), flags: header.flags)
    }

    private static func validateHeaderFlags(_ flags: UInt32) throws {
        guard (flags & requiredProtocolFlagMask) == requiredProtocolFlagValue,
              (flags & unknownFlagMask) == 0 else {
            throw ECProtocolError.invalidPacketFlags(flags)
        }
    }
}
