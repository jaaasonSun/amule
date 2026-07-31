#if canImport(UIKit)
import SwiftUI
import AMuleECClient
import SharedModels
import SharedServices
import SharedViews

@MainActor
struct IOSServerService {
    func refreshServers(model: IOSAppModel) {
        guard model.isBridgeOpSupported("servers") else {
            model.servers = []
            return
        }
        let session = model.currentSessionCoordinator()
        Task {
            do {
                if let (payloads, _) = try await session.coordinator.manualRefreshServers(),
                   model.isCurrentSession(session) {
                    model.servers = ServerItem.fromBridge(payloads)
                }
            } catch {
                guard model.isCurrentSession(session) else { return }
                model.lastError = model.localNetworkErrorPresenter.userFacingMessage(for: error)
            }
        }
    }

    func connectServer(_ server: ServerItem?, model: IOSAppModel) {
        guard model.isBridgeOpSupported("server-connect") else {
            model.lastError = L("Connecting to daemon servers is not supported by this server.")
            return
        }
        let config = model.config
        let bridge = model.bridgeClient
        let session = model.currentSessionCoordinator()
        Task {
            do {
                let _ = try await bridge.serverConnect(ip: server?.ip, port: server?.port, config: config)
                try await mutationRefreshStatus(model: model, session: session)
            } catch {
                await MainActor.run {
                    guard model.isCurrentSession(session) else { return }
                    model.lastError = model.localNetworkErrorPresenter.userFacingMessage(for: error)
                }
            }
        }
    }

    func connectUserServer(_ server: UserServer, model: IOSAppModel) {
        guard model.isBridgeOpSupported("server-connect") else {
            model.lastError = L("Connecting to local bookmarks is not supported by this server.")
            return
        }
        let config = model.config
        let bridge = model.bridgeClient
        let session = model.currentSessionCoordinator()
        Task {
            do {
                let _ = try await bridge.serverConnect(ip: server.ip, port: server.port, config: config)
                try await mutationRefreshStatus(model: model, session: session)
            } catch {
                await MainActor.run {
                    guard model.isCurrentSession(session) else { return }
                    model.lastError = model.localNetworkErrorPresenter.userFacingMessage(for: error)
                }
            }
        }
    }

    func disconnectServer(model: IOSAppModel) {
        guard model.isBridgeOpSupported("server-disconnect") else {
            model.lastError = L("Disconnecting from daemon servers is not supported by this server.")
            return
        }
        let config = model.config
        let bridge = model.bridgeClient
        let session = model.currentSessionCoordinator()
        Task {
            do {
                let _ = try await bridge.serverDisconnect(config: config)
                try await mutationRefreshStatus(model: model, session: session)
            } catch {
                await MainActor.run {
                    guard model.isCurrentSession(session) else { return }
                    model.lastError = model.localNetworkErrorPresenter.userFacingMessage(for: error)
                }
            }
        }
    }

    func addServer(name: String, ip: String, port: Int, model: IOSAppModel) {
        let endpoint = model.normalizedEndpoint(ip: ip, port: port)
        guard !endpoint.isEmpty else { return }
        guard !model.userServers.contains(where: { model.normalizedEndpoint(ip: $0.ip, port: $0.port) == endpoint }) else {
            model.lastError = "That local server bookmark already exists."
            return
        }
        let server = UserServer(name: name, ip: ip, port: port)
        model.userServers.append(server)
        model.persistUserServers()
    }

    func addRemoteServer(address: String, name: String?, model: IOSAppModel) {
        guard model.isBridgeOpSupported("server-add") else {
            model.lastError = L("Adding daemon servers is not supported by this server.")
            return
        }
        let config = model.config
        let bridge = model.bridgeClient
        let session = model.currentSessionCoordinator()
        Task {
            do {
                let _ = try await bridge.serverAdd(address: address, name: name, config: config)
                try await mutationRefreshServers(model: model, session: session)
            } catch {
                await MainActor.run {
                    guard model.isCurrentSession(session) else { return }
                    model.lastError = model.localNetworkErrorPresenter.userFacingMessage(for: error)
                }
            }
        }
    }

    func editUserServer(_ server: UserServer, newName: String, newIP: String, newPort: Int, model: IOSAppModel) {
        guard let index = model.userServers.firstIndex(of: server) else { return }
        model.userServers[index] = UserServer(name: newName, ip: newIP, port: newPort)
        model.persistUserServers()
    }

    func removeUserServer(_ server: UserServer, model: IOSAppModel) {
        model.userServers.removeAll { $0 == server }
        model.persistUserServers()
    }

    func removeRemoteServer(_ server: ServerItem, model: IOSAppModel) {
        guard model.isBridgeOpSupported("server-remove") else {
            model.lastError = L("Removing daemon servers is not supported by this server.")
            return
        }
        let config = model.config
        let bridge = model.bridgeClient
        let session = model.currentSessionCoordinator()
        Task {
            do {
                let _ = try await bridge.serverRemove(ip: server.ip, port: server.port, config: config)
                try await mutationRefreshServers(model: model, session: session)
            } catch {
                await MainActor.run {
                    guard model.isCurrentSession(session) else { return }
                    model.lastError = model.localNetworkErrorPresenter.userFacingMessage(for: error)
                }
            }
        }
    }

    func updateRemoteServers(from url: String, model: IOSAppModel) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard model.isBridgeOpSupported("server-update-from-url") else {
            model.lastError = L("Updating daemon servers from URL is not supported by this server.")
            return
        }
        let config = model.config
        let bridge = model.bridgeClient
        let session = model.currentSessionCoordinator()
        Task {
            do {
                let _ = try await bridge.serverUpdateFromURL(url: trimmed, config: config)
                try await mutationRefreshServers(model: model, session: session)
            } catch {
                await MainActor.run {
                    guard model.isCurrentSession(session) else { return }
                    model.lastError = model.localNetworkErrorPresenter.userFacingMessage(for: error)
                }
            }
        }
    }

    private func mutationRefreshStatus(model: IOSAppModel, session: IOSRemoteSessionLease) async throws {
        guard model.isCurrentSession(session) else { return }
        guard let (bridgeStatus, _) = try await session.coordinator.mutationRefreshStatus(),
              model.isCurrentSession(session) else {
            return
        }
        model.status = StatusSnapshot.fromBridge(bridgeStatus)
        model.isSessionConnected = bridgeStatus.connected
        if !bridgeStatus.connected {
            model.stopAutoRefresh()
        }
    }

    private func mutationRefreshServers(model: IOSAppModel, session: IOSRemoteSessionLease) async throws {
        guard model.isCurrentSession(session) else { return }
        guard let (payloads, _) = try await session.coordinator.mutationRefreshServers(),
              model.isCurrentSession(session) else {
            return
        }
        model.servers = ServerItem.fromBridge(payloads)
    }
}
#endif
