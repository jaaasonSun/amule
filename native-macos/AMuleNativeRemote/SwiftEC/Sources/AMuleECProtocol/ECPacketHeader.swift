import Foundation

public struct ECPacketHeader: Equatable, Sendable {
    public static let byteCount = 8

    public let flags: UInt32
    public let bodyLength: UInt32

    public init(flags: UInt32 = 0, bodyLength: UInt32) {
        self.flags = flags
        self.bodyLength = bodyLength
    }

    public func encode() -> Data {
        var data = Data(capacity: Self.byteCount)
        data.ecAppendUInt32(flags)
        data.ecAppendUInt32(bodyLength)
        return data
    }

    public static func decode(_ data: Data) throws -> ECPacketHeader {
        guard data.count == Self.byteCount else {
            throw ECProtocolError.malformedHeader(expected: Self.byteCount, actual: data.count)
        }

        var cursor = ECByteCursor(data)
        return ECPacketHeader(flags: try cursor.readUInt32(), bodyLength: try cursor.readUInt32())
    }
}

extension Data {
    mutating func ecAppendUInt8(_ value: UInt8) {
        append(value)
    }

    mutating func ecAppendNumber(_ value: UInt32, utf8Numbers: Bool) {
        if utf8Numbers {
            ecAppendUTF8Number(value)
        } else {
            ecAppendUInt32(value)
        }
    }

    mutating func ecAppendNumber(_ value: UInt16, utf8Numbers: Bool) {
        if utf8Numbers {
            ecAppendUTF8Number(UInt32(value))
        } else {
            ecAppendUInt16(value)
        }
    }

    mutating func ecAppendNumber(_ value: UInt8, utf8Numbers: Bool) {
        if utf8Numbers {
            ecAppendUTF8Number(UInt32(value))
        } else {
            ecAppendUInt8(value)
        }
    }

    mutating func ecAppendUInt16(_ value: UInt16) {
        append(UInt8((value >> 8) & 0xff))
        append(UInt8(value & 0xff))
    }

    mutating func ecAppendUInt32(_ value: UInt32) {
        append(UInt8((value >> 24) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8(value & 0xff))
    }

    mutating func ecAppendUInt64(_ value: UInt64) {
        append(UInt8((value >> 56) & 0xff))
        append(UInt8((value >> 48) & 0xff))
        append(UInt8((value >> 40) & 0xff))
        append(UInt8((value >> 32) & 0xff))
        append(UInt8((value >> 24) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8(value & 0xff))
    }

    private mutating func ecAppendUTF8Number(_ value: UInt32) {
        guard let scalar = UnicodeScalar(value) else { return }
        append(contentsOf: String(scalar).utf8)
    }
}

struct ECByteCursor {
    private let bytes: [UInt8]
    private let utf8Numbers: Bool
    private(set) var offset: Int = 0

    init(_ data: Data, utf8Numbers: Bool = false) {
        bytes = Array(data)
        self.utf8Numbers = utf8Numbers
    }

    var remaining: Int {
        bytes.count - offset
    }

    var isAtEnd: Bool {
        remaining == 0
    }

    mutating func readUInt8() throws -> UInt8 {
        if utf8Numbers {
            let value = try readUTF8Number()
            guard value <= UInt32(UInt8.max) else {
                throw ECProtocolError.invalidLength(field: "UTF-8 uint8", expected: Int(UInt8.max), actual: Int(value))
            }
            return UInt8(value)
        }
        try require(1)
        defer { offset += 1 }
        return bytes[offset]
    }

    mutating func readUInt16() throws -> UInt16 {
        if utf8Numbers {
            let value = try readUTF8Number()
            guard value <= UInt32(UInt16.max) else {
                throw ECProtocolError.invalidLength(field: "UTF-8 uint16", expected: Int(UInt16.max), actual: Int(value))
            }
            return UInt16(value)
        }
        let chunk = try readBytes(count: 2)
        return (UInt16(chunk[0]) << 8) | UInt16(chunk[1])
    }

    mutating func readUInt32() throws -> UInt32 {
        if utf8Numbers {
            return try readUTF8Number()
        }
        let chunk = try readBytes(count: 4)
        return (UInt32(chunk[0]) << 24) | (UInt32(chunk[1]) << 16) | (UInt32(chunk[2]) << 8) | UInt32(chunk[3])
    }

    mutating func readUInt64() throws -> UInt64 {
        let chunk = try readBytes(count: 8)
        return chunk.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
    }

    mutating func readBytes(count: Int) throws -> [UInt8] {
        try require(count)
        let end = offset + count
        defer { offset = end }
        return Array(bytes[offset..<end])
    }

    private func require(_ count: Int) throws {
        guard remaining >= count else {
            throw ECProtocolError.truncatedData(needed: count, available: remaining)
        }
    }

    private mutating func readUTF8Number() throws -> UInt32 {
        let first = try readFixedByte()
        let count: Int
        if first & 0x80 == 0 {
            return UInt32(first)
        } else if first & 0xE0 == 0xC0 {
            count = 2
        } else if first & 0xF0 == 0xE0 {
            count = 3
        } else if first & 0xF8 == 0xF0 {
            count = 4
        } else if first & 0xFC == 0xF8 {
            count = 5
        } else if first & 0xFE == 0xFC {
            count = 6
        } else {
            throw ECProtocolError.invalidStringData
        }

        var scalarBytes = [first]
        for _ in 1..<count {
            let byte = try readFixedByte()
            guard byte & 0xC0 == 0x80 else { throw ECProtocolError.invalidStringData }
            scalarBytes.append(byte)
        }

        guard let string = String(bytes: scalarBytes, encoding: .utf8),
              let scalar = string.unicodeScalars.first,
              string.unicodeScalars.count == 1 else {
            throw ECProtocolError.invalidStringData
        }
        return scalar.value
    }

    private mutating func readFixedByte() throws -> UInt8 {
        try require(1)
        defer { offset += 1 }
        return bytes[offset]
    }
}
