#if canImport(UIKit)
import SwiftUI
import AMuleRemoteIOSShared
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
        let config = model.config
        let bridge = model.bridgeClient
        Task {
            do {
                let (payloads, _) = try await bridge.servers(config: config)
                await MainActor.run {
                    model.servers = ServerItem.fromBridge(payloads)
                }
            } catch {
                await MainActor.run {
                    model.lastError = model.localNetworkErrorPresenter.userFacingMessage(for: error)
                }
            }
        }
    }

    func connectServer(_ server: ServerItem?, model: IOSAppModel) {
        guard model.isBridgeOpSupported("server-connect") else {
            model.lastError = L("Connecting to daemon servers is not supported by this bridge.")
            return
        }
        let config = model.config
        let bridge = model.bridgeClient
        Task {
            do {
                let _ = try await bridge.serverConnect(ip: server?.ip, port: server?.port, config: config)
                await MainActor.run {
                    model.refreshStatus()
                }
            } catch {
                await MainActor.run {
                    model.lastError = model.localNetworkErrorPresenter.userFacingMessage(for: error)
                }
            }
        }
    }

    func connectUserServer(_ server: UserServer, model: IOSAppModel) {
        guard model.isBridgeOpSupported("server-connect") else {
            model.lastError = L("Connecting to local bookmarks is not supported by this bridge.")
            return
        }
        let config = model.config
        let bridge = model.bridgeClient
        Task {
            do {
                let _ = try await bridge.serverConnect(ip: server.ip, port: server.port, config: config)
                await MainActor.run {
                    model.refreshStatus()
                }
            } catch {
                await MainActor.run {
                    model.lastError = model.localNetworkErrorPresenter.userFacingMessage(for: error)
                }
            }
        }
    }

    func disconnectServer(model: IOSAppModel) {
        guard model.isBridgeOpSupported("server-disconnect") else {
            model.lastError = L("Disconnecting from daemon servers is not supported by this bridge.")
            return
        }
        let config = model.config
        let bridge = model.bridgeClient
        Task {
            do {
                let _ = try await bridge.serverDisconnect(config: config)
                await MainActor.run {
                    model.refreshStatus()
                }
            } catch {
                await MainActor.run {
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
            model.lastError = L("Adding daemon servers is not supported by this bridge.")
            return
        }
        let config = model.config
        let bridge = model.bridgeClient
        Task {
            do {
                let _ = try await bridge.serverAdd(address: address, name: name, config: config)
                await MainActor.run {
                    model.refreshServers()
                }
            } catch {
                await MainActor.run {
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
            model.lastError = L("Removing daemon servers is not supported by this bridge.")
            return
        }
        let config = model.config
        let bridge = model.bridgeClient
        Task {
            do {
                let _ = try await bridge.serverRemove(ip: server.ip, port: server.port, config: config)
                await MainActor.run {
                    model.refreshServers()
                }
            } catch {
                await MainActor.run {
                    model.lastError = model.localNetworkErrorPresenter.userFacingMessage(for: error)
                }
            }
        }
    }

    func updateRemoteServers(from url: String, model: IOSAppModel) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard model.isBridgeOpSupported("server-update-from-url") else {
            model.lastError = L("Updating daemon servers from URL is not supported by this bridge.")
            return
        }
        let config = model.config
        let bridge = model.bridgeClient
        Task {
            do {
                let _ = try await bridge.serverUpdateFromURL(url: trimmed, config: config)
                await MainActor.run {
                    model.refreshServers()
                }
            } catch {
                await MainActor.run {
                    model.lastError = model.localNetworkErrorPresenter.userFacingMessage(for: error)
                }
            }
        }
    }
}
#endif
