import Foundation

struct FriendAddInput {
    struct Request: Equatable {
        let hash: String
        let ip: String
        let port: Int
        let name: String
    }

    enum ValidationError: Error, Equatable {
        case invalidHash
        case invalidIP
        case invalidPort

        var localizedMessage: String {
            switch self {
            case .invalidHash:
                return L3("Friend hash must be 32 hexadecimal characters.")
            case .invalidIP:
                return L3("Friend IP address is invalid.")
            case .invalidPort:
                return L3("Friend port must be between 1 and 65535.")
            }
        }
    }

    let hash: String
    let ip: String
    let port: String
    let name: String

    func validated() throws -> Request {
        let trimmedHash = hash.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard Self.isValidFriendHash(trimmedHash) else {
            throw ValidationError.invalidHash
        }
        guard Self.isValidIPv4Address(trimmedIP) else {
            throw ValidationError.invalidIP
        }
        guard let portNumber = Int(port.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...65535).contains(portNumber) else {
            throw ValidationError.invalidPort
        }

        return Request(
            hash: trimmedHash,
            ip: trimmedIP,
            port: portNumber,
            name: trimmedName.isEmpty ? trimmedIP : trimmedName
        )
    }

    private static func isValidFriendHash(_ hash: String) -> Bool {
        hash.count == 32 && hash.allSatisfy(\.isHexDigit)
    }

    private static func isValidIPv4Address(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard part.allSatisfy(\.isNumber) else { return false }
            guard let value = Int(part), (0...255).contains(value) else { return false }
            return true
        }
    }
}

extension AppModel {
    func addFriend(hash: String, ip: String, port: String, name: String) {
        guard isBridgeOpSupported("friend-add") else { return }
        let request: FriendAddInput.Request
        do {
            request = try FriendAddInput(hash: hash, ip: ip, port: port, name: name).validated()
        } catch let error as FriendAddInput.ValidationError {
            lastError = error.localizedMessage
            return
        } catch {
            lastError = L3("Friend input is invalid.")
            return
        }

        run(label: "friend-add") {
            let (_, raw) = try await self.bridge.friendAdd(
                hash: request.hash,
                ip: request.ip,
                port: request.port,
                name: request.name,
                config: self.config
            )
            await MainActor.run {
                self.appendLog("$ friend-add --hash \(request.hash) --ip \(request.ip) --port \(request.port)\n\(raw)")
            }
            if self.isBridgeOpSupported("friends") {
                try await self.refreshFriendsNow(logOutput: false, suppressErrors: true)
            }
        }
    }

    func requestFriendSharedList(id: Int) {
        guard isBridgeOpSupported("friend-shared") else { return }
        run(label: "friend-shared") {
            let (_, raw) = try await self.bridge.friendRequestSharedList(friendID: id, config: self.config)
            await MainActor.run {
                self.appendLog("$ friend-shared --friend-id \(id)\n\(raw)")
            }
        }
    }

    var isRemoteMessagesSupported: Bool {
        false
    }
}
