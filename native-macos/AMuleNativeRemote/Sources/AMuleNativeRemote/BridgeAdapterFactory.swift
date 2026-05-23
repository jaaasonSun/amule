import Foundation
import AMuleECBridgeAdapter

enum BridgeAdapterFactory {
    static func makeBridgeAdapter() -> BridgeProtocol {
        #if os(macOS)
        SwiftECBridgeAdapterWrapper()
        #else
        FakeBridgeAdapter()
        #endif
    }
}

struct SwiftECBridgeAdapterWrapper: BridgeProtocol {
    private let swiftECAdapter = SwiftECBridgeAdapter()

    func connect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let ecConfig = AMuleECBridgeAdapter.AMuleConnectionConfig(
            host: config.host,
            port: config.port,
            password: config.password
        )
        return try await swiftECAdapter.connect(config: ecConfig)
    }

    func disconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let ecConfig = AMuleECBridgeAdapter.AMuleConnectionConfig(
            host: config.host,
            port: config.port,
            password: config.password
        )
        return try await swiftECAdapter.disconnect(config: ecConfig)
    }

    func capabilities(config: AMuleConnectionConfig) async throws -> (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String) {
        let ecConfig = AMuleECBridgeAdapter.AMuleConnectionConfig(
            host: config.host,
            port: config.port,
            password: config.password
        )
        return try await swiftECAdapter.capabilities(config: ecConfig)
    }

    func status(config: AMuleConnectionConfig) async throws -> (BridgeStatusPayload, String) {
        let ecConfig = AMuleECBridgeAdapter.AMuleConnectionConfig(
            host: config.host,
            port: config.port,
            password: config.password
        )
        return try await swiftECAdapter.status(config: ecConfig)
    }

    func downloads(config: AMuleConnectionConfig) async throws -> ([BridgeDownloadPayload], String) {
        let ecConfig = AMuleECBridgeAdapter.AMuleConnectionConfig(
            host: config.host,
            port: config.port,
            password: config.password
        )
        return try await swiftECAdapter.downloads(config: ecConfig)
    }

    func search(scope: String, query: String, polls: Int, pollIntervalMs: Int, config: AMuleConnectionConfig) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String) {
        let ecConfig = AMuleECBridgeAdapter.AMuleConnectionConfig(
            host: config.host,
            port: config.port,
            password: config.password
        )
        return try await swiftECAdapter.search(scope: scope, query: query, polls: polls, pollIntervalMs: pollIntervalMs, config: ecConfig)
    }

    func searchStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let ecConfig = AMuleECBridgeAdapter.AMuleConnectionConfig(
            host: config.host,
            port: config.port,
            password: config.password
        )
        return try await swiftECAdapter.searchStop(config: ecConfig)
    }

    func download(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let ecConfig = AMuleECBridgeAdapter.AMuleConnectionConfig(
            host: config.host,
            port: config.port,
            password: config.password
        )
        return try await swiftECAdapter.download(hash: hash, config: ecConfig)
    }

    func addLink(link: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let ecConfig = AMuleECBridgeAdapter.AMuleConnectionConfig(
            host: config.host,
            port: config.port,
            password: config.password
        )
        return try await swiftECAdapter.addLink(link: link, config: ecConfig)
    }

    func rename(hash: String, name: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let ecConfig = AMuleECBridgeAdapter.AMuleConnectionConfig(
            host: config.host,
            port: config.port,
            password: config.password
        )
        return try await swiftECAdapter.rename(hash: hash, name: name, config: ecConfig)
    }

    func pause(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let ecConfig = AMuleECBridgeAdapter.AMuleConnectionConfig(
            host: config.host,
            port: config.port,
            password: config.password
        )
        return try await swiftECAdapter.pause(hash: hash, config: ecConfig)
    }

    func resume(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let ecConfig = AMuleECBridgeAdapter.AMuleConnectionConfig(
            host: config.host,
            port: config.port,
            password: config.password
        )
        return try await swiftECAdapter.resume(hash: hash, config: ecConfig)
    }

    func cancel(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let ecConfig = AMuleECBridgeAdapter.AMuleConnectionConfig(
            host: config.host,
            port: config.port,
            password: config.password
        )
        return try await swiftECAdapter.cancel(hash: hash, config: ecConfig)
    }

    func servers(config: AMuleConnectionConfig) async throws -> ([BridgeServerPayload], String) {
        let ecConfig = AMuleECBridgeAdapter.AMuleConnectionConfig(
            host: config.host,
            port: config.port,
            password: config.password
        )
        return try await swiftECAdapter.servers(config: ecConfig)
    }

    func serverConnect(ip: String?, port: Int?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let ecConfig = AMuleECBridgeAdapter.AMuleConnectionConfig(
            host: config.host,
            port: config.port,
            password: config.password
        )
        return try await swiftECAdapter.serverConnect(ip: ip, port: port, config: ecConfig)
    }

    func serverDisconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let ecConfig = AMuleECBridgeAdapter.AMuleConnectionConfig(
            host: config.host,
            port: config.port,
            password: config.password
        )
        return try await swiftECAdapter.serverDisconnect(config: ecConfig)
    }

    func serverAdd(address: String, name: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let ecConfig = AMuleECBridgeAdapter.AMuleConnectionConfig(
            host: config.host,
            port: config.port,
            password: config.password
        )
        return try await swiftECAdapter.serverAdd(address: address, name: name, config: ecConfig)
    }

    func serverRemove(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let ecConfig = AMuleECBridgeAdapter.AMuleConnectionConfig(
            host: config.host,
            port: config.port,
            password: config.password
        )
        return try await swiftECAdapter.serverRemove(ip: ip, port: port, config: ecConfig)
    }

    func serverUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let ecConfig = AMuleECBridgeAdapter.AMuleConnectionConfig(
            host: config.host,
            port: config.port,
            password: config.password
        )
        return try await swiftECAdapter.serverUpdateFromURL(url: url, config: ecConfig)
    }

    func sources(hash: String, config: AMuleConnectionConfig) async throws -> ([DownloadSourceItem], String) {
        let ecConfig = AMuleECBridgeAdapter.AMuleConnectionConfig(
            host: config.host,
            port: config.port,
            password: config.password
        )
        let (payloads, raw) = try await swiftECAdapter.sources(hash: hash, config: ecConfig)
        return (DownloadSourceItem.fromBridge(payloads), raw)
    }

    func prefsConnectionGet(config: AMuleConnectionConfig) async throws -> (BridgeConnectionPrefsPayload, String) {
        let ecConfig = AMuleECBridgeAdapter.AMuleConnectionConfig(
            host: config.host,
            port: config.port,
            password: config.password
        )
        return try await swiftECAdapter.prefsConnectionGet(config: ecConfig)
    }

    func prefsConnectionSet(maxDownload: Int, maxUpload: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let ecConfig = AMuleECBridgeAdapter.AMuleConnectionConfig(
            host: config.host,
            port: config.port,
            password: config.password
        )
        return try await swiftECAdapter.prefsConnectionSet(maxDownload: maxDownload, maxUpload: maxUpload, config: ecConfig)
    }
}
