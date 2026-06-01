import Foundation
import AMuleECBridgeAdapter
import AMuleECClient

enum BridgeAdapterFactory {
    static func makeBridgeAdapter() -> BridgeProtocol {
        SerializedBridgeAdapter(wrapping: MacOSPersistentSwiftECBridgeAdapter())
    }
}

private struct MacOSSwiftECSessionKey: Equatable, Sendable {
    let host: String
    let port: Int
    let password: String
}

private actor MacOSSwiftECSessionStore {
    private var key: MacOSSwiftECSessionKey?
    private var config: AMuleECBridgeAdapter.AMuleConnectionConfig?
    private var adapter: SwiftECBridgeAdapter?

    func adapter(for config: AMuleConnectionConfig) async -> (SwiftECBridgeAdapter, AMuleECBridgeAdapter.AMuleConnectionConfig) {
        let key = MacOSSwiftECSessionKey(host: config.host, port: config.port, password: config.password)
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

    func disconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
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

private extension AMuleConnectionConfig {
    var swiftECConfig: AMuleECBridgeAdapter.AMuleConnectionConfig {
        AMuleECBridgeAdapter.AMuleConnectionConfig(host: host, port: port, password: password)
    }
}

struct MacOSPersistentSwiftECBridgeAdapter: BridgeProtocol {
    private let sessions = MacOSSwiftECSessionStore()

    private func withAdapter<T: Sendable>(
        config: AMuleConnectionConfig,
        _ operation: (SwiftECBridgeAdapter, AMuleECBridgeAdapter.AMuleConnectionConfig) async throws -> T
    ) async throws -> T {
        let (adapter, ecConfig) = await sessions.adapter(for: config)
        return try await operation(adapter, ecConfig)
    }

    func connect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.connect(config: ecConfig)
        }
    }

    func disconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await sessions.disconnect(config: config)
    }

    func capabilities(config: AMuleConnectionConfig) async throws -> (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.capabilities(config: ecConfig)
        }
    }

    func status(config: AMuleConnectionConfig) async throws -> (BridgeStatusPayload, String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.status(config: ecConfig)
        }
    }

    func downloads(config: AMuleConnectionConfig) async throws -> ([BridgeDownloadPayload], String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.downloads(config: ecConfig)
        }
    }

    func search(scope: String, query: String, polls: Int, pollIntervalMs: Int, config: AMuleConnectionConfig) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.search(scope: scope, query: query, polls: polls, pollIntervalMs: pollIntervalMs, config: ecConfig)
        }
    }

    func searchStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.searchStop(config: ecConfig)
        }
    }

    func download(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.download(hash: hash, config: ecConfig)
        }
    }

    func addLink(link: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.addLink(link: link, config: ecConfig)
        }
    }

    func rename(hash: String, name: String, config: AMuleConnectionConfig) async throws -> RenameAcknowledgement {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.rename(hash: hash, name: name, config: ecConfig)
        }
    }

    func pause(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.pause(hash: hash, config: ecConfig)
        }
    }

    func resume(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.resume(hash: hash, config: ecConfig)
        }
    }

    func cancel(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.cancel(hash: hash, config: ecConfig)
        }
    }

    func servers(config: AMuleConnectionConfig) async throws -> ([BridgeServerPayload], String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.servers(config: ecConfig)
        }
    }

    func serverConnect(ip: String?, port: Int?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.serverConnect(ip: ip, port: port, config: ecConfig)
        }
    }

    func serverDisconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.serverDisconnect(config: ecConfig)
        }
    }

    func serverAdd(address: String, name: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.serverAdd(address: address, name: name, config: ecConfig)
        }
    }

    func serverRemove(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.serverRemove(ip: ip, port: port, config: ecConfig)
        }
    }

    func serverUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.serverUpdateFromURL(url: url, config: ecConfig)
        }
    }

    func sources(hash: String, config: AMuleConnectionConfig) async throws -> ([DownloadSourceItem], String) {
        do {
            return try await withAdapter(config: config) { adapter, ecConfig in
                let (payloads, raw) = try await adapter.sources(hash: hash, config: ecConfig)
                return (DownloadSourceItem.fromBridge(payloads), raw)
            }
        } catch let error as ECResponseParserError {
            if case .downloadNotFound(let missingHash) = error {
                throw AMuleClientError.downloadNotFound(missingHash)
            }
            throw error
        }
    }

    func prefsConnectionGet(config: AMuleConnectionConfig) async throws -> (BridgeConnectionPrefsPayload, String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.prefsConnectionGet(config: ecConfig)
        }
    }

    func prefsConnectionSet(maxDownload: Int, maxUpload: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.prefsConnectionSet(maxDownload: maxDownload, maxUpload: maxUpload, config: ecConfig)
        }
    }

    func kadStart(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.kadStart(config: ecConfig)
        }
    }

    func kadStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.kadStop(config: ecConfig)
        }
    }

    func kadBootstrap(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.kadBootstrap(ip: ip, port: port, config: ecConfig)
        }
    }

    func kadUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.kadUpdateFromURL(url: url, config: ecConfig)
        }
    }

    func uploads(config: AMuleConnectionConfig) async throws -> ([BridgeUploadPayload], String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.uploads(config: ecConfig)
        }
    }

    func sharedFiles(config: AMuleConnectionConfig) async throws -> ([BridgeSharedFilePayload], String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.sharedFiles(config: ecConfig)
        }
    }

    func sharedFilesReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.sharedFilesReload(config: ecConfig)
        }
    }

    func coreLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.coreLog(config: ecConfig)
        }
    }

    func debugLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.debugLog(config: ecConfig)
        }
    }

    func categories(config: AMuleConnectionConfig) async throws -> ([BridgeCategoryPayload], String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.categories(config: ecConfig)
        }
    }

    func categoryCreate(name: String, path: String, comment: String, color: Int, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.categoryCreate(name: name, path: path, comment: comment, color: color, priority: priority, config: ecConfig)
        }
    }

    func categoryDelete(categoryID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.categoryDelete(categoryID: categoryID, config: ecConfig)
        }
    }

    func ipfilterReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.ipfilterReload(config: ecConfig)
        }
    }

    func ipfilterUpdate(url: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.ipfilterUpdate(url: url, config: ecConfig)
        }
    }

    func friends(config: AMuleConnectionConfig) async throws -> ([BridgeFriendPayload], String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.friends(config: ecConfig)
        }
    }

    func friendRemove(friendID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.friendRemove(friendID: friendID, config: ecConfig)
        }
    }

    func friendSlot(friendID: Int, enabled: Bool, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.friendSlot(friendID: friendID, enabled: enabled, config: ecConfig)
        }
    }

    func clearCompleted(ecids: [Int], config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.clearCompleted(ecids: ecids, config: ecConfig)
        }
    }

    func priority(hash: String, value: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.priority(hash: hash, value: value, config: ecConfig)
        }
    }

    func statsTree(capping: Int?, config: AMuleConnectionConfig) async throws -> (BridgeStatsTreeNodePayload, String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.statsTree(capping: capping, config: ecConfig)
        }
    }

    func statsGraphs(width: Int, scale: Int, last: Double?, config: AMuleConnectionConfig) async throws -> (BridgeStatsGraphsPayload, String) {
        try await withAdapter(config: config) { adapter, ecConfig in
            try await adapter.statsGraphs(width: width, scale: scale, last: last, config: ecConfig)
        }
    }
}
