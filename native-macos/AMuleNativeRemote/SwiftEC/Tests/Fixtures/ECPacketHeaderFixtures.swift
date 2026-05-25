import Foundation

/// Golden EC packet header fixtures extracted from `src/libs/ec/cpp/ECSocket.cpp`.
///
/// aMule's C++ socket layer writes the 8-byte EC header as two 32-bit network-order
/// values: flags followed by body length. This intentionally records the C++
/// behavior even though older notes sometimes describe these fields as little-endian.
/// Body length excludes the 8-byte header.
public enum ECPacketHeaderFixtures {
    public struct Header: Equatable, Sendable {
        public let name: String
        public let flags: UInt32
        public let bodyLength: UInt32
        public let bytes: [UInt8]
        public let valid: Bool
        public let note: String
    }

    public static let protocolBaseFlag: UInt32 = 0x20
    public static let zlibFlag: UInt32 = 0x01
    public static let utf8NumbersFlag: UInt32 = 0x02
    public static let unknownMask: UInt32 = 0xff7f7f08
    public static let maximumAcceptedBodyLength = 16 * 1024 * 1024

    /// `EC_OP_NOOP` + zero child tags: opcode 0x01, tag count 0x0000.
    public static let noopBody: [UInt8] = [0x01, 0x00, 0x00]

    /// Minimal valid uncompressed header accepted by `ReadPacket`: flags 0x20, body length 3.
    public static let validNoopHeader = Header(
        name: "valid-noop-base-flags",
        flags: protocolBaseFlag,
        bodyLength: UInt32(noopBody.count),
        bytes: [0x00, 0x00, 0x00, 0x20, 0x00, 0x00, 0x00, 0x03],
        valid: true,
        note: "Base protocol marker only; produced when socket capabilities do not include UTF-8 numbers."
    )

    /// Small packets from a capability-enabled `CRemoteConnect` use UTF-8 numbers, not zlib.
    public static let validNoopHeaderWithUTF8Numbers = Header(
        name: "valid-noop-utf8-number-flag",
        flags: protocolBaseFlag | utf8NumbersFlag,
        bodyLength: UInt32(noopBody.count),
        bytes: [0x00, 0x00, 0x00, 0x22, 0x00, 0x00, 0x00, 0x03],
        valid: true,
        note: "Flags from `WritePacket` when `SetCapabilities(... canUTF8numbers: true ...)` is active and body <= 1024 bytes."
    )

    public static let validCompressedHeader = Header(
        name: "valid-zlib-header",
        flags: protocolBaseFlag | zlibFlag,
        bodyLength: 1_337,
        bytes: [0x00, 0x00, 0x00, 0x21, 0x00, 0x00, 0x05, 0x39],
        valid: true,
        note: "Valid zlib packet header shape; fixture does not require compressed payload bytes."
    )

    public static let malformedMissingProtocolMarker = Header(
        name: "malformed-missing-0x20-protocol-marker",
        flags: 0x00,
        bodyLength: UInt32(noopBody.count),
        bytes: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03],
        valid: false,
        note: "Rejected by `ReadPacket` because `(flags & 0x60) != 0x20`."
    )

    public static let malformedUnknownFlagBit = Header(
        name: "malformed-unknown-flag-bit",
        flags: protocolBaseFlag | 0x08,
        bodyLength: UInt32(noopBody.count),
        bytes: [0x00, 0x00, 0x00, 0x28, 0x00, 0x00, 0x00, 0x03],
        valid: false,
        note: "Rejected by `ReadPacket` because bit 0x08 is included in `EC_FLAG_UNKNOWN_MASK`."
    )

    public static let malformedTooLargeBody = Header(
        name: "malformed-body-length-over-16-mib",
        flags: protocolBaseFlag,
        bodyLength: UInt32(maximumAcceptedBodyLength + 1),
        bytes: [0x00, 0x00, 0x00, 0x20, 0x01, 0x00, 0x00, 0x01],
        valid: false,
        note: "Rejected by `ReadHeader` before packet parsing because body length exceeds 16 MiB."
    )

    public static let allHeaders: [Header] = [
        validNoopHeader,
        validNoopHeaderWithUTF8Numbers,
        validCompressedHeader,
        malformedMissingProtocolMarker,
        malformedUnknownFlagBit,
        malformedTooLargeBody,
    ]

    public static let validNoopPacketBytes = validNoopHeader.bytes + noopBody
}
