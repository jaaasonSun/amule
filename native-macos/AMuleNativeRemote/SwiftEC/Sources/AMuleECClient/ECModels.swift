import Foundation
import AMuleECProtocol

public enum ECOperationName: String, CaseIterable, Codable, Sendable {
    case capabilities
    case status
    case downloads
    case sources
    case servers
    case search
    case searchStop = "search-stop"
    case download
    case addLink = "add-link"
    case connect
    case disconnect
    case pause
    case resume
    case rename
    case cancel
    case priority
    case clearCompleted = "clear-completed"
    case serverConnect = "server-connect"
    case serverDisconnect = "server-disconnect"
    case serverAdd = "server-add"
    case serverRemove = "server-remove"
    case serverUpdateFromURL = "server-update-from-url"
    case kadStart = "kad-start"
    case kadStop = "kad-stop"
    case kadBootstrap = "kad-bootstrap"
    case kadUpdateFromURL = "kad-update-from-url"
    case prefsConnectionGet = "prefs-connection-get"
    case prefsConnectionSet = "prefs-connection-set"
    case uploads
    case sharedFiles = "shared-files"
    case sharedFilesReload = "shared-files-reload"
    case log
    case debugLog = "debug-log"
    case categories
    case categoryCreate = "category-create"
    case categoryUpdate = "category-update"
    case categoryDelete = "category-delete"
    case downloadSetCategory = "download-set-category"
    case ipfilterReload = "ipfilter-reload"
    case ipfilterUpdate = "ipfilter-update"
    case friends
    case friendRemove = "friend-remove"
    case friendSlot = "friend-slot"
    case statsTree = "stats-tree"
    case statsGraphs = "stats-graphs"
}

public struct ECCapabilities: Codable, Equatable, Sendable {
    public let bridgeVersion: String
    public let clientName: String
    public let defaultHost: String
    public let defaultPort: Int
    public let ops: [String]

    public init(
        bridgeVersion: String = "SwiftEC",
        clientName: String = "SwiftEC",
        defaultHost: String = "127.0.0.1",
        defaultPort: Int = 4712,
        ops: [String] = ECSupportedOps.allOperations
    ) {
        self.bridgeVersion = bridgeVersion
        self.clientName = clientName
        self.defaultHost = defaultHost
        self.defaultPort = defaultPort
        self.ops = ops
    }

    private enum CodingKeys: String, CodingKey {
        case bridgeVersion = "bridge_version"
        case clientName = "client_name"
        case defaultHost = "default_host"
        case defaultPort = "default_port"
        case ops
    }
}

public struct ECSearchResult: Codable, Equatable, Sendable {
    public let id: Int
    public let hash: String
    public let name: String
    public let size: UInt64
    public let sources: Int
    public let completeSources: Int
    public let statusCode: Int
    public let status: String
    public let parentID: Int
    public let alreadyHave: Bool

    public init(id: Int, hash: String, name: String, size: UInt64, sources: Int, completeSources: Int, statusCode: Int, status: String, parentID: Int, alreadyHave: Bool) {
        self.id = id
        self.hash = hash
        self.name = name
        self.size = size
        self.sources = sources
        self.completeSources = completeSources
        self.statusCode = statusCode
        self.status = status
        self.parentID = parentID
        self.alreadyHave = alreadyHave
    }

    private enum CodingKeys: String, CodingKey {
        case id, hash, name, size, sources, status
        case completeSources = "complete_sources"
        case statusCode = "status_code"
        case parentID = "parent_id"
        case alreadyHave = "already_have"
    }
}

public struct ECConnectionPrefs: Codable, Equatable, Sendable {
    public let maxDownload: Int
    public let maxUpload: Int

    public init(maxDownload: Int, maxUpload: Int) {
        self.maxDownload = maxDownload
        self.maxUpload = maxUpload
    }

    private enum CodingKeys: String, CodingKey {
        case maxDownload = "max_dl"
        case maxUpload = "max_ul"
    }
}

public struct ECStatus: Codable, Equatable, Sendable {
    public let connected: Bool
    public let ed2k: String
    public let kad: String
    public let downloadSpeed: Int
    public let uploadSpeed: Int
    public let queue: Int
    public let sources: Int

    public init(connected: Bool, ed2k: String, kad: String, downloadSpeed: Int, uploadSpeed: Int, queue: Int, sources: Int) {
        self.connected = connected
        self.ed2k = ed2k
        self.kad = kad
        self.downloadSpeed = downloadSpeed
        self.uploadSpeed = uploadSpeed
        self.queue = queue
        self.sources = sources
    }

    private enum CodingKeys: String, CodingKey {
        case connected, ed2k, kad, queue, sources
        case downloadSpeed = "download_speed"
        case uploadSpeed = "upload_speed"
    }
}

public struct ECDownload: Codable, Equatable, Sendable {
    public struct AlternativeName: Codable, Equatable, Sendable {
        public let name: String
        public let count: Int

        public init(name: String, count: Int) {
            self.name = name
            self.count = count
        }
    }

    public let ecid: Int
    public let hash: String
    public let name: String
    public let nameEncodingSuspect: Bool
    public let nameEncodingSuggestion: String?
    public let size: UInt64
    public let done: UInt64
    public let transferred: UInt64
    public let progress: Double
    public let sourcesCurrent: Int
    public let sourcesTotal: Int
    public let sourcesTransferring: Int
    public let sourcesA4AF: Int
    public let statusCode: Int
    public let isCompleted: Bool
    public let status: String
    public let speed: Int
    public let priority: Int
    public let category: Int
    public let partMet: String
    public let lastSeenComplete: UInt64
    public let lastReceived: UInt64
    public let activeSeconds: Int
    public let availableParts: Int
    public let shared: Bool
    public let alternativeNames: [AlternativeName]
    public let progressColors: [UInt32]

    public init(
        ecid: Int,
        hash: String,
        name: String,
        nameEncodingSuspect: Bool = false,
        nameEncodingSuggestion: String? = nil,
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
        alternativeNames: [AlternativeName] = [],
        progressColors: [UInt32] = []
    ) {
        let repairedName = FileNameEncodingRepair.repairedSuggestion(for: name)
        let trimmedSuggestion = nameEncodingSuggestion?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveSuggestion = (trimmedSuggestion?.isEmpty == false && trimmedSuggestion != name)
            ? trimmedSuggestion
            : repairedName

        self.ecid = ecid
        self.hash = hash
        self.name = name
        self.nameEncodingSuspect = nameEncodingSuspect || effectiveSuggestion != nil
        self.nameEncodingSuggestion = effectiveSuggestion
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.ecid = try container.decode(Int.self, forKey: .ecid)
        self.hash = try container.decode(String.self, forKey: .hash)
        self.name = try container.decode(String.self, forKey: .name)
        let decodedNameEncodingSuspect = try container.decodeIfPresent(Bool.self, forKey: .nameEncodingSuspect) ?? false
        let decodedNameEncodingSuggestion = try container.decodeIfPresent(String.self, forKey: .nameEncodingSuggestion)
        let repairedName = FileNameEncodingRepair.repairedSuggestion(for: self.name)
        let trimmedSuggestion = decodedNameEncodingSuggestion?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveSuggestion = (trimmedSuggestion?.isEmpty == false && trimmedSuggestion != self.name)
            ? trimmedSuggestion
            : repairedName
        self.nameEncodingSuspect = decodedNameEncodingSuspect || effectiveSuggestion != nil
        self.nameEncodingSuggestion = effectiveSuggestion
        self.size = try container.decode(UInt64.self, forKey: .size)
        self.done = try container.decode(UInt64.self, forKey: .done)
        self.transferred = try container.decode(UInt64.self, forKey: .transferred)
        self.progress = try container.decode(Double.self, forKey: .progress)
        self.sourcesCurrent = try container.decode(Int.self, forKey: .sourcesCurrent)
        self.sourcesTotal = try container.decode(Int.self, forKey: .sourcesTotal)
        self.sourcesTransferring = try container.decode(Int.self, forKey: .sourcesTransferring)
        self.sourcesA4AF = try container.decode(Int.self, forKey: .sourcesA4AF)
        self.statusCode = try container.decode(Int.self, forKey: .statusCode)
        self.isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        self.status = try container.decode(String.self, forKey: .status)
        self.speed = try container.decode(Int.self, forKey: .speed)
        self.priority = try container.decode(Int.self, forKey: .priority)
        self.category = try container.decode(Int.self, forKey: .category)
        self.partMet = try container.decode(String.self, forKey: .partMet)
        self.lastSeenComplete = try container.decode(UInt64.self, forKey: .lastSeenComplete)
        self.lastReceived = try container.decode(UInt64.self, forKey: .lastReceived)
        self.activeSeconds = try container.decode(Int.self, forKey: .activeSeconds)
        self.availableParts = try container.decode(Int.self, forKey: .availableParts)
        self.shared = try container.decode(Bool.self, forKey: .shared)
        self.alternativeNames = try container.decodeIfPresent([AlternativeName].self, forKey: .alternativeNames) ?? []
        self.progressColors = try container.decodeIfPresent([UInt32].self, forKey: .progressColors) ?? []
    }
}

public struct ECSource: Codable, Equatable, Sendable {
    public let clientID: Int
    public let requestFileID: Int
    public let clientName: String
    public let userIP: String
    public let userPort: Int
    public let serverName: String
    public let serverIP: String
    public let serverPort: Int
    public let software: String
    public let softwareVersion: String
    public let downloadState: Int
    public let downloadStateText: String
    public let sourceFrom: Int
    public let sourceFromText: String
    public let downSpeedKBps: Double
    public let availableParts: Int
    public let remoteQueueRank: Int
    public let obfuscationStatus: Int
    public let extendedProtocol: Bool
    public let remoteFilename: String

    public init(clientID: Int, requestFileID: Int, clientName: String, userIP: String, userPort: Int, serverName: String, serverIP: String, serverPort: Int, software: String, softwareVersion: String, downloadState: Int, downloadStateText: String, sourceFrom: Int, sourceFromText: String, downSpeedKBps: Double, availableParts: Int, remoteQueueRank: Int, obfuscationStatus: Int, extendedProtocol: Bool, remoteFilename: String) {
        self.clientID = clientID
        self.requestFileID = requestFileID
        self.clientName = clientName
        self.userIP = userIP
        self.userPort = userPort
        self.serverName = serverName
        self.serverIP = serverIP
        self.serverPort = serverPort
        self.software = software
        self.softwareVersion = softwareVersion
        self.downloadState = downloadState
        self.downloadStateText = downloadStateText
        self.sourceFrom = sourceFrom
        self.sourceFromText = sourceFromText
        self.downSpeedKBps = downSpeedKBps
        self.availableParts = availableParts
        self.remoteQueueRank = remoteQueueRank
        self.obfuscationStatus = obfuscationStatus
        self.extendedProtocol = extendedProtocol
        self.remoteFilename = remoteFilename
    }

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

public struct ECServer: Codable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let description: String
    public let version: String
    public let address: String
    public let ip: String
    public let port: Int
    public let users: Int
    public let maxUsers: Int
    public let files: Int
    public let ping: Int
    public let failed: Int
    public let priority: Int
    public let isStatic: Bool

    public init(id: Int, name: String, description: String, version: String, address: String, ip: String, port: Int, users: Int, maxUsers: Int, files: Int, ping: Int, failed: Int, priority: Int, isStatic: Bool) {
        self.id = id
        self.name = name
        self.description = description
        self.version = version
        self.address = address
        self.ip = ip
        self.port = port
        self.users = users
        self.maxUsers = maxUsers
        self.files = files
        self.ping = ping
        self.failed = failed
        self.priority = priority
        self.isStatic = isStatic
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, description, version, address, ip, port, users, files, ping, failed, priority
        case maxUsers = "max_users"
        case isStatic = "is_static"
    }
}

public struct ECUpload: Codable, Equatable, Sendable {
    public let clientID: Int
    public let clientName: String
    public let userIP: String
    public let userPort: Int
    public let serverIP: String
    public let serverPort: Int
    public let serverName: String
    public let speedUp: Int
    public let xferUp: UInt64
    public let xferDown: UInt64
    public let uploadFile: Int?

    public init(clientID: Int, clientName: String, userIP: String, userPort: Int, serverIP: String, serverPort: Int, serverName: String, speedUp: Int, xferUp: UInt64, xferDown: UInt64, uploadFile: Int?) {
        self.clientID = clientID
        self.clientName = clientName
        self.userIP = userIP
        self.userPort = userPort
        self.serverIP = serverIP
        self.serverPort = serverPort
        self.serverName = serverName
        self.speedUp = speedUp
        self.xferUp = xferUp
        self.xferDown = xferDown
        self.uploadFile = uploadFile
    }

    private enum CodingKeys: String, CodingKey {
        case speedUp = "speed_up"
        case xferUp = "xfer_up"
        case xferDown = "xfer_down"
        case clientID = "client_id"
        case clientName = "client_name"
        case userIP = "user_ip"
        case userPort = "user_port"
        case serverIP = "server_ip"
        case serverPort = "server_port"
        case serverName = "server_name"
        case uploadFile = "upload_file"
    }
}

public struct ECSharedFile: Codable, Equatable, Sendable {
    public let hash: String
    public let name: String
    public let path: String
    public let size: UInt64
    public let ed2kLink: String
    public let priority: Int
    public let requests: Int
    public let requestsAll: Int
    public let accepts: Int
    public let acceptsAll: Int
    public let xferred: UInt64
    public let xferredAll: UInt64
    public let comment: String?
    public let rating: Int?

    public init(hash: String, name: String, path: String, size: UInt64, ed2kLink: String, priority: Int, requests: Int, requestsAll: Int, accepts: Int, acceptsAll: Int, xferred: UInt64, xferredAll: UInt64, comment: String?, rating: Int?) {
        self.hash = hash
        self.name = name
        self.path = path
        self.size = size
        self.ed2kLink = ed2kLink
        self.priority = priority
        self.requests = requests
        self.requestsAll = requestsAll
        self.accepts = accepts
        self.acceptsAll = acceptsAll
        self.xferred = xferred
        self.xferredAll = xferredAll
        self.comment = comment
        self.rating = rating
    }

    private enum CodingKeys: String, CodingKey {
        case hash, name, path, size, priority, requests, accepts, xferred, comment, rating
        case ed2kLink = "ed2k_link"
        case requestsAll = "requests_all"
        case acceptsAll = "accepts_all"
        case xferredAll = "xferred_all"
    }
}

public struct ECCoreLog: Codable, Equatable, Sendable {
    public let kind: String
    public let lines: [String]

    public init(kind: String, lines: [String]) {
        self.kind = kind
        self.lines = lines
    }
}

public struct ECCategory: Codable, Equatable, Sendable {
    public let id: Int
    public let title: String
    public let path: String
    public let comment: String
    public let color: Int
    public let priority: Int

    public init(id: Int, title: String, path: String, comment: String, color: Int, priority: Int) {
        self.id = id
        self.title = title
        self.path = path
        self.comment = comment
        self.color = color
        self.priority = priority
    }
}

public struct ECFriend: Codable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let hash: String
    public let ip: String
    public let port: Int
    public let client: String
    public let friendSlot: Bool

    public init(id: Int, name: String, hash: String, ip: String, port: Int, client: String, friendSlot: Bool) {
        self.id = id
        self.name = name
        self.hash = hash
        self.ip = ip
        self.port = port
        self.client = client
        self.friendSlot = friendSlot
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, hash, ip, port, client
        case friendSlot = "friend_slot"
    }
}

public struct ECStatsTreeNode: Codable, Equatable, Sendable {
    public let id: Int
    public let label: String
    public let value: Double
    public let children: [ECStatsTreeNode]

    public init(id: Int, label: String, value: Double, children: [ECStatsTreeNode]) {
        self.id = id
        self.label = label
        self.value = value
        self.children = children
    }
}

public struct ECStatsGraphSample: Codable, Equatable, Sendable {
    public let dl: Int
    public let ul: Int
    public let connections: Int
    public let kad: Int

    public init(dl: Int, ul: Int, connections: Int, kad: Int) {
        self.dl = dl
        self.ul = ul
        self.connections = connections
        self.kad = kad
    }
}

public struct ECStatsGraphs: Codable, Equatable, Sendable {
    public let last: Double
    public let samples: [ECStatsGraphSample]

    public init(last: Double, samples: [ECStatsGraphSample]) {
        self.last = last
        self.samples = samples
    }
}
