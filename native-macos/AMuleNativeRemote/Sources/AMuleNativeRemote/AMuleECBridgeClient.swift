import Foundation

struct AMuleConnectionConfig {
    var bridgePath: String
    var host: String
    var port: Int
    var password: String

    static let fallbackBridgeCommand = "amule-ec-bridge"

    static var bundledBridgePath: String? {
        let fm = FileManager.default
        if let resource = Bundle.main.resourceURL?.appendingPathComponent("amule-ec-bridge").path,
           fm.isExecutableFile(atPath: resource) {
            return resource
        }

        let appBundlePath = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/amule-ec-bridge")
            .path
        if fm.isExecutableFile(atPath: appBundlePath) {
            return appBundlePath
        }

        return nil
    }

    static func preferredDefaultPath() -> String {
        let fm = FileManager.default
        if let bundled = bundledBridgePath {
            return bundled
        }

        let cwd = fm.currentDirectoryPath
        let candidates = [
            URL(fileURLWithPath: cwd)
                .appendingPathComponent("build/src/amule-ec-bridge")
                .path,
            URL(fileURLWithPath: cwd)
                .appendingPathComponent("../build/src/amule-ec-bridge")
                .standardized.path,
            URL(fileURLWithPath: cwd)
                .appendingPathComponent("../../build/src/amule-ec-bridge")
                .standardized.path,
            "/opt/homebrew/bin/amule-ec-bridge",
            "/usr/local/bin/amule-ec-bridge"
        ]

        for candidate in candidates where fm.isExecutableFile(atPath: candidate) {
            return candidate
        }

        return fallbackBridgeCommand
    }
}

enum AMuleClientError: LocalizedError {
    case missingBridge(String)
    case processFailure(Int32, String)
    case invalidResponse(String)
    case bridgeFailure(String)

    var errorDescription: String? {
        switch self {
        case .missingBridge(let path):
            return "amule-ec-bridge not found at: \(path)"
        case .processFailure(let code, let output):
            return "amule-ec-bridge exited with code \(code).\n\(output)"
        case .invalidResponse(let output):
            return "Invalid bridge response.\n\(output)"
        case .bridgeFailure(let message):
            return message
        }
    }
}

struct BridgeStatusPayload: Decodable {
    let connected: Bool
    let ed2k: String
    let kad: String
    let downloadSpeed: Int
    let uploadSpeed: Int
    let queue: Int
    let sources: Int

    private enum CodingKeys: String, CodingKey {
        case connected
        case ed2k
        case kad
        case downloadSpeed = "download_speed"
        case uploadSpeed = "upload_speed"
        case queue
        case sources
    }
}

struct BridgeDownloadPayload: Decodable {
    struct AlternativeName: Decodable {
        let name: String
        let count: Int
    }

    let ecid: Int
    let hash: String
    let name: String
    let nameEncodingSuspect: Bool
    let nameEncodingSuggestion: String?
    let size: UInt64
    let done: UInt64
    let transferred: UInt64
    let progress: Double
    let sourcesCurrent: Int
    let sourcesTotal: Int
    let sourcesTransferring: Int
    let sourcesA4AF: Int
    let statusCode: Int
    let isCompleted: Bool
    let status: String
    let speed: Int
    let priority: Int
    let category: Int
    let partMet: String
    let lastSeenComplete: UInt64
    let lastReceived: UInt64
    let activeSeconds: Int
    let availableParts: Int
    let shared: Bool
    let alternativeNames: [AlternativeName]
    let progressColors: [UInt32]?

    private enum CodingKeys: String, CodingKey {
        case ecid
        case hash
        case name
        case nameEncodingSuspect = "name_encoding_suspect"
        case nameEncodingSuggestion = "name_encoding_suggestion"
        case size
        case done
        case transferred
        case progress
        case sourcesCurrent = "sources_current"
        case sourcesTotal = "sources_total"
        case sourcesTransferring = "sources_transferring"
        case sourcesA4AF = "sources_a4af"
        case statusCode = "status_code"
        case isCompleted = "is_completed"
        case status
        case speed
        case priority
        case category
        case partMet = "part_met"
        case lastSeenComplete = "last_seen_complete"
        case lastReceived = "last_received"
        case activeSeconds = "active_seconds"
        case availableParts = "available_parts"
        case shared
        case alternativeNames = "alternative_names"
        case progressColors = "progress_colors"
    }

    init(
        ecid: Int,
        hash: String,
        name: String,
        nameEncodingSuspect: Bool,
        nameEncodingSuggestion: String?,
        size: UInt64,
        done: UInt64,
        transferred: UInt64,
        progress: Double,
        sourcesCurrent: Int,
        sourcesTotal: Int,
        sourcesTransferring: Int,
        sourcesA4AF: Int,
        statusCode: Int,
        isCompleted: Bool,
        status: String,
        speed: Int,
        priority: Int,
        category: Int,
        partMet: String,
        lastSeenComplete: UInt64,
        lastReceived: UInt64,
        activeSeconds: Int,
        availableParts: Int,
        shared: Bool,
        alternativeNames: [AlternativeName],
        progressColors: [UInt32]?
    ) {
        self.ecid = ecid
        self.hash = hash
        self.name = name
        self.nameEncodingSuspect = nameEncodingSuspect
        self.nameEncodingSuggestion = nameEncodingSuggestion
        self.size = size
        self.done = done
        self.transferred = transferred
        self.progress = progress
        self.sourcesCurrent = sourcesCurrent
        self.sourcesTotal = sourcesTotal
        self.sourcesTransferring = sourcesTransferring
        self.sourcesA4AF = sourcesA4AF
        self.statusCode = statusCode
        self.isCompleted = isCompleted
        self.status = status
        self.speed = speed
        self.priority = priority
        self.category = category
        self.partMet = partMet
        self.lastSeenComplete = lastSeenComplete
        self.lastReceived = lastReceived
        self.activeSeconds = activeSeconds
        self.availableParts = availableParts
        self.shared = shared
        self.alternativeNames = alternativeNames
        self.progressColors = progressColors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ecid = try container.decode(Int.self, forKey: .ecid)
        hash = try container.decode(String.self, forKey: .hash)
        name = try container.decode(String.self, forKey: .name)
        nameEncodingSuspect = try container.decodeIfPresent(Bool.self, forKey: .nameEncodingSuspect) ?? false
        nameEncodingSuggestion = try container.decodeIfPresent(String.self, forKey: .nameEncodingSuggestion)
        size = try container.decode(UInt64.self, forKey: .size)
        done = try container.decode(UInt64.self, forKey: .done)
        transferred = try container.decode(UInt64.self, forKey: .transferred)
        progress = try container.decode(Double.self, forKey: .progress)
        sourcesCurrent = try container.decode(Int.self, forKey: .sourcesCurrent)
        sourcesTotal = try container.decode(Int.self, forKey: .sourcesTotal)
        sourcesTransferring = try container.decode(Int.self, forKey: .sourcesTransferring)
        sourcesA4AF = try container.decode(Int.self, forKey: .sourcesA4AF)
        statusCode = try container.decode(Int.self, forKey: .statusCode)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        status = try container.decode(String.self, forKey: .status)
        speed = try container.decode(Int.self, forKey: .speed)
        priority = try container.decode(Int.self, forKey: .priority)
        category = try container.decode(Int.self, forKey: .category)
        partMet = try container.decode(String.self, forKey: .partMet)
        lastSeenComplete = try container.decode(UInt64.self, forKey: .lastSeenComplete)
        lastReceived = try container.decode(UInt64.self, forKey: .lastReceived)
        activeSeconds = try container.decode(Int.self, forKey: .activeSeconds)
        availableParts = try container.decode(Int.self, forKey: .availableParts)
        shared = try container.decode(Bool.self, forKey: .shared)
        alternativeNames = try container.decode([AlternativeName].self, forKey: .alternativeNames)
        progressColors = try container.decodeIfPresent([UInt32].self, forKey: .progressColors)
    }
}

struct BridgeDownloadSourcePayload: Decodable {
    let clientID: Int
    let requestFileID: Int
    let clientName: String
    let userIP: String
    let userPort: Int
    let serverName: String
    let serverIP: String
    let serverPort: Int
    let software: String
    let softwareVersion: String
    let downloadState: Int
    let downloadStateText: String
    let sourceFrom: Int
    let sourceFromText: String
    let downSpeedKBps: Double
    let availableParts: Int
    let remoteQueueRank: Int
    let obfuscationStatus: Int
    let extendedProtocol: Bool
    let remoteFilename: String

    private enum CodingKeys: String, CodingKey {
        case clientID = "client_id"
        case requestFileID = "request_file_id"
        case clientName = "client_name"
        case userIP = "user_ip"
        case userPort = "user_port"
        case serverName = "server_name"
        case serverIP = "server_ip"
        case serverPort = "server_port"
        case software
        case softwareVersion = "software_version"
        case downloadState = "download_state"
        case downloadStateText = "download_state_text"
        case sourceFrom = "source_from"
        case sourceFromText = "source_from_text"
        case downSpeedKBps = "down_speed_kbps"
        case availableParts = "available_parts"
        case remoteQueueRank = "remote_queue_rank"
        case obfuscationStatus = "obfuscation_status"
        case extendedProtocol = "extended_protocol"
        case remoteFilename = "remote_filename"
    }
}

struct BridgeSearchPayload: Decodable {
    let id: Int
    let hash: String
    let name: String
    let size: UInt64
    let sources: Int
    let completeSources: Int
    let statusCode: Int
    let status: String
    let parentID: Int
    let alreadyHave: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case hash
        case name
        case size
        case sources
        case completeSources = "complete_sources"
        case statusCode = "status_code"
        case status
        case parentID = "parent_id"
        case alreadyHave = "already_have"
    }
}

struct BridgeServerPayload: Decodable {
    let id: Int
    let name: String
    let description: String
    let version: String
    let address: String
    let ip: String
    let port: Int
    let users: Int
    let maxUsers: Int
    let files: Int
    let ping: Int
    let failed: Int
    let priority: Int
    let isStatic: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case version
        case address
        case ip
        case port
        case users
        case maxUsers = "max_users"
        case files
        case ping
        case failed
        case priority
        case isStatic = "is_static"
    }
}

struct BridgeCapabilitiesPayload: Decodable {
    let bridgeVersion: String
    let clientName: String
    let defaultHost: String
    let defaultPort: Int
    let ops: [String]

    private enum CodingKeys: String, CodingKey {
        case bridgeVersion = "bridge_version"
        case clientName = "client_name"
        case defaultHost = "default_host"
        case defaultPort = "default_port"
        case ops
    }
}

struct BridgeUploadPayload: Decodable {
    let clientID: Int
    let clientName: String
    let userIP: String
    let userPort: Int
    let serverIP: String
    let serverPort: Int
    let serverName: String
    let speedUp: Int
    let xferUp: UInt64
    let xferDown: UInt64
    let uploadFile: Int?

    private enum CodingKeys: String, CodingKey {
        case clientID = "client_id"
        case clientName = "client_name"
        case userIP = "user_ip"
        case userPort = "user_port"
        case serverIP = "server_ip"
        case serverPort = "server_port"
        case serverName = "server_name"
        case speedUp = "speed_up"
        case xferUp = "xfer_up"
        case xferDown = "xfer_down"
        case uploadFile = "upload_file"
    }
}

struct BridgeSharedFilePayload: Decodable {
    let hash: String
    let name: String
    let path: String
    let size: UInt64
    let ed2kLink: String
    let priority: Int
    let requests: Int
    let requestsAll: Int
    let accepts: Int
    let acceptsAll: Int
    let xferred: UInt64
    let xferredAll: UInt64
    let comment: String?
    let rating: Int?

    private enum CodingKeys: String, CodingKey {
        case hash
        case name
        case path
        case size
        case ed2kLink = "ed2k_link"
        case priority
        case requests
        case requestsAll = "requests_all"
        case accepts
        case acceptsAll = "accepts_all"
        case xferred
        case xferredAll = "xferred_all"
        case comment
        case rating
    }
}

struct BridgeCoreLogPayload: Decodable {
    let kind: String
    let lines: [String]
}

struct BridgeConnectionPrefsPayload: Decodable {
    let maxDownload: Int
    let maxUpload: Int

    private enum CodingKeys: String, CodingKey {
        case maxDownload = "max_dl"
        case maxUpload = "max_ul"
    }
}

struct BridgeCategoryPayload: Decodable {
    let id: Int
    let title: String
    let path: String
    let comment: String
    let color: Int
    let priority: Int
}

struct BridgeFriendPayload: Decodable {
    let id: Int
    let name: String
    let hash: String
    let ip: String
    let port: Int
    let client: String
    let friendSlot: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case hash
        case ip
        case port
        case client
        case friendSlot = "friend_slot"
    }
}

struct BridgeStatsTreeNodePayload: Decodable {
    let id: Int
    let label: String
    let value: Double
    let children: [BridgeStatsTreeNodePayload]
}

struct BridgeStatsGraphSamplePayload: Decodable {
    let dl: Int
    let ul: Int
    let connections: Int
    let kad: Int
}

struct BridgeStatsGraphsPayload: Decodable {
    let last: Double
    let samples: [BridgeStatsGraphSamplePayload]
}

struct BridgeStatsPayload: Decodable {
    let tree: BridgeStatsTreeNodePayload?
    let graphs: BridgeStatsGraphsPayload?
}

struct BridgeEnvelope: Decodable {
    let ok: Bool
    let error: String?
    let message: String?
    let schemaVersion: Int?
    let capabilities: BridgeCapabilitiesPayload?
    let status: BridgeStatusPayload?
    let downloads: [BridgeDownloadPayload]?
    let sources: [BridgeDownloadSourcePayload]?
    let uploads: [BridgeUploadPayload]?
    let sharedFiles: [BridgeSharedFilePayload]?
    let log: BridgeCoreLogPayload?
    let prefsConnection: BridgeConnectionPrefsPayload?
    let categories: [BridgeCategoryPayload]?
    let friends: [BridgeFriendPayload]?
    let stats: BridgeStatsPayload?
    let servers: [BridgeServerPayload]?
    let progress: Int?
    let results: [BridgeSearchPayload]?

    private enum CodingKeys: String, CodingKey {
        case ok
        case error
        case message
        case schemaVersion = "schema_version"
        case capabilities
        case status
        case downloads
        case sources
        case uploads
        case sharedFiles = "shared_files"
        case log
        case prefsConnection = "prefs_connection"
        case categories
        case friends
        case stats
        case servers
        case progress
        case results
    }
}

enum AMuleECBridgeClient {
    private final class ThreadSafeDataBuffer: @unchecked Sendable {
        private let lock = NSLock()
        private var value = Data()

        func append(_ data: Data) {
            lock.lock()
            value.append(data)
            lock.unlock()
        }

        func snapshot() -> Data {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
    }

    static func connect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(op: "connect", extraArgs: [], config: config)
        return (envelope.message ?? "Connect requested", raw)
    }

    static func disconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(op: "disconnect", extraArgs: [], config: config)
        return (envelope.message ?? "Disconnect requested", raw)
    }

    static func status(config: AMuleConnectionConfig) async throws -> (BridgeStatusPayload, String) {
        let (envelope, raw) = try await invoke(op: "status", extraArgs: [], config: config)
        guard let status = envelope.status else {
            throw AMuleClientError.invalidResponse(raw)
        }
        return (status, raw)
    }

    static func downloads(config: AMuleConnectionConfig) async throws -> ([BridgeDownloadPayload], String) {
        let (envelope, raw) = try await invoke(op: "downloads", extraArgs: [], config: config)
        return (envelope.downloads ?? [], raw)
    }

    static func sources(hash: String, config: AMuleConnectionConfig) async throws -> ([BridgeDownloadSourcePayload], String) {
        let (envelope, raw) = try await invoke(op: "sources", extraArgs: ["--hash", hash], config: config)
        return (envelope.sources ?? [], raw)
    }

    static func servers(config: AMuleConnectionConfig) async throws -> ([BridgeServerPayload], String) {
        let (envelope, raw) = try await invoke(op: "servers", extraArgs: [], config: config)
        return (envelope.servers ?? [], raw)
    }

    static func search(
        scope: String,
        query: String,
        polls: Int,
        pollIntervalMs: Int,
        config: AMuleConnectionConfig
    ) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String) {
        let extra = [
            "--scope", scope,
            "--query", query,
            "--polls", String(max(1, polls)),
            "--poll-interval-ms", String(max(100, pollIntervalMs))
        ]
        let (envelope, raw) = try await invoke(op: "search", extraArgs: extra, config: config)
        return (envelope.progress ?? 0, envelope.results ?? [], raw)
    }

    static func searchStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(op: "search-stop", extraArgs: [], config: config)
        return (envelope.message ?? "Search stop requested", raw)
    }

    static func download(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(op: "download", extraArgs: ["--hash", hash], config: config)
        return (envelope.message ?? "Download request accepted", raw)
    }

    static func addLink(link: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(op: "add-link", extraArgs: ["--link", link], config: config)
        return (envelope.message ?? "Link add request accepted", raw)
    }

    static func rename(hash: String, name: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(
            op: "rename",
            extraArgs: ["--hash", hash, "--name", name],
            config: config
        )
        return (envelope.message ?? "Rename requested", raw)
    }

    static func pause(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(op: "pause", extraArgs: ["--hash", hash], config: config)
        return (envelope.message ?? "Pause requested", raw)
    }

    static func resume(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(op: "resume", extraArgs: ["--hash", hash], config: config)
        return (envelope.message ?? "Resume requested", raw)
    }

    static func cancel(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(op: "cancel", extraArgs: ["--hash", hash], config: config)
        return (envelope.message ?? "Cancel requested", raw)
    }

    static func priority(hash: String, value: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(
            op: "priority",
            extraArgs: ["--hash", hash, "--priority", value],
            config: config
        )
        return (envelope.message ?? "Priority changed", raw)
    }

    static func clearCompleted(ecids: [Int], config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        var extraArgs: [String] = []
        for ecid in ecids where ecid > 0 {
            extraArgs.append(contentsOf: ["--ecid", String(ecid)])
        }
        let (envelope, raw) = try await invoke(op: "clear-completed", extraArgs: extraArgs, config: config)
        return (envelope.message ?? "Completed downloads cleared", raw)
    }

    static func serverConnect(ip: String?, port: Int?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        var extraArgs: [String] = []
        if let ip, !ip.isEmpty, let port {
            extraArgs = ["--server-ip", ip, "--server-port", String(port)]
        }
        let (envelope, raw) = try await invoke(op: "server-connect", extraArgs: extraArgs, config: config)
        return (envelope.message ?? "Server connect requested", raw)
    }

    static func serverDisconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(op: "server-disconnect", extraArgs: [], config: config)
        return (envelope.message ?? "Server disconnect requested", raw)
    }

    static func serverAdd(address: String, name: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        var extraArgs: [String] = ["--server-address", address]
        if let name, !name.isEmpty {
            extraArgs += ["--server-name", name]
        }
        let (envelope, raw) = try await invoke(op: "server-add", extraArgs: extraArgs, config: config)
        return (envelope.message ?? "Server add requested", raw)
    }

    static func serverRemove(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(
            op: "server-remove",
            extraArgs: ["--server-ip", ip, "--server-port", String(port)],
            config: config
        )
        return (envelope.message ?? "Server remove requested", raw)
    }

    static func serverUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(
            op: "server-update-from-url",
            extraArgs: ["--server-url", url],
            config: config
        )
        return (envelope.message ?? "Server list update requested", raw)
    }

    static func kadUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(
            op: "kad-update-from-url",
            extraArgs: ["--kad-url", url],
            config: config
        )
        return (envelope.message ?? "Kad nodes update requested", raw)
    }

    static func capabilitiesEnvelope(config: AMuleConnectionConfig) async throws -> (BridgeEnvelope, String) {
        try await invoke(op: "capabilities", extraArgs: [], config: config)
    }

    static func capabilities(config: AMuleConnectionConfig) async throws -> (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String) {
        let (envelope, raw) = try await invoke(op: "capabilities", extraArgs: [], config: config)
        guard let capabilities = envelope.capabilities else {
            throw AMuleClientError.invalidResponse(raw)
        }
        return (envelope.schemaVersion, capabilities, raw)
    }

    static func uploads(config: AMuleConnectionConfig) async throws -> ([BridgeUploadPayload], String) {
        let (envelope, raw) = try await invoke(op: "uploads", extraArgs: [], config: config)
        return (envelope.uploads ?? [], raw)
    }

    static func sharedFiles(config: AMuleConnectionConfig) async throws -> ([BridgeSharedFilePayload], String) {
        let (envelope, raw) = try await invoke(op: "shared-files", extraArgs: [], config: config)
        return (envelope.sharedFiles ?? [], raw)
    }

    static func sharedFilesReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(op: "shared-files-reload", extraArgs: [], config: config)
        return (envelope.message ?? "Shared files reload requested", raw)
    }

    static func log(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) {
        let (envelope, raw) = try await invoke(op: "log", extraArgs: [], config: config)
        guard let payload = envelope.log else {
            throw AMuleClientError.invalidResponse(raw)
        }
        return (payload, raw)
    }

    static func debugLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) {
        let (envelope, raw) = try await invoke(op: "debug-log", extraArgs: [], config: config)
        guard let payload = envelope.log else {
            throw AMuleClientError.invalidResponse(raw)
        }
        return (payload, raw)
    }

    static func kadStart(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(op: "kad-start", extraArgs: [], config: config)
        return (envelope.message ?? "Kad start requested", raw)
    }

    static func kadStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(op: "kad-stop", extraArgs: [], config: config)
        return (envelope.message ?? "Kad stop requested", raw)
    }

    static func kadBootstrap(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(
            op: "kad-bootstrap",
            extraArgs: ["--server-ip", ip, "--server-port", String(port)],
            config: config
        )
        return (envelope.message ?? "Kad bootstrap requested", raw)
    }

    static func prefsConnectionGet(config: AMuleConnectionConfig) async throws -> (BridgeConnectionPrefsPayload, String) {
        let (envelope, raw) = try await invoke(op: "prefs-connection-get", extraArgs: [], config: config)
        guard let payload = envelope.prefsConnection else {
            throw AMuleClientError.invalidResponse(raw)
        }
        return (payload, raw)
    }

    static func prefsConnectionSet(maxDownload: Int, maxUpload: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(
            op: "prefs-connection-set",
            extraArgs: ["--max-dl", String(maxDownload), "--max-ul", String(maxUpload)],
            config: config
        )
        return (envelope.message ?? "Connection speed limits updated", raw)
    }

    static func categories(config: AMuleConnectionConfig) async throws -> ([BridgeCategoryPayload], String) {
        let (envelope, raw) = try await invoke(op: "categories", extraArgs: [], config: config)
        return (envelope.categories ?? [], raw)
    }

    static func categoryCreate(
        name: String,
        path: String,
        comment: String,
        color: Int,
        priority: Int,
        config: AMuleConnectionConfig
    ) async throws -> (message: String, raw: String) {
        let extraArgs = [
            "--name", name,
            "--category-path", path,
            "--category-comment", comment,
            "--category-color", String(color),
            "--category-priority", String(priority)
        ]
        let (envelope, raw) = try await invoke(op: "category-create", extraArgs: extraArgs, config: config)
        return (envelope.message ?? "Category create requested", raw)
    }

    static func categoryUpdate(
        categoryID: Int,
        name: String,
        path: String,
        comment: String,
        color: Int,
        priority: Int,
        config: AMuleConnectionConfig
    ) async throws -> (message: String, raw: String) {
        let extraArgs = [
            "--category", String(categoryID),
            "--name", name,
            "--category-path", path,
            "--category-comment", comment,
            "--category-color", String(color),
            "--category-priority", String(priority)
        ]
        let (envelope, raw) = try await invoke(op: "category-update", extraArgs: extraArgs, config: config)
        return (envelope.message ?? "Category update requested", raw)
    }

    static func categoryDelete(categoryID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(
            op: "category-delete",
            extraArgs: ["--category", String(categoryID)],
            config: config
        )
        return (envelope.message ?? "Category delete requested", raw)
    }

    static func downloadSetCategory(hash: String, categoryID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(
            op: "download-set-category",
            extraArgs: ["--hash", hash, "--category", String(categoryID)],
            config: config
        )
        return (envelope.message ?? "Download category update requested", raw)
    }

    static func ipfilterReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(op: "ipfilter-reload", extraArgs: [], config: config)
        return (envelope.message ?? "IP filter reload requested", raw)
    }

    static func ipfilterUpdate(url: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        var extraArgs: [String] = []
        if let url, !url.isEmpty {
            extraArgs = ["--ipfilter-url", url]
        }
        let (envelope, raw) = try await invoke(op: "ipfilter-update", extraArgs: extraArgs, config: config)
        return (envelope.message ?? "IP filter update requested", raw)
    }

    static func friends(config: AMuleConnectionConfig) async throws -> ([BridgeFriendPayload], String) {
        let (envelope, raw) = try await invoke(op: "friends", extraArgs: [], config: config)
        return (envelope.friends ?? [], raw)
    }

    static func friendRemove(friendID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(
            op: "friend-remove",
            extraArgs: ["--friend-id", String(friendID)],
            config: config
        )
        return (envelope.message ?? "Friend remove requested", raw)
    }

    static func friendSlot(friendID: Int, enabled: Bool, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(
            op: "friend-slot",
            extraArgs: ["--friend-id", String(friendID), "--friend-slot", enabled ? "1" : "0"],
            config: config
        )
        return (envelope.message ?? "Friend slot update requested", raw)
    }

    static func statsTree(capping: Int?, config: AMuleConnectionConfig) async throws -> (BridgeStatsTreeNodePayload, String) {
        var extraArgs: [String] = []
        if let capping {
            extraArgs = ["--stats-tree-capping", String(capping)]
        }
        let (envelope, raw) = try await invoke(op: "stats-tree", extraArgs: extraArgs, config: config)
        guard let payload = envelope.stats?.tree else {
            throw AMuleClientError.invalidResponse(raw)
        }
        return (payload, raw)
    }

    static func statsGraphs(width: Int, scale: Int, last: Double?, config: AMuleConnectionConfig) async throws -> (BridgeStatsGraphsPayload, String) {
        var extraArgs: [String] = ["--stats-width", String(width), "--stats-scale", String(scale)]
        if let last {
            extraArgs += ["--stats-last", String(last)]
        }
        let (envelope, raw) = try await invoke(op: "stats-graphs", extraArgs: extraArgs, config: config)
        guard let payload = envelope.stats?.graphs else {
            throw AMuleClientError.invalidResponse(raw)
        }
        return (payload, raw)
    }

    private static func invoke(
        op: String,
        extraArgs: [String],
        config: AMuleConnectionConfig
    ) async throws -> (BridgeEnvelope, String) {
        let arguments = [
            "--host", config.host,
            "--port", String(config.port),
            "--password", config.password,
            "--op", op
        ] + extraArgs

        let bridgePaths = candidateBridgePaths(primary: config.bridgePath)
        var lastError: Error?

        for (index, bridgePath) in bridgePaths.enumerated() {
            do {
                return try await invokeOnce(arguments: arguments, bridgePath: bridgePath)
            } catch {
                lastError = error
                let hasFallback = index + 1 < bridgePaths.count
                if !hasFallback || !shouldRetryWithFallback(after: error) {
                    throw error
                }
            }
        }

        throw lastError ?? AMuleClientError.invalidResponse("No bridge response")
    }

    private static func invokeOnce(arguments: [String], bridgePath: String) async throws -> (BridgeEnvelope, String) {
        let result = try await run(arguments: arguments, bridgePath: bridgePath)
        let envelope: BridgeEnvelope

        do {
            let parseInputs = [result.stdout, result.stderr, result.combinedOutput]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            var parsedEnvelope: BridgeEnvelope?
            var parseError: Error?

            for input in parseInputs {
                do {
                    parsedEnvelope = try parseEnvelope(from: input)
                    break
                } catch {
                    parseError = error
                }
            }

            if let parsedEnvelope {
                envelope = parsedEnvelope
            } else {
                if result.status != 0 {
                    throw AMuleClientError.processFailure(result.status, result.combinedOutput)
                }
                throw parseError ?? AMuleClientError.invalidResponse(result.combinedOutput)
            }
        } catch {
            if result.status != 0 {
                throw AMuleClientError.processFailure(result.status, result.combinedOutput)
            }
            throw error
        }

        if !envelope.ok {
            throw AMuleClientError.bridgeFailure(envelope.error ?? "Bridge request failed")
        }

        if result.status != 0 {
            throw AMuleClientError.processFailure(result.status, result.combinedOutput)
        }

        return (envelope, result.combinedOutput)
    }

    private static func candidateBridgePaths(primary: String) -> [String] {
        let fallback = AMuleConnectionConfig.preferredDefaultPath()
        if fallback == primary {
            return [primary]
        }
        return [primary, fallback]
    }

    private static func shouldRetryWithFallback(after error: Error) -> Bool {
        guard let clientError = error as? AMuleClientError else {
            return false
        }

        switch clientError {
        case .missingBridge:
            return true
        case .invalidResponse:
            return true
        case .processFailure:
            return true
        case let .bridgeFailure(message):
            let lowered = message.lowercased()
            return lowered.contains("not found") || lowered.contains("permission denied")
        }
    }

    private struct ProcessResult {
        let status: Int32
        let stdout: String
        let stderr: String

        var combinedOutput: String {
            let out = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            let err = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if out.isEmpty { return err }
            if err.isEmpty { return out }
            return out + "\n" + err
        }
    }

    private static func run(arguments: [String], bridgePath: String) async throws -> ProcessResult {
        guard let executablePath = resolveExecutablePath(bridgePath) else {
            throw AMuleClientError.missingBridge(bridgePath)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.environment = utf8ProcessEnvironment()

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let collectedStdout = ThreadSafeDataBuffer()
            let collectedStderr = ThreadSafeDataBuffer()
            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                collectedStdout.append(data)
            }
            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                collectedStderr.append(data)
            }

            process.terminationHandler = { process in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                let stdoutTail = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrTail = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                collectedStdout.append(stdoutTail)
                collectedStderr.append(stderrTail)

                let stdoutText = String(decoding: collectedStdout.snapshot(), as: UTF8.self)
                let stderrText = String(decoding: collectedStderr.snapshot(), as: UTF8.self)
                continuation.resume(
                    returning: ProcessResult(
                        status: process.terminationStatus,
                        stdout: stdoutText,
                        stderr: stderrText
                    )
                )
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func parseEnvelope(from output: String) throws -> BridgeEnvelope {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        var candidates: [String] = []

        if !trimmed.isEmpty {
            candidates.append(trimmed)
        }

        let lines = output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        candidates.append(contentsOf: lines.reversed())
        candidates.append(contentsOf: extractJSONObjects(from: output))

        let decoder = JSONDecoder()
        var seen = Set<String>()
        for candidate in candidates {
            let normalized = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { continue }
            guard seen.insert(normalized).inserted else { continue }

            if let data = normalized.data(using: .utf8),
               let envelope = try? decoder.decode(BridgeEnvelope.self, from: data) {
                return envelope
            }
        }

        if let likelyError = likelyBridgeError(from: output) {
            throw AMuleClientError.bridgeFailure(likelyError)
        }

        throw AMuleClientError.invalidResponse(output)
    }

    private static func extractJSONObjects(from output: String) -> [String] {
        var results: [String] = []
        var startIndex: String.Index?
        var depth = 0
        var inString = false
        var isEscaped = false
        var index = output.startIndex

        while index < output.endIndex {
            let ch = output[index]

            if inString {
                if isEscaped {
                    isEscaped = false
                } else if ch == "\\" {
                    isEscaped = true
                } else if ch == "\"" {
                    inString = false
                }
            } else {
                if ch == "\"" {
                    inString = true
                } else if ch == "{" {
                    if depth == 0 {
                        startIndex = index
                    }
                    depth += 1
                } else if ch == "}", depth > 0 {
                    depth -= 1
                    if depth == 0, let startIndex {
                        let candidate = output[startIndex...index]
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if !candidate.isEmpty {
                            results.append(candidate)
                        }
                    }
                }
            }

            index = output.index(after: index)
        }

        return results
    }

    private static func likelyBridgeError(from output: String) -> String? {
        let hints = [
            "could not connect",
            "missing --password",
            "wrong password",
            "unsupported --op",
            "not found",
            "permission denied"
        ]

        let lines = output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines.reversed() {
            let lowered = line.lowercased()
            if hints.contains(where: lowered.contains) {
                return line
            }
            if line.hasPrefix("Error:") {
                return line
            }
        }

        return nil
    }

    private static func resolveExecutablePath(_ bridgePath: String) -> String? {
        let fm = FileManager.default
        let expanded = (bridgePath as NSString).expandingTildeInPath

        if expanded.contains("/") {
            return fm.isExecutableFile(atPath: expanded) ? expanded : nil
        }

        let envPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for dir in envPath.split(separator: ":") {
            let fullPath = String(dir) + "/" + expanded
            if fm.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }

        return nil
    }

    private static func utf8ProcessEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        if env["LANG"]?.localizedCaseInsensitiveContains("UTF-8") != true {
            env["LANG"] = "en_US.UTF-8"
        }
        if env["LC_ALL"]?.localizedCaseInsensitiveContains("UTF-8") != true {
            env["LC_ALL"] = "en_US.UTF-8"
        }
        env["LC_CTYPE"] = "UTF-8"
        return env
    }
}
