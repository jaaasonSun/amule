import Foundation

/// Golden EC tag fixtures extracted from `src/libs/ec/cpp/ECTag.{h,cpp}` and `ECCodes.h`.
///
/// Serialized tag layout:
/// - `uint16 tagNameAndChildren`: `(tagName << 1) | hasChildren`, network byte order
/// - `uint8 type`
/// - `uint32 length`: data length plus full serialized child tags, network byte order
/// - optional `uint16 childCount` when `hasChildren == true`
/// - child tags
/// - raw data bytes
///
/// Source tag type values are `CUSTOM=1, UINT8=2, UINT16=3, UINT32=4, UINT64=5,
/// STRING=6, DOUBLE=7, IPV4=8, HASH16=9, UINT128=10`.
public enum ECTagFixtures {
    public struct Tag: Equatable, Sendable {
        public let name: String
        public let tagName: UInt16
        public let type: UInt8
        public let valueDescription: String
        public let bytes: [UInt8]
    }

    public enum TagType {
        public static let custom: UInt8 = 1
        public static let uint8: UInt8 = 2
        public static let uint16: UInt8 = 3
        public static let uint32: UInt8 = 4
        public static let uint64: UInt8 = 5
        public static let string: UInt8 = 6
        public static let double: UInt8 = 7
        public static let ipv4: UInt8 = 8
        public static let hash16: UInt8 = 9
    }

    public static let uint8Tag = Tag(
        name: "EC_TAG_DETAIL_LEVEL uint8 full-detail",
        tagName: 0x0004,
        type: TagType.uint8,
        valueDescription: "EC_DETAIL_FULL = 2",
        bytes: [0x00, 0x08, 0x02, 0x00, 0x00, 0x00, 0x01, 0x02]
    )

    public static let uint16Tag = Tag(
        name: "EC_TAG_PROTOCOL_VERSION uint16 current-version",
        tagName: 0x0002,
        type: TagType.uint16,
        valueDescription: "EC_CURRENT_PROTOCOL_VERSION = 0x0204",
        bytes: [0x00, 0x04, 0x03, 0x00, 0x00, 0x00, 0x02, 0x02, 0x04]
    )

    public static let uint32Tag = Tag(
        name: "EC_TAG_ECID uint32 sample-id",
        tagName: 0x000f,
        type: TagType.uint32,
        valueDescription: "0x01020304",
        bytes: [0x00, 0x1e, 0x04, 0x00, 0x00, 0x00, 0x04, 0x01, 0x02, 0x03, 0x04]
    )

    public static let uint64Tag = Tag(
        name: "EC_TAG_PARTFILE_SIZE_FULL uint64 sample-size",
        tagName: 0x0303,
        type: TagType.uint64,
        valueDescription: "0x0102030405060708",
        bytes: [0x06, 0x06, 0x05, 0x00, 0x00, 0x00, 0x08, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
    )

    public static let stringTag = Tag(
        name: "EC_TAG_CLIENT_NAME string",
        tagName: 0x0100,
        type: TagType.string,
        valueDescription: "aMuleNativeBridge plus NUL terminator",
        bytes: [
            0x02, 0x00, 0x06, 0x00, 0x00, 0x00, 0x12,
            0x61, 0x4d, 0x75, 0x6c, 0x65, 0x4e, 0x61, 0x74, 0x69, 0x76,
            0x65, 0x42, 0x72, 0x69, 0x64, 0x67, 0x65, 0x00,
        ]
    )

    public static let doubleTag = Tag(
        name: "EC_TAG_CLIENT_DOWN_SPEED double-as-string",
        tagName: 0x060e,
        type: TagType.double,
        valueDescription: "3.5 encoded as ASCII `3.5\\0` by `std::ostringstream`",
        bytes: [0x0c, 0x1c, 0x07, 0x00, 0x00, 0x00, 0x04, 0x33, 0x2e, 0x35, 0x00]
    )

    public static let ipv4Tag = Tag(
        name: "EC_TAG_SERVER IPv4 endpoint",
        tagName: 0x0500,
        type: TagType.ipv4,
        valueDescription: "1.2.3.4:4662; port is network-order 0x1236",
        bytes: [0x0a, 0x00, 0x08, 0x00, 0x00, 0x00, 0x06, 0x01, 0x02, 0x03, 0x04, 0x12, 0x36]
    )

    public static let hash16Tag = Tag(
        name: "EC_TAG_PASSWD_HASH hash16",
        tagName: 0x0001,
        type: TagType.hash16,
        valueDescription: "16 raw bytes 00...0f",
        bytes: [
            0x00, 0x02, 0x09, 0x00, 0x00, 0x00, 0x10,
            0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
            0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
        ]
    )

    public static let nestedTag = Tag(
        name: "EC_TAG_PARTFILE nested custom tag",
        tagName: 0x0300,
        type: TagType.custom,
        valueDescription: "Parent with EC_TAG_PARTFILE_PRIO uint8(1) and EC_TAG_PARTFILE_NAME string(`child`) children",
        bytes: [
            0x06, 0x01, 0x01, 0x00, 0x00, 0x00, 0x15, 0x00, 0x02,
            0x06, 0x12, 0x02, 0x00, 0x00, 0x00, 0x01, 0x01,
            0x06, 0x02, 0x06, 0x00, 0x00, 0x00, 0x06, 0x63, 0x68, 0x69, 0x6c, 0x64, 0x00,
        ]
    )

    public static let allTags: [Tag] = [
        uint8Tag,
        uint16Tag,
        uint32Tag,
        uint64Tag,
        stringTag,
        doubleTag,
        ipv4Tag,
        hash16Tag,
        nestedTag,
    ]

    /// Example packet body containing every top-level fixture tag.
    public static let aggregatePacketBody: [UInt8] = [0x06, 0x00, UInt8(allTags.count)] + allTags.flatMap(\.bytes)
}
