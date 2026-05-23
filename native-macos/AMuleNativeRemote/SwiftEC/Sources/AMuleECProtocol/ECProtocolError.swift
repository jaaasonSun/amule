import Foundation

public enum ECProtocolError: Error, Equatable, CustomStringConvertible, LocalizedError {
    case malformedHeader(expected: Int, actual: Int)
    case invalidLength(field: String, expected: Int, actual: Int)
    case truncatedData(needed: Int, available: Int)
    case unknownTagType(UInt8)
    case invalidTagData(type: UInt8, length: Int)
    case invalidStringData
    case invalidPacketBody
    case invalidPacketFlags(UInt32)
    case compressionFailed(operation: String)
    case decompressionLimitExceeded(limit: Int)

    public var description: String {
        switch self {
        case let .malformedHeader(expected, actual):
            return "Malformed EC packet header: expected \(expected) bytes, got \(actual)."
        case let .invalidLength(field, expected, actual):
            return "Invalid EC \(field) length: expected \(expected), got \(actual)."
        case let .truncatedData(needed, available):
            return "Truncated EC data: needed \(needed) bytes, available \(available)."
        case let .unknownTagType(rawValue):
            return "Unknown EC tag type: \(rawValue)."
        case let .invalidTagData(type, length):
            return "Invalid EC tag data for type \(type): length \(length)."
        case .invalidStringData:
            return "Invalid EC string data."
        case .invalidPacketBody:
            return "Invalid EC packet body."
        case let .invalidPacketFlags(flags):
            return "Invalid EC packet flags: 0x\(String(flags, radix: 16))."
        case let .compressionFailed(operation):
            return "EC zlib \(operation) failed."
        case let .decompressionLimitExceeded(limit):
            return "EC zlib inflate exceeded \(limit) bytes."
        }
    }

    public var errorDescription: String? {
        description
    }
}
