import Foundation

struct BridgeStatusPayload: Decodable {
    let connected: Bool
    let ed2k: String
    let kad: String
    let downloadSpeed: Int
    let uploadSpeed: Int
    let queue: Int
    let sources: Int

    private enum CodingKeys: String, CodingKey {
        case connected, ed2k, kad, queue, sources
        case downloadSpeed = "download_speed"
        case uploadSpeed = "upload_speed"
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
        case ecid, hash, name, size, done, transferred, progress, status, speed, priority, category, shared
        case nameEncodingSuspect = "name_encoding_suspect"
        case nameEncodingSuggestion = "name_encoding_suggestion"
        case sourcesCurrent = "sources_current"
        case sourcesTotal = "sources_total"
        case sourcesTransferring = "sources_transferring"
        case sourcesA4AF = "sources_a4af"
        case statusCode = "status_code"
        case isCompleted = "is_completed"
        case partMet = "part_met"
        case lastSeenComplete = "last_seen_complete"
        case lastReceived = "last_received"
        case activeSeconds = "active_seconds"
        case availableParts = "available_parts"
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
        case software
        case clientID = "client_id"
        case requestFileID = "request_file_id"
        case clientName = "client_name"
        case userIP = "user_ip"
        case userPort = "user_port"
        case serverName = "server_name"
        case serverIP = "server_ip"
        case serverPort = "server_port"
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
        case id, hash, name, size, sources, status
        case completeSources = "complete_sources"
        case statusCode = "status_code"
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
        case id, name, description, version, address, ip, port, users, files, ping, failed, priority
        case maxUsers = "max_users"
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
        case hash, name, path, size, priority, requests, accepts, xferred, comment, rating
        case ed2kLink = "ed2k_link"
        case requestsAll = "requests_all"
        case acceptsAll = "accepts_all"
        case xferredAll = "xferred_all"
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
        case id, name, hash, ip, port, client
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
        case ok, error, message, capabilities, status, downloads, sources, uploads, log, categories, friends, stats, servers, progress, results
        case schemaVersion = "schema_version"
        case sharedFiles = "shared_files"
        case prefsConnection = "prefs_connection"
    }
}


struct DownloadAlternativeName: Hashable, Identifiable {
    let name: String
    let count: Int

    var id: String { "\(name)|\(count)" }
}

struct SearchResult: Identifiable, Hashable {
    let index: Int
    let hash: String
    let name: String
    let sizeBytes: UInt64
    let sources: Int
    let completeSources: Int
    let statusCode: Int
    let status: String
    let parentID: Int
    let alreadyHave: Bool

    var id: String { "\(index)" }

    var sizeDisplay: String {
        AMuleFormatter.fileSize(sizeBytes)
    }

    var alreadyHaveText: String {
        alreadyHave ? "Yes" : "No"
    }

    var haveSortValue: Int {
        alreadyHave ? 1 : 0
    }

    static func fromBridge(_ payload: [BridgeSearchPayload]) -> [SearchResult] {
        payload
            .sorted { $0.id < $1.id }
            .map {
                SearchResult(
                    index: $0.id,
                    hash: $0.hash,
                    name: $0.name,
                    sizeBytes: $0.size,
                    sources: $0.sources,
                    completeSources: $0.completeSources,
                    statusCode: $0.statusCode,
                    status: $0.status,
                    parentID: $0.parentID,
                    alreadyHave: $0.alreadyHave
                )
            }
    }
}

struct DownloadItem: Identifiable, Hashable {
    let ecid: Int
    let id: String
    let name: String
    let nameEncodingSuspect: Bool
    let nameEncodingSuggestion: String?
    let sizeBytes: UInt64
    let doneBytes: UInt64
    let transferredBytes: UInt64
    let progressValue: Double
    let sourceCurrent: Int
    let sourceTotal: Int
    let sourceTransferring: Int
    let sourceA4AF: Int
    let statusCode: Int
    let isCompleted: Bool
    let status: String
    let speedBytes: Int
    let priority: Int
    let category: Int
    let partMetName: String
    let lastSeenComplete: UInt64
    let lastReceived: UInt64
    let activeSeconds: Int
    let availableParts: Int
    let shared: Bool
    let alternativeNames: [DownloadAlternativeName]
    let progressColors: [UInt32]

    var meaningfulNameEncodingSuggestion: String? {
        guard let suggestion = nameEncodingSuggestion else { return nil }
        let trimmedSuggestion = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSuggestion.isEmpty else { return nil }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedSuggestion == trimmedName ? nil : trimmedSuggestion
    }

    var hasMeaningfulNameEncodingSuggestion: Bool {
        meaningfulNameEncodingSuggestion != nil
    }

    var trimmedDisplayName: String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? nil : trimmedName
    }

    func displayedNameEncodingValue(alwaysShowDiagnostic: Bool) -> String? {
        if let suggestion = meaningfulNameEncodingSuggestion {
            return suggestion
        }

        guard alwaysShowDiagnostic else { return nil }
        return trimmedDisplayName
    }

    func usesDiagnosticNameEncodingFallback(alwaysShowDiagnostic: Bool) -> Bool {
        meaningfulNameEncodingSuggestion == nil && displayedNameEncodingValue(alwaysShowDiagnostic: alwaysShowDiagnostic) != nil
    }

    func hasDisplayedNameEncodingValue(alwaysShowDiagnostic: Bool) -> Bool {
        displayedNameEncodingValue(alwaysShowDiagnostic: alwaysShowDiagnostic) != nil
    }

    var progressDisplayValue: Double {
        let clamped = max(0, min(progressValue, 100))
        return floor(clamped * 10.0) / 10.0
    }

    var progressSortValue: Double {
        max(0, min(progressValue, 100))
    }

    var isCompletedLike: Bool {
        if isCompleted || statusCode == 9 {
            return true
        }
        if sizeBytes > 0 && doneBytes >= sizeBytes {
            return true
        }
        return false
    }

    var speedSortValue: Int {
        if speedBytes > 0 {
            // Sort priority for descending speed:
            // 1) actively downloading (with speed),
            // 2) completed (no speed),
            // 3) non-completed idle items.
            return 2_000_000_000 + max(0, speedBytes)
        }
        if isCompletedLike {
            return 1_000_000_000
        }
        return 0
    }

    var progressText: String {
        String(format: "%.1f%%", progressDisplayValue)
    }

    var sourcesText: String {
        "\(sourceCurrent)/\(sourceTotal)"
    }

    var speedText: String {
        AMuleFormatter.speed(bytesPerSecond: speedBytes)
    }

    var completionText: String {
        "\(AMuleFormatter.fileSize(doneBytes)) / \(AMuleFormatter.fileSize(sizeBytes))"
    }

    var transferredText: String {
        AMuleFormatter.fileSize(transferredBytes)
    }

    var activeTimeText: String {
        AMuleFormatter.duration(seconds: activeSeconds)
    }

    var lastSeenCompleteText: String {
        AMuleFormatter.dateTime(unix: lastSeenComplete)
    }

    var lastReceivedText: String {
        AMuleFormatter.dateTime(unix: lastReceived)
    }

    var priorityText: String {
        AMuleFormatter.priority(priority)
    }

    var ed2kLink: String {
        let sanitizedName = name
            .replacingOccurrences(of: "|", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
        let encodedName = sanitizedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? sanitizedName
        return "ed2k://|file|\(encodedName)|\(sizeBytes)|\(id)|/"
    }

    static func fromBridge(_ payload: [BridgeDownloadPayload]) -> [DownloadItem] {
        payload.map {
            DownloadItem(
                ecid: $0.ecid,
                id: $0.hash,
                name: $0.name,
                nameEncodingSuspect: $0.nameEncodingSuspect,
                nameEncodingSuggestion: $0.nameEncodingSuggestion,
                sizeBytes: $0.size,
                doneBytes: $0.done,
                transferredBytes: $0.transferred,
                progressValue: $0.progress,
                sourceCurrent: $0.sourcesCurrent,
                sourceTotal: $0.sourcesTotal,
                sourceTransferring: $0.sourcesTransferring,
                sourceA4AF: $0.sourcesA4AF,
                statusCode: $0.statusCode,
                isCompleted: $0.isCompleted,
                status: $0.status,
                speedBytes: $0.speed,
                priority: $0.priority,
                category: $0.category,
                partMetName: $0.partMet,
                lastSeenComplete: $0.lastSeenComplete,
                lastReceived: $0.lastReceived,
                activeSeconds: $0.activeSeconds,
                availableParts: $0.availableParts,
                shared: $0.shared,
                alternativeNames: $0.alternativeNames.map {
                    DownloadAlternativeName(name: $0.name, count: $0.count)
                },
                progressColors: $0.progressColors ?? []
            )
        }
    }
}

struct DownloadSourceItem: Identifiable, Hashable {
    let id: Int
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

    var clientDisplayName: String {
        clientName.isEmpty ? "(unknown client)" : clientName
    }

    var endpoint: String {
        if !userIP.isEmpty, userPort > 0 {
            return "\(userIP):\(userPort)"
        }
        if !userIP.isEmpty {
            return userIP
        }
        return "-"
    }

    var serverEndpoint: String {
        let endpoint: String
        if !serverIP.isEmpty, serverPort > 0 {
            endpoint = "\(serverIP):\(serverPort)"
        } else if !serverIP.isEmpty {
            endpoint = serverIP
        } else {
            endpoint = "-"
        }

        if serverName.isEmpty {
            return endpoint
        }
        return serverName + (endpoint == "-" ? "" : " (\(endpoint))")
    }

    var softwareDisplay: String {
        if softwareVersion.isEmpty {
            return software
        }
        return "\(software) \(softwareVersion)"
    }

    var speedText: String {
        guard downSpeedKBps > 0 else { return "-" }
        let bytesPerSecond = Int((downSpeedKBps * 1024.0).rounded())
        return AMuleFormatter.speed(bytesPerSecond: bytesPerSecond)
    }

    var queueRankText: String {
        remoteQueueRank == 0xffff ? "Full" : String(remoteQueueRank)
    }

    static func fromBridge(_ payload: [BridgeDownloadSourcePayload]) -> [DownloadSourceItem] {
        payload.map {
            DownloadSourceItem(
                id: $0.clientID,
                requestFileID: $0.requestFileID,
                clientName: $0.clientName,
                userIP: $0.userIP,
                userPort: $0.userPort,
                serverName: $0.serverName,
                serverIP: $0.serverIP,
                serverPort: $0.serverPort,
                software: $0.software,
                softwareVersion: $0.softwareVersion,
                downloadState: $0.downloadState,
                downloadStateText: $0.downloadStateText,
                sourceFrom: $0.sourceFrom,
                sourceFromText: $0.sourceFromText,
                downSpeedKBps: $0.downSpeedKBps,
                availableParts: $0.availableParts,
                remoteQueueRank: $0.remoteQueueRank,
                obfuscationStatus: $0.obfuscationStatus,
                extendedProtocol: $0.extendedProtocol,
                remoteFilename: $0.remoteFilename
            )
        }
    }
}

struct ServerItem: Identifiable, Hashable {
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

    var endpointText: String {
        if !address.isEmpty {
            return address
        }
        if !ip.isEmpty {
            return port > 0 ? "\(ip):\(port)" : ip
        }
        return "-"
    }

    var usersText: String {
        if maxUsers > 0 {
            return "\(users)/\(maxUsers)"
        }
        return String(users)
    }

    static func fromBridge(_ payload: [BridgeServerPayload]) -> [ServerItem] {
        payload.map {
            ServerItem(
                id: $0.id,
                name: $0.name,
                description: $0.description,
                version: $0.version,
                address: $0.address,
                ip: $0.ip,
                port: $0.port,
                users: $0.users,
                maxUsers: $0.maxUsers,
                files: $0.files,
                ping: $0.ping,
                failed: $0.failed,
                priority: $0.priority,
                isStatic: $0.isStatic
            )
        }
    }
}

enum AMuleFormatter {
    static func speed(bytesPerSecond: Int) -> String {
        guard bytesPerSecond > 0 else {
            return "-"
        }
        let text = ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .binary)
            .replacingOccurrences(of: " bytes", with: " B")
            .replacingOccurrences(of: " byte", with: " B")
        return "\(text)/s"
    }

    static func fileSize(_ bytes: UInt64) -> String {
        if bytes > UInt64(Int64.max) {
            return ByteCountFormatter.string(fromByteCount: Int64.max, countStyle: .file)
        }
        return fileSize(Int64(bytes))
    }

    static func fileSize(_ bytes: Int64) -> String {
        guard bytes > 0 else {
            return "-"
        }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func duration(seconds: Int) -> String {
        guard seconds > 0 else {
            return "-"
        }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%02dh %02dm %02ds", hours, minutes, secs)
        }
        return String(format: "%02dm %02ds", minutes, secs)
    }

    static func dateTime(unix: UInt64) -> String {
        guard unix > 0 else {
            return "-"
        }
        let date = Date(timeIntervalSince1970: TimeInterval(unix))
        return date.formatted(date: .numeric, time: .standard)
    }

    static func priority(_ value: Int) -> String {
        switch value {
        case 0: return "Low"
        case 1: return "Normal"
        case 2: return "High"
        case 10: return "Auto (Low)"
        case 11: return "Auto (Normal)"
        case 12: return "Auto (High)"
        default: return String(value)
        }
    }
}
