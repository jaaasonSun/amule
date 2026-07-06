import Foundation

extension AppModel {
    func addFriend(hash: String, ip: String, port: String, name: String) {
        guard isBridgeOpSupported("friend-add") else { return }
        let trimmedHash = hash.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = trimmedName.isEmpty ? trimmedIP : trimmedName

        guard isValidFriendHash(trimmedHash) else {
            lastError = L3("Friend hash must be 32 hexadecimal characters.")
            return
        }
        guard isValidIPv4Address(trimmedIP) else {
            lastError = L3("Friend IP address is invalid.")
            return
        }
        guard let portNumber = Int(port.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...65535).contains(portNumber) else {
            lastError = L3("Friend port must be between 1 and 65535.")
            return
        }

        run(label: "friend-add") {
            let (_, raw) = try await self.bridge.friendAdd(
                hash: trimmedHash,
                ip: trimmedIP,
                port: portNumber,
                name: displayName,
                config: self.config
            )
            await MainActor.run {
                self.appendLog("$ friend-add --hash \(trimmedHash) --ip \(trimmedIP) --port \(portNumber)\n\(raw)")
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

    private func isValidFriendHash(_ hash: String) -> Bool {
        hash.count == 32 && hash.allSatisfy(\.isHexDigit)
    }

    private func isValidIPv4Address(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard part.allSatisfy(\.isNumber) else { return false }
            guard let value = Int(part), (0...255).contains(value) else { return false }
            return true
        }
    }
}
