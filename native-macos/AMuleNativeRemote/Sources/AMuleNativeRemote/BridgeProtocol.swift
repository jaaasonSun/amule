import Foundation

protocol BridgeProtocol: Sendable {
    func connect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func disconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func capabilities(config: AMuleConnectionConfig) async throws -> (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String)
    func status(config: AMuleConnectionConfig) async throws -> (BridgeStatusPayload, String)
    func downloads(config: AMuleConnectionConfig) async throws -> ([BridgeDownloadPayload], String)
    func search(scope: String, query: String, polls: Int, pollIntervalMs: Int, config: AMuleConnectionConfig) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String)
    func searchStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func download(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func addLink(link: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func pause(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func resume(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func serverConnect(ip: String?, port: Int?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
}

struct MacOSBridgeAdapter: BridgeProtocol {
    func connect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await AMuleECBridgeClient.connect(config: config)
    }

    func disconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await AMuleECBridgeClient.disconnect(config: config)
    }

    func capabilities(config: AMuleConnectionConfig) async throws -> (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String) {
        try await AMuleECBridgeClient.capabilities(config: config)
    }

    func status(config: AMuleConnectionConfig) async throws -> (BridgeStatusPayload, String) {
        try await AMuleECBridgeClient.status(config: config)
    }

    func downloads(config: AMuleConnectionConfig) async throws -> ([BridgeDownloadPayload], String) {
        try await AMuleECBridgeClient.downloads(config: config)
    }

    func search(scope: String, query: String, polls: Int, pollIntervalMs: Int, config: AMuleConnectionConfig) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String) {
        try await AMuleECBridgeClient.search(scope: scope, query: query, polls: polls, pollIntervalMs: pollIntervalMs, config: config)
    }

    func searchStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await AMuleECBridgeClient.searchStop(config: config)
    }

    func download(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await AMuleECBridgeClient.download(hash: hash, config: config)
    }

    func addLink(link: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await AMuleECBridgeClient.addLink(link: link, config: config)
    }

    func pause(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await AMuleECBridgeClient.pause(hash: hash, config: config)
    }

    func resume(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await AMuleECBridgeClient.resume(hash: hash, config: config)
    }

    func serverConnect(ip: String?, port: Int?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await AMuleECBridgeClient.serverConnect(ip: ip, port: port, config: config)
    }
}

final class FakeBridgeAdapter: BridgeProtocol, @unchecked Sendable {
    var capabilitiesResult: (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String)
    var statusResult: (BridgeStatusPayload, String)
    var downloadsResult: ([BridgeDownloadPayload], String) = ([], #"{"ok":true,"downloads":[]}"#)
    var searchResult: (progress: Int, results: [BridgeSearchPayload], raw: String) = (0, [], #"{"ok":true,"progress":0,"results":[]}"#)
    var messageRaw: String = #"{"ok":true,"message":"ok"}"#

    init(
        capabilitiesResult: (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String)? = nil,
        statusResult: (BridgeStatusPayload, String)? = nil
    ) {
        self.capabilitiesResult = capabilitiesResult ?? (
            1,
            BridgeCapabilitiesPayload(
                bridgeVersion: "fake",
                clientName: "fake",
                defaultHost: "127.0.0.1",
                defaultPort: 4712,
                ops: ["capabilities", "status", "downloads", "search", "add-link", "pause", "resume", "server-connect"]
            ),
            #"{"ok":true,"schema_version":1,"capabilities":{"bridge_version":"fake","client_name":"fake","default_host":"127.0.0.1","default_port":4712,"ops":[]}}"#
        )
        self.statusResult = statusResult ?? (
            BridgeStatusPayload(
                connected: false,
                ed2k: "Disconnected",
                kad: "Disconnected",
                downloadSpeed: 0,
                uploadSpeed: 0,
                queue: 0,
                sources: 0
            ),
            #"{"ok":true,"status":{}}"#
        )
    }

    func connect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func disconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func capabilities(config: AMuleConnectionConfig) async throws -> (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String) { capabilitiesResult }
    func status(config: AMuleConnectionConfig) async throws -> (BridgeStatusPayload, String) { statusResult }
    func downloads(config: AMuleConnectionConfig) async throws -> ([BridgeDownloadPayload], String) { downloadsResult }
    func search(scope: String, query: String, polls: Int, pollIntervalMs: Int, config: AMuleConnectionConfig) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String) { searchResult }
    func searchStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func download(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func addLink(link: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func pause(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func resume(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func serverConnect(ip: String?, port: Int?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
}

func platformDefaultBridgeAdapter() -> BridgeProtocol {
    #if os(macOS)
    MacOSBridgeAdapter()
    #else
    FakeBridgeAdapter()
    #endif
}
