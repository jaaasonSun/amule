import Foundation

/// Golden authentication fixtures extracted from `src/libs/ec/cpp/RemoteConnect.cpp`.
///
/// Flow:
/// 1. Bridge normalizes a plain password to lowercase `MD5(password)`.
/// 2. Server replies with `EC_OP_AUTH_SALT` and integer `EC_TAG_PASSWD_SALT`.
/// 3. Client computes `saltHash = MD5(CFormat("%lX") % salt)`, i.e. uppercase hex salt text.
/// 4. Client computes `response = MD5(normalizedPasswordMD5.lower() + saltHash)`.
/// 5. `CECAuthPacket` sends `response` decoded as a 16-byte `EC_TAG_PASSWD_HASH` tag.
public enum ECAuthFixtures {
    public struct AuthHash: Equatable, Sendable {
        public let password: String
        public let passwordMD5Hex: String
        public let saltUInt64: UInt64
        public let saltUppercaseHex: String
        public let saltMD5Hex: String
        public let responseMD5Hex: String
        public let passwordHashTagBytes: [UInt8]
    }

    public static let secretPasswordSalt1234ABCD = AuthHash(
        password: "secret",
        passwordMD5Hex: "5ebe2294ecd0e0f08eab7690d2a6ee69",
        saltUInt64: 0x1234_abcd,
        saltUppercaseHex: "1234ABCD",
        saltMD5Hex: "3b8cd688b396a7d2a0c32a1a503d51c2",
        responseMD5Hex: "89e17d3c82aeb8eb245fa2d42750e25c",
        passwordHashTagBytes: [
            0x00, 0x02, 0x09, 0x00, 0x00, 0x00, 0x10,
            0x89, 0xe1, 0x7d, 0x3c, 0x82, 0xae, 0xb8, 0xeb,
            0x24, 0x5f, 0xa2, 0xd4, 0x27, 0x50, 0xe2, 0x5c,
        ]
    )

    /// `EC_OP_AUTH_PASSWD` packet body with one child `EC_TAG_PASSWD_HASH`.
    public static let authPasswordPacketBody: [UInt8] = [
        0x50, 0x00, 0x01,
    ] + secretPasswordSalt1234ABCD.passwordHashTagBytes

    /// Full uncompressed packet using base EC flags and `authPasswordPacketBody`.
    public static let authPasswordPacketBytes: [UInt8] = [
        0x00, 0x00, 0x00, 0x20,
        0x00, 0x00, 0x00, UInt8(authPasswordPacketBody.count),
    ] + authPasswordPacketBody

    /// Server salt body: `EC_OP_AUTH_SALT` with `EC_TAG_PASSWD_SALT = 0x1234ABCD`.
    public static let authSaltPacketBody: [UInt8] = [
        0x4f, 0x00, 0x01,
        0x00, 0x16, 0x04, 0x00, 0x00, 0x00, 0x04, 0x12, 0x34, 0xab, 0xcd,
    ]

    public static let additionalKnownHashes: [AuthHash] = [
        secretPasswordSalt1234ABCD,
        AuthHash(
            password: "amule",
            passwordMD5Hex: "ef7628c92bff39c0b3532d36a617cf09",
            saltUInt64: 0x1234_abcd,
            saltUppercaseHex: "1234ABCD",
            saltMD5Hex: "3b8cd688b396a7d2a0c32a1a503d51c2",
            responseMD5Hex: "0f8efcb84613c01967ffbd9589e71565",
            passwordHashTagBytes: [
                0x00, 0x02, 0x09, 0x00, 0x00, 0x00, 0x10,
                0x0f, 0x8e, 0xfc, 0xb8, 0x46, 0x13, 0xc0, 0x19,
                0x67, 0xff, 0xbd, 0x95, 0x89, 0xe7, 0x15, 0x65,
            ]
        ),
    ]
}
