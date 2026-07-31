#if canImport(UIKit)
import SwiftUI
import AMuleECClient
import SharedModels
import SharedServices
import SharedViews

@MainActor
struct IOSConnectionService {
    func startLifecycleServices(model: IOSAppModel) {
        model.appLifecycleService.start()
        model.reconnectAfterForegroundTransition()
    }

    func stopLifecycleServices(model: IOSAppModel) {
        model.appLifecycleService.stop()
        model.stopAutoRefresh()
    }

    func connect(model: IOSAppModel) {
        let trimmedHost = model.host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty else {
            model.lastError = L("Host is required.")
            model.isSessionConnected = false
            return
        }

        guard (1...65535).contains(model.port) else {
            model.lastError = L("Invalid port. Enter a value between 1 and 65535.")
            model.isSessionConnected = false
            return
        }

        model.host = trimmedHost
        model.resetSessionCoordinator()
        let session = model.currentSessionCoordinator()
        model.isBusy = true
        model.lastError = ""
        let config = model.config
        let bridge = model.bridgeClient
        Task {
            do {
                let _ = try await model.runStartupStep("authenticate") {
                    try await bridge.connect(config: config)
                }
                let (_, capabilities, _) = try await model.runStartupStep("load capabilities") {
                    try await bridge.capabilities(config: config)
                }
                let (bridgeStatus, _) = try await model.runStartupStep("load status") {
                    try await bridge.status(config: config)
                }
                let (downloadPayloads, _) = try await model.runStartupStep("load downloads") {
                    try await bridge.downloads(config: config)
                }
                let remoteServerPayloads = try await model.runStartupStep("load servers") {
                    try await model.remoteServersIfSupported(by: capabilities.ops, config: config)
                }
                await MainActor.run {
                    guard model.isCurrentSession(session) else { return }
                    model.isSessionConnected = true
                    model.bridgeOps = Set(capabilities.ops)
                    model.bridgeVersion = capabilities.bridgeVersion
                    model.bridgeClientName = capabilities.clientName
                    model.bridgeDefaultHost = capabilities.defaultHost
                    model.bridgeDefaultPort = capabilities.defaultPort
                    model.status = StatusSnapshot.fromBridge(bridgeStatus)
                    model.downloads = DownloadItem.fromBridge(downloadPayloads)
                    model.servers = ServerItem.fromBridge(remoteServerPayloads)
                    model.isBusy = false
                    model.startAutoRefresh()
                    model.flushIncomingLinks()
                    model.fetchTransferLimits()
                }
            } catch {
                await MainActor.run {
                    guard model.isCurrentSession(session) else { return }
                    model.lastError = model.localNetworkErrorPresenter.userFacingMessage(for: error)
                    model.isSessionConnected = false
                    model.isBusy = false
                    model.stopAutoRefresh()
                }
            }
        }
    }

    func disconnect(model: IOSAppModel) {
        let session = model.currentSessionCoordinator()
        model.isBusy = true
        let config = model.config
        let bridge = model.bridgeClient
        Task {
            do {
                let _ = try await bridge.disconnect(config: config)
                await MainActor.run {
                    guard model.isCurrentSession(session) else { return }
                    model.isSessionConnected = false
                    model.bridgeOps = []
                    model.bridgeVersion = ""
                    model.bridgeClientName = ""
                    model.bridgeDefaultHost = ""
                    model.bridgeDefaultPort = 0
                    model.status = StatusSnapshot()
                    model.servers = []
                    model.isBusy = false
                    model.stopAutoRefresh()
                    model.resetSessionCoordinator()
                }
            } catch {
                await MainActor.run {
                    guard model.isCurrentSession(session) else { return }
                    model.lastError = model.localNetworkErrorPresenter.userFacingMessage(for: error)
                    model.isBusy = false
                }
            }
        }
    }
}
#endif
