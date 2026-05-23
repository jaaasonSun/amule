import Foundation

public enum ECTagType: UInt8, CaseIterable, Equatable, Sendable {
    case unknown = 0
    case custom = 1
    case uint8 = 2
    case uint16 = 3
    case uint32 = 4
    case uint64 = 5
    case string = 6
    case double = 7
    case ipv4 = 8
    case hash16 = 9
    case uint128 = 10
}

public struct ECIPv4Address: Equatable, Sendable {
    public let octets: (UInt8, UInt8, UInt8, UInt8)
    public let port: UInt16

    public init(_ first: UInt8, _ second: UInt8, _ third: UInt8, _ fourth: UInt8, port: UInt16) {
        octets = (first, second, third, fourth)
        self.port = port
    }

    public static func == (lhs: ECIPv4Address, rhs: ECIPv4Address) -> Bool {
        lhs.octets == rhs.octets && lhs.port == rhs.port
    }
}

public enum ECTagValue: Equatable, Sendable {
    case empty
    case custom(Data)
    case uint(UInt64)
    case string(String)
    case double(Double)
    case ipv4(ECIPv4Address)
    case hash16(Data)
    case uint128(Data)
}

public struct ECTag: Equatable, Sendable {
    public let name: UInt16
    public let type: ECTagType
    public let value: ECTagValue
    public var children: [ECTag]

    public init(name: UInt16, type: ECTagType, value: ECTagValue = .empty, children: [ECTag] = []) {
        self.name = name
        self.type = type
        self.value = value
        self.children = children
    }

    public static func integer(name: UInt16, value: UInt64, children: [ECTag] = []) -> ECTag {
        let type: ECTagType
        if value <= UInt64(UInt8.max) {
            type = .uint8
        } else if value <= UInt64(UInt16.max) {
            type = .uint16
        } else if value <= UInt64(UInt32.max) {
            type = .uint32
        } else {
            type = .uint64
        }
        return ECTag(name: name, type: type, value: .uint(value), children: children)
    }

    public func encode(utf8Numbers: Bool = false) throws -> Data {
        let valueBytes = try encodedValueBytes()
        let childBytes = try children.map { try $0.encode(utf8Numbers: utf8Numbers) }
        let childLength = childBytes.reduce(0) { $0 + $1.count }
        let tagLength = valueBytes.count + childLength
        guard tagLength <= Int(UInt32.max) else {
            throw ECProtocolError.invalidLength(field: "tag", expected: Int(UInt32.max), actual: tagLength)
        }
        guard name <= 0x7fff else {
            throw ECProtocolError.invalidLength(field: "tag name", expected: Int(0x7fff), actual: Int(name))
        }
        guard children.count <= Int(UInt16.max) else {
            throw ECProtocolError.invalidLength(field: "child count", expected: Int(UInt16.max), actual: children.count)
        }

        var data = Data(capacity: 7 + (children.isEmpty ? 0 : 2) + tagLength)
        data.ecAppendNumber((name << 1) | (children.isEmpty ? 0 : 1), utf8Numbers: utf8Numbers)
        data.ecAppendNumber(type.rawValue, utf8Numbers: utf8Numbers)
        data.ecAppendNumber(UInt32(tagLength), utf8Numbers: utf8Numbers)
        if !children.isEmpty {
            data.ecAppendNumber(UInt16(children.count), utf8Numbers: utf8Numbers)
            childBytes.forEach { data.append($0) }
        }
        data.append(valueBytes)
        return data
    }

    public static func decode(_ data: Data) throws -> ECTag {
        var cursor = ECByteCursor(data)
        let tag = try decode(from: &cursor)
        guard cursor.isAtEnd else {
            throw ECProtocolError.invalidLength(field: "tag", expected: cursor.offset, actual: data.count)
        }
        return tag
    }

    static func decode(from cursor: inout ECByteCursor) throws -> ECTag {
        let nameAndChildren = try cursor.readUInt16()
        let name = nameAndChildren >> 1
        let hasChildren = (nameAndChildren & 0x0001) != 0
        let rawType = try cursor.readUInt8()
        guard let type = ECTagType(rawValue: rawType) else {
            throw ECProtocolError.unknownTagType(rawType)
        }
        let tagLength = Int(try cursor.readUInt32())

        var children: [ECTag] = []
        var consumedChildBytes = 0
        if hasChildren {
            let count = Int(try cursor.readUInt16())
            for _ in 0..<count {
                let before = cursor.offset
                children.append(try decode(from: &cursor))
                consumedChildBytes += cursor.offset - before
            }
        }

        guard tagLength >= consumedChildBytes else {
            throw ECProtocolError.invalidLength(field: "tag", expected: consumedChildBytes, actual: tagLength)
        }

        let valueBytes = Data(try cursor.readBytes(count: tagLength - consumedChildBytes))
        let value = try decodedValue(type: type, bytes: valueBytes)
        return ECTag(name: name, type: type, value: value, children: children)
    }

    private func encodedValueBytes() throws -> Data {
        var data = Data()
        switch (type, value) {
        case (.unknown, .empty):
            return data
        case (.custom, .custom(let bytes)):
            return bytes
        case (.custom, .empty):
            return data
        case (.uint8, .uint(let value)) where value <= UInt64(UInt8.max):
            data.ecAppendUInt8(UInt8(value))
        case (.uint16, .uint(let value)) where value <= UInt64(UInt16.max):
            data.ecAppendUInt16(UInt16(value))
        case (.uint32, .uint(let value)) where value <= UInt64(UInt32.max):
            data.ecAppendUInt32(UInt32(value))
        case (.uint64, .uint(let value)):
            data.ecAppendUInt64(value)
        case (.string, .string(let value)):
            guard let bytes = value.data(using: .utf8) else { throw ECProtocolError.invalidStringData }
            data.append(bytes)
            data.ecAppendUInt8(0)
        case (.double, .double(let value)):
            guard let bytes = String(value).data(using: .ascii) else { throw ECProtocolError.invalidStringData }
            data.append(bytes)
            data.ecAppendUInt8(0)
        case (.ipv4, .ipv4(let value)):
            data.ecAppendUInt8(value.octets.0)
            data.ecAppendUInt8(value.octets.1)
            data.ecAppendUInt8(value.octets.2)
            data.ecAppendUInt8(value.octets.3)
            data.ecAppendUInt16(value.port)
        case (.hash16, .hash16(let bytes)) where bytes.count == 16:
            data.append(bytes)
        case (.uint128, .uint128(let bytes)) where bytes.count == 16:
            data.append(bytes)
        default:
            throw ECProtocolError.invalidTagData(type: type.rawValue, length: encodedValueLength)
        }
        return data
    }

    private var encodedValueLength: Int {
        switch value {
        case .empty: return 0
        case .custom(let data), .hash16(let data), .uint128(let data): return data.count
        case .uint: return 0
        case .string(let string): return string.utf8.count + 1
        case .double(let double): return String(double).utf8.count + 1
        case .ipv4: return 6
        }
    }

    private static func decodedValue(type: ECTagType, bytes: Data) throws -> ECTagValue {
        var cursor = ECByteCursor(bytes)
        switch type {
        case .unknown:
            guard bytes.isEmpty else { throw ECProtocolError.invalidTagData(type: type.rawValue, length: bytes.count) }
            return .empty
        case .custom:
            return bytes.isEmpty ? .empty : .custom(bytes)
        case .uint8:
            guard bytes.count == 1 else { throw ECProtocolError.invalidTagData(type: type.rawValue, length: bytes.count) }
            return .uint(UInt64(try cursor.readUInt8()))
        case .uint16:
            guard bytes.count == 2 else { throw ECProtocolError.invalidTagData(type: type.rawValue, length: bytes.count) }
            return .uint(UInt64(try cursor.readUInt16()))
        case .uint32:
            guard bytes.count == 4 else { throw ECProtocolError.invalidTagData(type: type.rawValue, length: bytes.count) }
            return .uint(UInt64(try cursor.readUInt32()))
        case .uint64:
            guard bytes.count == 8 else { throw ECProtocolError.invalidTagData(type: type.rawValue, length: bytes.count) }
            return .uint(try cursor.readUInt64())
        case .string:
            return .string(try decodeNullTerminatedString(bytes))
        case .double:
            let text = try decodeNullTerminatedString(bytes)
            guard let value = Double(text) else { throw ECProtocolError.invalidStringData }
            return .double(value)
        case .ipv4:
            guard bytes.count == 6 else { throw ECProtocolError.invalidTagData(type: type.rawValue, length: bytes.count) }
            let octets = try cursor.readBytes(count: 4)
            let port = try cursor.readUInt16()
            return .ipv4(ECIPv4Address(octets[0], octets[1], octets[2], octets[3], port: port))
        case .hash16:
            guard bytes.count == 16 else { throw ECProtocolError.invalidTagData(type: type.rawValue, length: bytes.count) }
            return .hash16(bytes)
        case .uint128:
            guard bytes.count == 16 else { throw ECProtocolError.invalidTagData(type: type.rawValue, length: bytes.count) }
            return .uint128(bytes)
        }
    }

    private static func decodeNullTerminatedString(_ data: Data) throws -> String {
        guard let terminator = data.firstIndex(of: 0) else { throw ECProtocolError.invalidStringData }
        let bytes = data[..<terminator]
        guard let string = String(data: bytes, encoding: .utf8) else { throw ECProtocolError.invalidStringData }
        return string
    }
}
