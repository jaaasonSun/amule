import Foundation
import AMuleECBridgeAdapter
import AMuleECClient

private struct SwiftECSessionKey: Equatable, Sendable {
    let host: String
    let port: Int
    let password: String
}

private actor SwiftECIOSSessionStore {
    private var key: SwiftECSessionKey?
    private var config: AMuleECBridgeAdapter.AMuleConnectionConfig?
    private var adapter: SwiftECBridgeAdapter?

    func adapter(for config: AMuleConnectionConfig) async -> (SwiftECBridgeAdapter, AMuleECBridgeAdapter.AMuleConnectionConfig) {
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
        AMuleECBridgeAdapter.AMuleConnectionConfig(
            host: host,
            port: port,
            password: password
        )
    }
}

public struct SwiftECBridgeAdapterIOS: BridgeProtocol {
    private let sessions = SwiftECIOSSessionStore()

    public func connect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.adapter(for: config)
        return try await swiftECAdapter.connect(config: ecConfig)
    }

    public func disconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await sessions.disconnect(config: config)
    }

    public func capabilities(config: AMuleConnectionConfig) async throws -> (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.adapter(for: config)
        return try await swiftECAdapter.capabilities(config: ecConfig)
    }

    public func status(config: AMuleConnectionConfig) async throws -> (BridgeStatusPayload, String) {
        let (swiftECAdapter, ecConfig) = await sessions.adapter(for: config)
        return try await swiftECAdapter.status(config: ecConfig)
    }

    public func downloads(config: AMuleConnectionConfig) async throws -> ([BridgeDownloadPayload], String) {
        let (swiftECAdapter, ecConfig) = await sessions.adapter(for: config)
        return try await swiftECAdapter.downloads(config: ecConfig)
    }

    public func search(scope: String, query: String, polls: Int, pollIntervalMs: Int, config: AMuleConnectionConfig) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.adapter(for: config)
        return try await swiftECAdapter.search(scope: scope, query: query, polls: polls, pollIntervalMs: pollIntervalMs, config: ecConfig)
    }

    public func searchStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.adapter(for: config)
        return try await swiftECAdapter.searchStop(config: ecConfig)
    }

    public func download(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.adapter(for: config)
        return try await swiftECAdapter.download(hash: hash, config: ecConfig)
    }

    public func addLink(link: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.adapter(for: config)
        return try await swiftECAdapter.addLink(link: link, config: ecConfig)
    }

    public func rename(hash: String, name: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.adapter(for: config)
        return try await swiftECAdapter.rename(hash: hash, name: name, config: ecConfig)
    }

    public func pause(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.adapter(for: config)
        return try await swiftECAdapter.pause(hash: hash, config: ecConfig)
    }

    public func resume(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.adapter(for: config)
        return try await swiftECAdapter.resume(hash: hash, config: ecConfig)
    }

    public func cancel(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.adapter(for: config)
        return try await swiftECAdapter.cancel(hash: hash, config: ecConfig)
    }

    public func servers(config: AMuleConnectionConfig) async throws -> ([BridgeServerPayload], String) {
        let (swiftECAdapter, ecConfig) = await sessions.adapter(for: config)
        return try await swiftECAdapter.servers(config: ecConfig)
    }

    public func serverConnect(ip: String?, port: Int?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.adapter(for: config)
        return try await swiftECAdapter.serverConnect(ip: ip, port: port, config: ecConfig)
    }

    public func serverDisconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.adapter(for: config)
        return try await swiftECAdapter.serverDisconnect(config: ecConfig)
    }

    public func serverAdd(address: String, name: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.adapter(for: config)
        return try await swiftECAdapter.serverAdd(address: address, name: name, config: ecConfig)
    }

    public func serverRemove(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.adapter(for: config)
        return try await swiftECAdapter.serverRemove(ip: ip, port: port, config: ecConfig)
    }

    public func serverUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.adapter(for: config)
        return try await swiftECAdapter.serverUpdateFromURL(url: url, config: ecConfig)
    }

    public func sources(hash: String, config: AMuleConnectionConfig) async throws -> ([DownloadSourceItem], String) {
        let (swiftECAdapter, ecConfig) = await sessions.adapter(for: config)
        let (payloads, raw) = try await swiftECAdapter.sources(hash: hash, config: ecConfig)
        return (DownloadSourceItem.fromBridge(payloads), raw)
    }

    public func prefsConnectionGet(config: AMuleConnectionConfig) async throws -> (BridgeConnectionPrefsPayload, String) {
        let (swiftECAdapter, ecConfig) = await sessions.adapter(for: config)
        return try await swiftECAdapter.prefsConnectionGet(config: ecConfig)
    }

    public func prefsConnectionSet(maxDownload: Int, maxUpload: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (swiftECAdapter, ecConfig) = await sessions.adapter(for: config)
        return try await swiftECAdapter.prefsConnectionSet(maxDownload: maxDownload, maxUpload: maxUpload, config: ecConfig)
    }
}

public func platformDefaultBridgeAdapter() -> BridgeProtocol {
    SerializedBridgeAdapter(wrapping: SwiftECBridgeAdapterIOS())
}
