import Foundation
import SharedModels
import SharedServices

extension AppModel {
    func refreshServers() {
        run(label: "servers") {
            try await self.refreshServersNow()
        }
    }

    func addServer() {
        let address = serverAddressInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = serverNameInput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !address.isEmpty else {
            lastError = L3("Server address is required (e.g. 1.2.3.4:4661).")
            return
        }

        run(label: "server-add") {
            let (_, raw) = try await self.bridge.serverAdd(
                address: address,
                name: name.isEmpty ? nil : name,
                config: self.config
            )
            await MainActor.run {
                self.appendLog("$ server-add \(address)\n\(raw)")
                self.serverAddressInput = ""
                self.serverNameInput = ""
            }
            try await self.mutationRefreshServersNow(logOutput: false)
        }
    }

    func connectServer(_ server: ServerItem?) {
        run(label: "server-connect") {
            let ip = server?.ip
            let port = server?.port
            let (_, raw) = try await self.bridge.serverConnect(ip: ip, port: port, config: self.config)
            await MainActor.run {
                if let server {
                    self.appendLog("$ server-connect \(server.address)\n\(raw)")
                } else {
                    self.appendLog("$ server-connect\n\(raw)")
                }
            }
            await self.mutationRefreshStatus(logOutput: false)
            try await self.mutationRefreshServersNow(logOutput: false)
        }
    }

    func disconnectServer() {
        run(label: "server-disconnect") {
            let (_, raw) = try await self.bridge.serverDisconnect(config: self.config)
            await MainActor.run {
                self.appendLog("$ server-disconnect\n\(raw)")
            }
            await self.mutationRefreshStatus(logOutput: false)
            try await self.mutationRefreshServersNow(logOutput: false)
        }
    }

    func removeServer(_ server: ServerItem) {
        guard !server.ip.isEmpty, server.port > 0 else {
            lastError = L3("Selected server has invalid endpoint information.")
            return
        }

        run(label: "server-remove") {
            let (_, raw) = try await self.bridge.serverRemove(ip: server.ip, port: server.port, config: self.config)
            await MainActor.run {
                self.appendLog("$ server-remove \(server.address)\n\(raw)")
            }
            try await self.mutationRefreshServersNow(logOutput: false)
        }
    }

    func setServerStatic(ecid: Int, isStatic: Bool) {
        guard isBridgeOpSupported("server-set-static") else { return }
        run(label: "server-set-static") {
            let (_, raw) = try await self.bridge.serverSetStatic(ecid: ecid, isStatic: isStatic, config: self.config)
            await MainActor.run {
                self.appendLog("$ server-set-static \(ecid) \(isStatic ? 1 : 0)\n\(raw)")
            }
            if self.isBridgeOpSupported("servers") {
                try? await self.mutationRefreshServersNow(logOutput: false, suppressErrors: true)
            }
        }
    }

    func setServerPriority(ecid: Int, priority: Int) {
        guard isBridgeOpSupported("server-set-priority") else { return }
        run(label: "server-set-priority") {
            let (_, raw) = try await self.bridge.serverSetPriority(ecid: ecid, priority: priority, config: self.config)
            await MainActor.run {
                self.appendLog("$ server-set-priority \(ecid) \(priority)\n\(raw)")
            }
            if self.isBridgeOpSupported("servers") {
                try? await self.mutationRefreshServersNow(logOutput: false, suppressErrors: true)
            }
        }
    }

    func refreshServerInfo() {
        guard isBridgeOpSupported("server-info") else { return }
        run(label: "server-info") {
            let (payload, raw) = try await self.bridge.serverInfo(config: self.config)
            await MainActor.run {
                self.serverInfoLines = payload.lines
                self.lastServerInfoRawOutput = raw
                self.appendLog("$ server-info\n\(raw)")
            }
        }
    }

    func clearServerInfo() {
        guard isBridgeOpSupported("clear-server-info") else { return }
        run(label: "clear-server-info") {
            let (_, raw) = try await self.bridge.clearServerInfo(config: self.config)
            await MainActor.run {
                self.serverInfoLines = []
                self.lastServerInfoRawOutput = ""
                self.appendLog("$ clear-server-info\n\(raw)")
            }
        }
    }

    func updateServerListFromURL(_ rawURL: String) {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = L3("Server list URL is required.")
            return
        }
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            lastError = L3("Invalid server list URL. Use http:// or https://.")
            return
        }

        run(label: "server-update-from-url") {
            let (_, raw) = try await self.bridge.serverUpdateFromURL(url: trimmed, config: self.config)
            await MainActor.run {
                self.appendLog("$ server-update-from-url \(trimmed)\n\(raw)")
            }
            try await self.mutationRefreshServersNow(logOutput: false)
        }
    }

    func updateKadNodesFromURL(_ rawURL: String) {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = L3("nodes.dat URL is required.")
            return
        }
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            lastError = L3("Invalid nodes.dat URL. Use http:// or https://.")
            return
        }

        run(label: "kad-update-from-url") {
            let (_, raw) = try await self.bridge.kadUpdateFromURL(url: trimmed, config: self.config)
            await MainActor.run {
                self.appendLog("$ kad-update-from-url \(trimmed)\n\(raw)")
            }
            await self.refreshStatus(logOutput: false, suppressErrors: true)
        }
    }

    func startKad() {
        guard isBridgeOpSupported("kad-start") else { return }
        run(label: "kad-start") {
            let (_, raw) = try await self.bridge.kadStart(config: self.config)
            await MainActor.run {
                self.appendLog("$ kad-start\n\(raw)")
            }
            await self.refreshStatus(logOutput: false, suppressErrors: true)
        }
    }

    func stopKad() {
        guard isBridgeOpSupported("kad-stop") else { return }
        run(label: "kad-stop") {
            let (_, raw) = try await self.bridge.kadStop(config: self.config)
            await MainActor.run {
                self.appendLog("$ kad-stop\n\(raw)")
            }
            await self.refreshStatus(logOutput: false, suppressErrors: true)
        }
    }

    func bootstrapKad(ip rawIP: String, port rawPort: String) {
        guard isBridgeOpSupported("kad-bootstrap") else { return }

        let ip = rawIP.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidIPv4(ip) else {
            lastError = L3("Invalid Kad bootstrap IP address.")
            return
        }

        let trimmedPort = rawPort.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let port = Int(trimmedPort), (1...65535).contains(port) else {
            lastError = L3("Invalid Kad bootstrap port.")
            return
        }

        run(label: "kad-bootstrap") {
            let (_, raw) = try await self.bridge.kadBootstrap(ip: ip, port: port, config: self.config)
            await MainActor.run {
                self.appendLog("$ kad-bootstrap --server-ip \(ip) --server-port \(port)\n\(raw)")
            }
            await self.refreshStatus(logOutput: false, suppressErrors: true)
        }
    }

    func refreshServersNow(logOutput: Bool = true, suppressErrors: Bool = false) async throws {
        let session = currentSessionCoordinator()
        do {
            guard let (payload, raw) = try await session.coordinator.manualRefreshServers(),
                  isCurrentSession(session) else {
                return
            }
            let parsed = ServerItem.fromBridge(payload)
            await MainActor.run {
                self.servers = parsed
                self.lastServersRawOutput = raw
                if logOutput {
                    self.appendLog("$ servers\n\(raw)")
                }
            }
        } catch {
            guard isCurrentSession(session) else { return }
            await MainActor.run {
                if !suppressErrors {
                    self.lastError = error.localizedDescription
                }
            }
            throw error
        }
    }

    func mutationRefreshServersNow(logOutput: Bool = true, suppressErrors: Bool = false) async throws {
        let session = currentSessionCoordinator()
        do {
            guard let (payload, raw) = try await session.coordinator.mutationRefreshServers(),
                  isCurrentSession(session) else {
                return
            }
            let parsed = ServerItem.fromBridge(payload)
            await MainActor.run {
                self.servers = parsed
                self.lastServersRawOutput = raw
                if logOutput {
                    self.appendLog("$ servers\n\(raw)")
                }
            }
        } catch {
            guard isCurrentSession(session) else { return }
            await MainActor.run {
                if !suppressErrors {
                    self.lastError = error.localizedDescription
                }
            }
            throw error
        }
    }

    private func isValidIPv4(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        for part in parts {
            guard let octet = Int(part), (0...255).contains(octet) else {
                return false
            }
        }
        return true
    }
}
