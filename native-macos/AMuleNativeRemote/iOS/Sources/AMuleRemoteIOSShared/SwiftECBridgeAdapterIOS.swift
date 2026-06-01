import Foundation
import AMuleECBridgeAdapter
import AMuleECClient
import SharedCore

private struct SwiftECSessionKey: Equatable, Sendable {
    let host: String
    let port: Int
    let password: String
}

private actor SwiftECIOSSessionStore {
    private var key: SwiftECSessionKey?
    private var config: AMuleECBridgeAdapter.AMuleConnectionConfig?
    private var adapter: SwiftECBridgeAdapter?

    func resolveAdapter(for config: SharedCore.AMuleConnectionConfig) async -> (SwiftECBridgeAdapter, AMuleECBridgeAdapter.AMuleConnectionConfig) {
        let key = SwiftECSessionKey(host: config.host, port: config.port, password: config.password)
        let ecConfig = config.swiftECConfig

        if let adapter, self.key == key {
            return (adapter, ecConfig)
        }

        if let adapter, let oldConfig = self.config {
            _ = try? await adapter.disconnect(config: oldConfig)
        }

        let session = ECSession(configuration: ECSession.Configuration(
            host: config.host,
            port: UInt16(clamping: config.port),
            password: config.password
        ))
        let adapter = SwiftECBridgeAdapter(session: session)
        self.key = key
        self.config = ecConfig
        self.adapter = adapter
        return (adapter, ecConfig)
    }

    func disconnect(config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let ecConfig = config.swiftECConfig
        guard let adapter else {
            return try await SwiftECBridgeAdapter().disconnect(config: ecConfig)
        }

        self.key = nil
        self.config = nil
        self.adapter = nil
        return try await adapter.disconnect(config: ecConfig)
    }
}

private extension SharedCore.AMuleConnectionConfig {
    var swiftECConfig: AMuleECBridgeAdapter.AMuleConnectionConfig {
        AMuleECBridgeAdapter.AMuleConnectionConfig(
            host: host,
            port: port,
            password: password
        )
    }
}

public struct SwiftECBridgeAdapterIOS: SharedCore.BridgeProtocol {
    private let sessions = SwiftECIOSSessionStore()

    public func connect(config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.connect(config: ecConfig)
    }

    public func disconnect(config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await sessions.disconnect(config: config)
    }

    public func capabilities(config: SharedCore.AMuleConnectionConfig) async throws -> (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.capabilities(config: ecConfig)
    }

    public func status(config: SharedCore.AMuleConnectionConfig) async throws -> (BridgeStatusPayload, String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.status(config: ecConfig)
    }

    public func downloads(config: SharedCore.AMuleConnectionConfig) async throws -> ([BridgeDownloadPayload], String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.downloads(config: ecConfig)
    }

    public func search(scope: String, query: String, polls: Int, pollIntervalMs: Int, config: SharedCore.AMuleConnectionConfig) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.search(scope: scope, query: query, polls: polls, pollIntervalMs: pollIntervalMs, config: ecConfig)
    }

    public func searchStop(config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.searchStop(config: ecConfig)
    }

    public func download(hash: String, config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.download(hash: hash, config: ecConfig)
    }

    public func addLink(link: String, config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.addLink(link: link, config: ecConfig)
    }

    public func rename(hash: String, name: String, config: SharedCore.AMuleConnectionConfig) async throws -> RenameAcknowledgement {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.rename(hash: hash, name: name, config: ecConfig)
    }

    public func pause(hash: String, config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.pause(hash: hash, config: ecConfig)
    }

    public func resume(hash: String, config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.resume(hash: hash, config: ecConfig)
    }

    public func cancel(hash: String, config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.cancel(hash: hash, config: ecConfig)
    }

    public func servers(config: SharedCore.AMuleConnectionConfig) async throws -> ([BridgeServerPayload], String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.servers(config: ecConfig)
    }

    public func serverConnect(ip: String?, port: Int?, config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.serverConnect(ip: ip, port: port, config: ecConfig)
    }

    public func serverDisconnect(config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.serverDisconnect(config: ecConfig)
    }

    public func serverAdd(address: String, name: String?, config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.serverAdd(address: address, name: name, config: ecConfig)
    }

    public func serverRemove(ip: String, port: Int, config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.serverRemove(ip: ip, port: port, config: ecConfig)
    }

    public func serverUpdateFromURL(url: String, config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.serverUpdateFromURL(url: url, config: ecConfig)
    }

    public func sources(hash: String, config: SharedCore.AMuleConnectionConfig) async throws -> ([DownloadSourceItem], String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        do {
            let (payloads, raw) = try await swiftECAdapter.sources(hash: hash, config: ecConfig)
            return (DownloadSourceItem.fromBridge(payloads), raw)
        } catch let error as ECResponseParserError {
            if case .downloadNotFound(let missingHash) = error {
                throw AMuleClientError.downloadNotFound(missingHash)
            }
            throw error
        }
    }

    public func prefsConnectionGet(config: SharedCore.AMuleConnectionConfig) async throws -> (BridgeConnectionPrefsPayload, String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.prefsConnectionGet(config: ecConfig)
    }

    public func prefsConnectionSet(maxDownload: Int, maxUpload: Int, config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.prefsConnectionSet(maxDownload: maxDownload, maxUpload: maxUpload, config: ecConfig)
    }

    public func kadStart(config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.kadStart(config: ecConfig)
    }

    public func kadStop(config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.kadStop(config: ecConfig)
    }

    public func kadBootstrap(ip: String, port: Int, config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.kadBootstrap(ip: ip, port: port, config: ecConfig)
    }

    public func kadUpdateFromURL(url: String, config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.kadUpdateFromURL(url: url, config: ecConfig)
    }

    public func uploads(config: SharedCore.AMuleConnectionConfig) async throws -> ([BridgeUploadPayload], String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.uploads(config: ecConfig)
    }

    public func sharedFiles(config: SharedCore.AMuleConnectionConfig) async throws -> ([BridgeSharedFilePayload], String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.sharedFiles(config: ecConfig)
    }

    public func sharedFilesReload(config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.sharedFilesReload(config: ecConfig)
    }

    public func coreLog(config: SharedCore.AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.coreLog(config: ecConfig)
    }

    public func debugLog(config: SharedCore.AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.debugLog(config: ecConfig)
    }

    public func categories(config: SharedCore.AMuleConnectionConfig) async throws -> ([BridgeCategoryPayload], String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.categories(config: ecConfig)
    }

    public func categoryCreate(name: String, path: String, comment: String, color: Int, priority: Int, config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.categoryCreate(name: name, path: path, comment: comment, color: color, priority: priority, config: ecConfig)
    }

    public func categoryDelete(categoryID: Int, config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.categoryDelete(categoryID: categoryID, config: ecConfig)
    }

    public func ipfilterReload(config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.ipfilterReload(config: ecConfig)
    }

    public func ipfilterUpdate(url: String?, config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.ipfilterUpdate(url: url, config: ecConfig)
    }

    public func friends(config: SharedCore.AMuleConnectionConfig) async throws -> ([BridgeFriendPayload], String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.friends(config: ecConfig)
    }

    public func friendRemove(friendID: Int, config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.friendRemove(friendID: friendID, config: ecConfig)
    }

    public func friendSlot(friendID: Int, enabled: Bool, config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.friendSlot(friendID: friendID, enabled: enabled, config: ecConfig)
    }

    public func clearCompleted(ecids: [Int], config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.clearCompleted(ecids: ecids, config: ecConfig)
    }

    public func priority(hash: String, value: String, config: SharedCore.AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.priority(hash: hash, value: value, config: ecConfig)
    }

    public func statsTree(capping: Int?, config: SharedCore.AMuleConnectionConfig) async throws -> (BridgeStatsTreeNodePayload, String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.statsTree(capping: capping, config: ecConfig)
    }

    public func statsGraphs(width: Int, scale: Int, last: Double?, config: SharedCore.AMuleConnectionConfig) async throws -> (BridgeStatsGraphsPayload, String) {
        let (swiftECAdapter, ecConfig) = await sessions.resolveAdapter(for: config)
        return try await swiftECAdapter.statsGraphs(width: width, scale: scale, last: last, config: ecConfig)
    }
}

public func platformDefaultBridgeAdapter() -> SharedCore.BridgeProtocol {
    SerializedBridgeAdapter(wrapping: SwiftECBridgeAdapterIOS())
}
