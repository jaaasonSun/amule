import CryptoKit
import Foundation

public enum ECLegacyAuthError: Error, Equatable, CustomStringConvertible, Sendable {
    case emptyPassword
    case invalidMD5Hex(String)
    case authRejected(String?)
    case missingPasswordSalt

    public var description: String {
        switch self {
        case .emptyPassword:
            return "External Connection password must be non-empty."
        case .invalidMD5Hex(let value):
            return "Invalid MD5 hex password: \(value)."
        case .authRejected(let reason):
            return reason.map { "External Connection authentication rejected: \($0)." }
                ?? "External Connection authentication rejected."
        case .missingPasswordSalt:
            return "External Connection authentication salt is missing."
        }
    }
}

public enum ECAuthResult: Equatable, Sendable {
    case accepted(serverVersion: String?)
}

public enum ECLegacyAuth {
    public static func normalizePassword(_ password: String) throws -> String {
        guard !password.isEmpty else { throw ECLegacyAuthError.emptyPassword }

        if password.count == 32 {
            let normalized = password.lowercased()
            guard normalized.allSatisfy({ $0 >= "0" && $0 <= "9" || $0 >= "a" && $0 <= "f" }) else {
                throw ECLegacyAuthError.invalidMD5Hex(password)
            }
            guard normalized != emptyMD5Hex else { throw ECLegacyAuthError.emptyPassword }
            return normalized
        }

        let hashed = md5Hex(password)
        guard hashed != emptyMD5Hex else { throw ECLegacyAuthError.emptyPassword }
        return hashed
    }

    public static func saltHashHex(salt: UInt64) -> String {
        md5Hex(String(salt, radix: 16, uppercase: true))
    }

    public static func responseHashHex(password: String, salt: UInt64) throws -> String {
        let passwordHex = try normalizePassword(password)
        return responseHashHex(normalizedPasswordMD5Hex: passwordHex, salt: salt)
    }

    public static func responseHashHex(normalizedPasswordMD5Hex passwordHex: String, salt: UInt64) -> String {
        md5Hex(passwordHex.lowercased() + saltHashHex(salt: salt))
    }

    public static func responseHashBytes(password: String, salt: UInt64) throws -> Data {
        try bytes(fromMD5Hex: responseHashHex(password: password, salt: salt))
    }

    public static func bytes(fromMD5Hex hex: String) throws -> Data {
        guard hex.count == 32, hex.allSatisfy({ $0 >= "0" && $0 <= "9" || $0 >= "a" && $0 <= "f" }) else {
            throw ECLegacyAuthError.invalidMD5Hex(hex)
        }

        var bytes = Data(capacity: 16)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else {
                throw ECLegacyAuthError.invalidMD5Hex(hex)
            }
            bytes.append(byte)
            index = next
        }
        return bytes
    }

    public static func parseSalt(from packet: ECPacket) throws -> UInt64 {
        guard packet.opcode == ECAuthPacket.opAuthSalt,
              let tag = packet.tags.first(where: { $0.name == ECAuthPacket.tagPasswordSalt }),
              case .uint(let salt) = tag.value
        else {
            throw ECLegacyAuthError.missingPasswordSalt
        }
        return salt
    }

    public static func parseAuthResponse(_ packet: ECPacket) throws -> ECAuthResult {
        switch packet.opcode {
        case ECAuthPacket.opAuthOK:
            let version = packet.tags.compactMap { tag -> String? in
                guard tag.name == ECAuthPacket.tagServerVersion, case .string(let value) = tag.value else { return nil }
                return value
            }.first
            return .accepted(serverVersion: version)
        default:
            let reason = packet.tags.compactMap { tag -> String? in
                guard tag.name == ECAuthPacket.tagString, case .string(let value) = tag.value else { return nil }
                return value
            }.first
            throw ECLegacyAuthError.authRejected(reason)
        }
    }

    private static let emptyMD5Hex = "d41d8cd98f00b204e9800998ecf8427e"

    private static func md5Hex(_ text: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
