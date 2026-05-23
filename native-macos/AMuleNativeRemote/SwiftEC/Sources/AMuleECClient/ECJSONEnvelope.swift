import Foundation

public struct ECBridgeEnvelope<Payload: Encodable>: Encodable {
    public let ok: Bool
    public let schemaVersion: Int?
    public let error: String?
    public let message: String?
    public let capabilities: ECCapabilities?
    public let status: ECStatus?
    public let downloads: [ECDownload]?
    public let sources: [ECSource]?
    public let servers: [ECServer]?
    public let progress: Int?
    public let results: [ECSearchResult]?
    public let prefsConnection: ECConnectionPrefs?

    public init(ok: Bool, schemaVersion: Int? = nil, error: String? = nil, message: String? = nil, capabilities: ECCapabilities? = nil, status: ECStatus? = nil, downloads: [ECDownload]? = nil, sources: [ECSource]? = nil, servers: [ECServer]? = nil, progress: Int? = nil, results: [ECSearchResult]? = nil, prefsConnection: ECConnectionPrefs? = nil) {
        self.ok = ok
        self.schemaVersion = schemaVersion
        self.error = error
        self.message = message
        self.capabilities = capabilities
        self.status = status
        self.downloads = downloads
        self.sources = sources
        self.servers = servers
        self.progress = progress
        self.results = results
        self.prefsConnection = prefsConnection
    }

    private enum CodingKeys: String, CodingKey {
        case ok, error, message, capabilities, status, downloads, sources, servers, progress, results
        case schemaVersion = "schema_version"
        case prefsConnection = "prefs_connection"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ok, forKey: .ok)
        try container.encodeIfPresent(schemaVersion, forKey: .schemaVersion)
        try container.encodeIfPresent(error, forKey: .error)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(capabilities, forKey: .capabilities)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(downloads, forKey: .downloads)
        try container.encodeIfPresent(sources, forKey: .sources)
        try container.encodeIfPresent(servers, forKey: .servers)
        try container.encodeIfPresent(progress, forKey: .progress)
        try container.encodeIfPresent(results, forKey: .results)
        try container.encodeIfPresent(prefsConnection, forKey: .prefsConnection)
    }
}

public enum ECJSONEnvelope {
    public static func capabilities(_ capabilities: ECCapabilities) throws -> Data {
        try encode(ECBridgeEnvelope<EmptyPayload>(ok: true, schemaVersion: 1, capabilities: capabilities))
    }

    public static func status(_ status: ECStatus) throws -> Data {
        try encode(ECBridgeEnvelope<EmptyPayload>(ok: true, status: status))
    }

    public static func downloads(_ downloads: [ECDownload]) throws -> Data {
        try encode(ECBridgeEnvelope<EmptyPayload>(ok: true, downloads: downloads))
    }

    public static func sources(_ sources: [ECSource]) throws -> Data {
        try encode(ECBridgeEnvelope<EmptyPayload>(ok: true, sources: sources))
    }

    public static func servers(_ servers: [ECServer]) throws -> Data {
        try encode(ECBridgeEnvelope<EmptyPayload>(ok: true, servers: servers))
    }

    public static func search(progress: Int, results: [ECSearchResult]) throws -> Data {
        try encode(ECBridgeEnvelope<EmptyPayload>(ok: true, progress: progress, results: results))
    }

    public static func prefsConnection(_ prefs: ECConnectionPrefs) throws -> Data {
        try encode(ECBridgeEnvelope<EmptyPayload>(ok: true, prefsConnection: prefs))
    }

    public static func message(_ message: String) throws -> Data {
        try encode(ECBridgeEnvelope<EmptyPayload>(ok: true, message: message))
    }

    public static func error(_ message: String) throws -> Data {
        try encode(ECBridgeEnvelope<EmptyPayload>(ok: false, error: message))
    }

    public static func jsonString(_ data: Data) -> String {
        String(data: data, encoding: .utf8) ?? ""
    }

    private static func encode(_ envelope: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(envelope)
    }
}

public struct EmptyPayload: Encodable, Sendable {}
