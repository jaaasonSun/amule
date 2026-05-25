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
    public let uploads: [ECUpload]?
    public let sharedFiles: [ECSharedFile]?
    public let log: ECCoreLog?
    public let categories: [ECCategory]?
    public let friends: [ECFriend]?
    public let stats: ECStatsPayload?
    public let progress: Int?
    public let results: [ECSearchResult]?
    public let prefsConnection: ECConnectionPrefs?

    public init(ok: Bool, schemaVersion: Int? = nil, error: String? = nil, message: String? = nil, capabilities: ECCapabilities? = nil, status: ECStatus? = nil, downloads: [ECDownload]? = nil, sources: [ECSource]? = nil, servers: [ECServer]? = nil, uploads: [ECUpload]? = nil, sharedFiles: [ECSharedFile]? = nil, log: ECCoreLog? = nil, categories: [ECCategory]? = nil, friends: [ECFriend]? = nil, stats: ECStatsPayload? = nil, progress: Int? = nil, results: [ECSearchResult]? = nil, prefsConnection: ECConnectionPrefs? = nil) {
        self.ok = ok
        self.schemaVersion = schemaVersion
        self.error = error
        self.message = message
        self.capabilities = capabilities
        self.status = status
        self.downloads = downloads
        self.sources = sources
        self.servers = servers
        self.uploads = uploads
        self.sharedFiles = sharedFiles
        self.log = log
        self.categories = categories
        self.friends = friends
        self.stats = stats
        self.progress = progress
        self.results = results
        self.prefsConnection = prefsConnection
    }

    private enum CodingKeys: String, CodingKey {
        case ok, error, message, capabilities, status, downloads, sources, servers, uploads, log, categories, friends, stats, progress, results
        case schemaVersion = "schema_version"
        case sharedFiles = "shared_files"
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
        try container.encodeIfPresent(uploads, forKey: .uploads)
        try container.encodeIfPresent(sharedFiles, forKey: .sharedFiles)
        try container.encodeIfPresent(log, forKey: .log)
        try container.encodeIfPresent(categories, forKey: .categories)
        try container.encodeIfPresent(friends, forKey: .friends)
        try container.encodeIfPresent(stats, forKey: .stats)
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

    public static func uploads(_ uploads: [ECUpload]) throws -> Data {
        try encode(ECBridgeEnvelope<EmptyPayload>(ok: true, uploads: uploads))
    }

    public static func sharedFiles(_ sharedFiles: [ECSharedFile]) throws -> Data {
        try encode(ECBridgeEnvelope<EmptyPayload>(ok: true, sharedFiles: sharedFiles))
    }

    public static func log(_ log: ECCoreLog) throws -> Data {
        try encode(ECBridgeEnvelope<EmptyPayload>(ok: true, log: log))
    }

    public static func categories(_ categories: [ECCategory]) throws -> Data {
        try encode(ECBridgeEnvelope<EmptyPayload>(ok: true, categories: categories))
    }

    public static func friends(_ friends: [ECFriend]) throws -> Data {
        try encode(ECBridgeEnvelope<EmptyPayload>(ok: true, friends: friends))
    }

    public static func statsTree(_ tree: ECStatsTreeNode) throws -> Data {
        try encode(ECBridgeEnvelope<EmptyPayload>(ok: true, stats: ECStatsPayload(tree: tree, graphs: nil)))
    }

    public static func statsGraphs(_ graphs: ECStatsGraphs) throws -> Data {
        try encode(ECBridgeEnvelope<EmptyPayload>(ok: true, stats: ECStatsPayload(tree: nil, graphs: graphs)))
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

public struct ECStatsPayload: Codable, Equatable, Sendable {
    public let tree: ECStatsTreeNode?
    public let graphs: ECStatsGraphs?

    public init(tree: ECStatsTreeNode?, graphs: ECStatsGraphs?) {
        self.tree = tree
        self.graphs = graphs
    }
}
