import Foundation
import AMuleECProtocol

public enum ECOperationError: Error, Equatable, LocalizedError, Sendable {
    case unsupportedOperation(String)
    case invalidHash(String)
    case invalidServerEndpoint(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedOperation(let operation): return "Unsupported operation: \(operation)"
        case .invalidHash(let hash): return "Invalid hash: \(hash)"
        case .invalidServerEndpoint(let endpoint): return "Invalid server endpoint: \(endpoint)"
        }
    }
}

public struct ECCapabilityGate: Equatable, Sendable {
    public let supportedOps: Set<String>

    public init(_ supportedOps: some Sequence<String>) {
        self.supportedOps = Set(supportedOps)
    }

    public init(capabilities: ECCapabilities) {
        self.supportedOps = Set(capabilities.ops)
    }

    public func require(_ operation: ECOperationName) throws {
        guard supportedOps.contains(operation.rawValue) else {
            throw ECOperationError.unsupportedOperation(operation.rawValue)
        }
    }
}

public enum ECOperations {
    public enum A4AFSwapMode: Sendable, Equatable {
        case toThis
        case toThisAuto
        case toAnyOther
    }

    public enum OpCode {
        public static let noop: UInt8 = 0x01
        public static let failed: UInt8 = 0x05
        public static let strings: UInt8 = 0x06
        public static let miscData: UInt8 = 0x07
        public static let shutdown: UInt8 = 0x08
        public static let statRequest: UInt8 = 0x0A
        public static let getConnectionState: UInt8 = 0x0B
        public static let stats: UInt8 = 0x0C
        public static let addLink: UInt8 = 0x09
        public static let getLastLogEntry: UInt8 = 0x3E
        public static let resetDebugLog: UInt8 = 0x3C
        public static let sharedSetPriority: UInt8 = 0x11
        public static let partFileSwapA4AFThis: UInt8 = 0x16
        public static let partFileSwapA4AFThisAuto: UInt8 = 0x17
        public static let partFileSwapA4AFOthers: UInt8 = 0x18
        public static let partFilePause: UInt8 = 0x19
        public static let partFileResume: UInt8 = 0x1A
        public static let partFileStop: UInt8 = 0x1B
        public static let searchStart: UInt8 = 0x26
        public static let searchStop: UInt8 = 0x27
        public static let searchResults: UInt8 = 0x28
        public static let searchProgress: UInt8 = 0x29
        public static let clientSwapToAnotherFile: UInt8 = 0x2A
        public static let downloadSearchResult: UInt8 = 0x2A
        public static let getDownloadQueue: UInt8 = 0x0D
        public static let downloadQueue: UInt8 = 0x1F
        public static let getServerList: UInt8 = 0x2C
        public static let serverList: UInt8 = 0x2D
        public static let serverDisconnect: UInt8 = 0x2E
        public static let serverConnect: UInt8 = 0x2F
        public static let serverRemove: UInt8 = 0x30
        public static let serverAdd: UInt8 = 0x31
        public static let partFileDelete: UInt8 = 0x1D
        public static let partFilePrioSet: UInt8 = 0x1C
        public static let partFileSetCat: UInt8 = 0x1E
        public static let renameFile: UInt8 = 0x25
        public static let getUploadQueue: UInt8 = 0x0E
        public static let uploadQueue: UInt8 = 0x20
        public static let getSharedFiles: UInt8 = 0x10
        public static let sharedFiles: UInt8 = 0x22
        public static let sharedFilesReload: UInt8 = 0x23
        public static let getStatsGraphs: UInt8 = 0x44
        public static let statsGraphs: UInt8 = 0x45
        public static let getStatsTree: UInt8 = 0x46
        public static let statsTree: UInt8 = 0x47
        public static let kadStart: UInt8 = 0x48
        public static let kadStop: UInt8 = 0x49
        public static let kadBootstrapFromIP: UInt8 = 0x4E
        public static let kadUpdateFromURL: UInt8 = 0x4D
        public static let getPreferences: UInt8 = 0x3F
        public static let setPreferences: UInt8 = 0x40
        public static let createCategory: UInt8 = 0x41
        public static let updateCategory: UInt8 = 0x42
        public static let deleteCategory: UInt8 = 0x43
        public static let ipfilterReload: UInt8 = 0x2B
        public static let ipfilterUpdate: UInt8 = 0x51
        public static let getLog: UInt8 = 0x35
        public static let log: UInt8 = 0x38
        public static let getDebugLog: UInt8 = 0x36
        public static let debugLog: UInt8 = 0x39
        public static let getServerInfo: UInt8 = 0x37
        public static let serverInfo: UInt8 = 0x3A
        public static let resetLog: UInt8 = 0x3B
        public static let clearServerInfo: UInt8 = 0x3D
        public static let clearCompleted: UInt8 = 0x53
        public static let sharedFileSetComment: UInt8 = 0x55
        public static let serverSetStaticPriority: UInt8 = 0x56
        public static let friend: UInt8 = 0x57
        public static let connect: UInt8 = 0x4A
        public static let disconnect: UInt8 = 0x4B
        public static let getUpdate: UInt8 = 0x52
        public static let serverUpdateFromURL: UInt8 = 0x32
    }

    public enum DetailLevel: UInt64 {
        case command = 0x00
        case full = 0x02
        case incrementalUpdate = 0x04
    }

    public enum TagName {
        public static let detailLevel: UInt16 = 0x0004
        public static let string: UInt16 = 0x0000
        public static let partFile: UInt16 = 0x0300
        public static let partFileName: UInt16 = 0x0301
        public static let partFilePriority: UInt16 = 0x0309
        public static let partFileCategory: UInt16 = 0x030F
        public static let knownFile: UInt16 = 0x0400
        public static let ecid: UInt16 = 0x000F
        public static let server: UInt16 = 0x0500
        public static let serverName: UInt16 = 0x0501
        public static let serverAddress: UInt16 = 0x0503
        public static let serverPriority: UInt16 = 0x0508
        public static let serverStatic: UInt16 = 0x050A
        public static let serverIP: UInt16 = 0x050C
        public static let serverPort: UInt16 = 0x050D
        public static let searchType: UInt16 = 0x0701
        public static let searchName: UInt16 = 0x0702
        public static let searchMinSize: UInt16 = 0x0703
        public static let searchMaxSize: UInt16 = 0x0704
        public static let searchFileType: UInt16 = 0x0705
        public static let searchExtension: UInt16 = 0x0706
        public static let searchAvailability: UInt16 = 0x0707
        public static let selectPrefs: UInt16 = 0x1000
        public static let prefsGeneral: UInt16 = 0x1200
        public static let prefsConnections: UInt16 = 0x1300
        public static let connMaxDownload: UInt16 = 0x1303
        public static let connMaxUpload: UInt16 = 0x1304
        public static let connTCPPort: UInt16 = 0x1306
        public static let connUDPPort: UInt16 = 0x1307
        public static let connUDPDisable: UInt16 = 0x1308
        public static let networkED2K: UInt16 = 0x130D
        public static let networkKademlia: UInt16 = 0x130E
        public static let prefsMessageFilter: UInt16 = 0x1400
        public static let prefsRemoteControls: UInt16 = 0x1500
        public static let webServerAutorun: UInt16 = 0x1501
        public static let webServerPort: UInt16 = 0x1502
        public static let webServerGuest: UInt16 = 0x1503
        public static let webServerUseGzip: UInt16 = 0x1504
        public static let webServerRefresh: UInt16 = 0x1505
        public static let webServerTemplate: UInt16 = 0x1506
        public static let prefsOnlineSignature: UInt16 = 0x1600
        public static let prefsServers: UInt16 = 0x1700
        public static let serversRemoveDead: UInt16 = 0x1701
        public static let serversDeadServerRetries: UInt16 = 0x1702
        public static let serversAutoUpdate: UInt16 = 0x1703
        public static let serversAddFromServer: UInt16 = 0x1705
        public static let serversAddFromClient: UInt16 = 0x1706
        public static let serversUseScoreSystem: UInt16 = 0x1707
        public static let serversSmartIDCheck: UInt16 = 0x1708
        public static let serversSafeServerConnect: UInt16 = 0x1709
        public static let serversAutoConnectStaticOnly: UInt16 = 0x170A
        public static let serversManualHighPriority: UInt16 = 0x170B
        public static let serversUpdateURL: UInt16 = 0x170C
        public static let prefsFiles: UInt16 = 0x1800
        public static let filesNewPaused: UInt16 = 0x1803
        public static let filesNewAutoDownloadPriority: UInt16 = 0x1804
        public static let filesPreviewPriority: UInt16 = 0x1805
        public static let filesNewAutoUploadPriority: UInt16 = 0x1806
        public static let filesSaveSources: UInt16 = 0x180A
        public static let filesExtractMetadata: UInt16 = 0x180B
        public static let filesAllocateFullSize: UInt16 = 0x180C
        public static let filesCheckFreeSpace: UInt16 = 0x180D
        public static let filesMinFreeSpace: UInt16 = 0x180E
        public static let filesCreateNormal: UInt16 = 0x180F
        public static let prefsCoreTweaks: UInt16 = 0x1D00
        public static let prefsDirectories: UInt16 = 0x1A00
        public static let directoriesIncoming: UInt16 = 0x1A01
        public static let directoriesTemp: UInt16 = 0x1A02
        public static let directoriesShared: UInt16 = 0x1A03
        public static let directoriesShareHidden: UInt16 = 0x1A04
        public static let prefsStatistics: UInt16 = 0x1B00
        public static let prefsSecurity: UInt16 = 0x1C00
        public static let securityCanSeeShares: UInt16 = 0x1C01
        public static let ipFilterClients: UInt16 = 0x1C02
        public static let ipFilterServers: UInt16 = 0x1C03
        public static let ipFilterAutoUpdate: UInt16 = 0x1C04
        public static let ipFilterUpdateURL: UInt16 = 0x1C05
        public static let ipFilterLevel: UInt16 = 0x1C06
        public static let ipFilterFilterLan: UInt16 = 0x1C07
        public static let securityUseSecureIdent: UInt16 = 0x1C08
        public static let securityObfuscationSupported: UInt16 = 0x1C09
        public static let securityObfuscationRequested: UInt16 = 0x1C0A
        public static let securityObfuscationRequired: UInt16 = 0x1C0B
        public static let prefsKademlia: UInt16 = 0x1E00
        public static let kademliaUpdateURL: UInt16 = 0x1E01
        public static let knownFileXferred: UInt16 = 0x0401
        public static let knownFileXferredAll: UInt16 = 0x0402
        public static let knownFileRequests: UInt16 = 0x0403
        public static let knownFileRequestsAll: UInt16 = 0x0404
        public static let knownFileAccepts: UInt16 = 0x0405
        public static let knownFileAcceptsAll: UInt16 = 0x0406
        public static let knownFileFilename: UInt16 = 0x0408
        public static let knownFilePriority: UInt16 = 0x040B
        public static let knownFileComment: UInt16 = 0x040E
        public static let knownFileRating: UInt16 = 0x040F
        public static let client: UInt16 = 0x0600
        public static let clientUploadTotal: UInt16 = 0x060A
        public static let clientDownloadTotal: UInt16 = 0x060B
        public static let clientUpSpeed: UInt16 = 0x060D
        public static let clientUploadFile: UInt16 = 0x061F
        public static let friend: UInt16 = 0x0800
        public static let friendName: UInt16 = 0x0801
        public static let friendHash: UInt16 = 0x0802
        public static let friendIP: UInt16 = 0x0803
        public static let friendPort: UInt16 = 0x0804
        public static let friendClient: UInt16 = 0x0805
        public static let friendAdd: UInt16 = 0x0806
        public static let friendRemove: UInt16 = 0x0807
        public static let friendSlot: UInt16 = 0x0808
        public static let friendShared: UInt16 = 0x0809
        public static let prefsCategories: UInt16 = 0x1100
        public static let category: UInt16 = 0x1101
        public static let categoryTitle: UInt16 = 0x1102
        public static let categoryPath: UInt16 = 0x1103
        public static let categoryComment: UInt16 = 0x1104
        public static let categoryColor: UInt16 = 0x1105
        public static let categoryPriority: UInt16 = 0x1106
        public static let statsGraphWidth: UInt16 = 0x1B01
        public static let statsGraphScale: UInt16 = 0x1B02
        public static let statsGraphLast: UInt16 = 0x1B03
        public static let statsGraphData: UInt16 = 0x1B04
        public static let statsTreeCapping: UInt16 = 0x1B05
        public static let statsTreeNode: UInt16 = 0x1B06
        public static let statsNodeValue: UInt16 = 0x1B07
        public static let statsTreeNodeID: UInt16 = 0x1B09
    }

    struct OmittedPreferenceTag: Equatable, Sendable {
        let tag: UInt16
        let symbol: String
        let rationale: String
    }

    // Upstream exposes these EC_TAG_FILES_* values in CEC_Prefs_Packet, but the
    // native remote intentionally models only safe remote settings. These are
    // local integrity/trust or queue-automation behaviors and stay hidden until
    // their remote UX and daemon-side side effects are explicitly designed.
    static let omittedRemoteFilePreferenceTags: [OmittedPreferenceTag] = [
        .init(tag: 0x1801, symbol: "EC_TAG_FILES_ICH_ENABLED", rationale: "ICH integrity behavior is a local core policy, not a routine remote GUI setting."),
        .init(tag: 0x1802, symbol: "EC_TAG_FILES_AICH_TRUST", rationale: "AICH hash trust changes security posture and is outside the safe remote subset."),
        .init(tag: 0x1807, symbol: "EC_TAG_FILES_UL_FULL_CHUNKS", rationale: "Upload full chunks affects sharing policy and is not part of the scoped amulegui parity UI."),
        .init(tag: 0x1808, symbol: "EC_TAG_FILES_START_NEXT_PAUSED", rationale: "Start-next automation can change queue behavior beyond per-file preference parity."),
        .init(tag: 0x1809, symbol: "EC_TAG_FILES_RESUME_SAME_CAT", rationale: "Resume-same-category automation depends on broader category workflow state."),
    ]

    public enum SearchScope: UInt64 {
        case local = 0x00
        case global = 0x01
        case kad = 0x02

        init(_ scope: String) {
            switch scope.lowercased() {
            case "local": self = .local
            case "global": self = .global
            default: self = .kad
            }
        }
    }

    private static let prefsConnections: UInt64 = 0x00000004
    private static let prefsCategories: UInt64 = 0x00000001
    private static let prefsGeneral: UInt64 = 0x00000002
    private static let prefsMessageFilter: UInt64 = 0x00000008
    private static let prefsRemoteControls: UInt64 = 0x00000010
    private static let prefsOnlineSignature: UInt64 = 0x00000020
    private static let prefsServers: UInt64 = 0x00000040
    private static let prefsFiles: UInt64 = 0x00000080
    private static let prefsCoreTweaks: UInt64 = 0x00001000
    private static let prefsDirectories: UInt64 = 0x00000200
    private static let prefsStatistics: UInt64 = 0x00000400
    private static let prefsSecurity: UInt64 = 0x00000800
    private static let prefsKademlia: UInt64 = 0x00002000

    public enum PreferencesGroup: Sendable {
        case connection
        case directories
        case files
        case servers
        case security
        case remoteControls
        case statistics

        var mask: UInt64 {
            switch self {
            case .connection: return prefsConnections
            case .directories: return prefsDirectories
            case .files: return prefsFiles
            case .servers: return prefsServers
            case .security: return prefsSecurity
            case .remoteControls: return prefsRemoteControls
            case .statistics: return prefsStatistics
            }
        }
    }

    private static let allRemotePreferenceGroups = prefsGeneral | prefsConnections | prefsMessageFilter | prefsRemoteControls | prefsOnlineSignature | prefsServers | prefsFiles | prefsCoreTweaks | prefsDirectories | prefsStatistics | prefsSecurity | prefsKademlia

    public static let readOnlyOperations: [String] = ECSupportedOps.allOperations

    public static func capabilities() -> ECCapabilities {
        ECCapabilities(ops: readOnlyOperations)
    }

    public static func status(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.status)
        return request(opcode: OpCode.statRequest, detail: .command)
    }

    public static func downloads(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.downloads)
        return request(opcode: OpCode.getDownloadQueue, detail: .full)
    }

    public static func downloadsUpdate(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.downloads)
        return request(opcode: OpCode.getUpdate, detail: .incrementalUpdate)
    }

    public static func servers(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.servers)
        return request(opcode: OpCode.getServerList, detail: .full)
    }

    public static func uploads(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.uploads)
        return request(opcode: OpCode.getUploadQueue, detail: .full)
    }

    public static func sharedFiles(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.sharedFiles)
        return request(opcode: OpCode.getSharedFiles, detail: .full)
    }

    public static func log(debug: Bool = false, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(debug ? .debugLog : .log)
        return ECPacket(opcode: debug ? OpCode.getDebugLog : OpCode.getLog)
    }

    public static func shutdown(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.shutdown)
        return ECPacket(opcode: OpCode.shutdown)
    }

    public static func resetDebugLog(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.resetDebugLog)
        return ECPacket(opcode: OpCode.resetDebugLog)
    }

    public static func lastLogEntry(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.lastLogEntry)
        return ECPacket(opcode: OpCode.getLastLogEntry)
    }

    public static func connectionState(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.connectionState)
        return ECPacket(opcode: OpCode.getConnectionState)
    }

    public static func sourcesQueueLookup(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.sources)
        return request(opcode: OpCode.getDownloadQueue, detail: .command)
    }

    public static func sourcesUpdate(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.sources)
        return request(opcode: OpCode.getUpdate, detail: .incrementalUpdate)
    }

    public static func friends(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.friends)
        return request(opcode: OpCode.getUpdate, detail: .incrementalUpdate)
    }

    public static func sources(hash: String, gate: ECCapabilityGate? = nil) throws -> [ECPacket] {
        guard isValidMD4Hash(hash) else { throw ECOperationError.invalidHash(hash) }
        return [try sourcesQueueLookup(gate: gate), try sourcesUpdate(gate: gate)]
    }

    public static func search(scope: String, query: String, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try search(request: ECSearchRequest(scope: scope, query: query), gate: gate)
    }

    public static func search(request: ECSearchRequest, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.search)
        var children = [
            ECTag(name: TagName.searchName, type: .string, value: .string(request.query)),
            ECTag(name: TagName.searchFileType, type: .string, value: .string(request.fileType)),
        ]
        if !request.extension.isEmpty {
            children.append(ECTag(name: TagName.searchExtension, type: .string, value: .string(request.extension)))
        }
        if request.availability > 0 {
            children.append(ECTag.integer(name: TagName.searchAvailability, value: request.availability))
        }
        if request.minSize > 0 {
            children.append(ECTag.integer(name: TagName.searchMinSize, value: request.minSize))
        }
        if request.maxSize > 0 {
            children.append(ECTag.integer(name: TagName.searchMaxSize, value: request.maxSize))
        }
        return ECPacket(opcode: OpCode.searchStart, tags: [
            ECTag.integer(name: TagName.searchType, value: SearchScope(request.scope).rawValue, children: children),
        ])
    }

    public static func searchStop(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.searchStop)
        return ECPacket(opcode: OpCode.searchStop)
    }

    public static func searchProgress() -> ECPacket {
        ECPacket(opcode: OpCode.searchProgress)
    }

    public static func searchResults() -> ECPacket {
        request(opcode: OpCode.searchResults, detail: .full)
    }

    public static func download(hash: String, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.download)
        return ECPacket(opcode: OpCode.downloadSearchResult, tags: [
            ECTag(name: TagName.partFile, type: .hash16, value: .hash16(try hashData(hash)), children: [
                ECTag.integer(name: TagName.partFileCategory, value: 0),
            ]),
        ])
    }

    public static func swapClientToAnotherFile(hash: String, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.clientSwapToAnotherFile)
        return ECPacket(opcode: OpCode.clientSwapToAnotherFile, tags: [
            ECTag(name: TagName.client, type: .hash16, value: .hash16(try hashData(hash)))
        ])
    }

    public static func addLink(_ link: String, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.addLink)
        return ECPacket(opcode: OpCode.addLink, tags: [ECTag(name: TagName.string, type: .string, value: .string(normalizedED2KLink(link)))])
    }

    public static func pause(hash: String, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try partFileAction(opcode: OpCode.partFilePause, operation: .pause, hash: hash, gate: gate)
    }

    public static func resume(hash: String, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try partFileAction(opcode: OpCode.partFileResume, operation: .resume, hash: hash, gate: gate)
    }

    public static func stop(hash: String, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try partFileAction(opcode: OpCode.partFileStop, operation: .downloadStop, hash: hash, gate: gate)
    }

    public static func swapA4AF(hash: String, mode: A4AFSwapMode, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        let opcode: UInt8
        let operation: ECOperationName
        switch mode {
        case .toThis:
            opcode = OpCode.partFileSwapA4AFThis
            operation = .downloadA4AFThis
        case .toThisAuto:
            opcode = OpCode.partFileSwapA4AFThisAuto
            operation = .downloadA4AFAuto
        case .toAnyOther:
            opcode = OpCode.partFileSwapA4AFOthers
            operation = .downloadA4AFOthers
        }
        return try partFileAction(opcode: opcode, operation: operation, hash: hash, gate: gate)
    }

    public static func cancel(hash: String, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try partFileAction(opcode: OpCode.partFileDelete, operation: .cancel, hash: hash, gate: gate)
    }

    public static func rename(hash: String, name: String, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.rename)
        return ECPacket(opcode: OpCode.renameFile, tags: [
            ECTag(name: TagName.knownFile, type: .hash16, value: .hash16(try hashData(hash))),
            ECTag(name: TagName.partFileName, type: .string, value: .string(name)),
        ])
    }

    public static func priority(hash: String, value: Int, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.priority)
        return ECPacket(opcode: OpCode.partFilePrioSet, tags: [
            ECTag(name: TagName.partFile, type: .hash16, value: .hash16(try hashData(hash)), children: [
                ECTag.integer(name: TagName.partFilePriority, value: UInt64(max(0, value))),
            ]),
        ])
    }

    public static func downloadSetCategory(hash: String, categoryID: Int, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.downloadSetCategory)
        return ECPacket(opcode: OpCode.partFileSetCat, tags: [
            ECTag(name: TagName.partFile, type: .hash16, value: .hash16(try hashData(hash)), children: [
                ECTag.integer(name: TagName.partFileCategory, value: UInt64(max(0, categoryID))),
            ]),
        ])
    }

    public static func sharedFilePriority(hash: String, priority: Int, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.sharedFilePriority)
        return ECPacket(opcode: OpCode.sharedSetPriority, tags: [
            ECTag(name: TagName.partFile, type: .hash16, value: .hash16(try hashData(hash)), children: [
                ECTag.integer(name: TagName.partFilePriority, value: UInt64(max(0, priority))),
            ]),
        ])
    }

    public static func sharedFileCommentRating(hash: String, comment: String, rating: Int, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.sharedFileCommentRating)
        return ECPacket(opcode: OpCode.sharedFileSetComment, tags: [
            ECTag(name: TagName.knownFile, type: .hash16, value: .hash16(try hashData(hash))),
            ECTag(name: TagName.knownFileComment, type: .string, value: .string(comment)),
            ECTag.integer(name: TagName.knownFileRating, value: UInt64(max(0, rating))),
        ])
    }

    public static func clearCompleted(ecids: [Int] = [], gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.clearCompleted)
        return ECPacket(opcode: OpCode.clearCompleted, tags: ecids.map { ecid in
            ECTag.integer(name: TagName.ecid, value: UInt64(max(0, ecid)))
        })
    }

    public static func sharedFilesReload(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.sharedFilesReload)
        return ECPacket(opcode: OpCode.sharedFilesReload)
    }

    public static func coreConnect(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.connect)
        return ECPacket(opcode: OpCode.connect)
    }

    public static func coreDisconnect(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.disconnect)
        return ECPacket(opcode: OpCode.disconnect)
    }

    public static func serverConnect(ip: String? = nil, port: Int? = nil, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.serverConnect)
        guard let ip, !ip.isEmpty, let port else { return ECPacket(opcode: OpCode.serverConnect) }
        return ECPacket(opcode: OpCode.serverConnect, tags: [try serverTag(ip: ip, port: port)])
    }

    public static func serverDisconnect(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.serverDisconnect)
        return ECPacket(opcode: OpCode.serverDisconnect)
    }

    public static func serverAdd(address: String, name: String? = nil, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.serverAdd)
        var tags = [ECTag(name: TagName.serverAddress, type: .string, value: .string(address))]
        if let name, !name.isEmpty {
            tags.append(ECTag(name: TagName.serverName, type: .string, value: .string(name)))
        }
        return ECPacket(opcode: OpCode.serverAdd, tags: tags)
    }

    public static func serverRemove(ip: String, port: Int, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.serverRemove)
        return ECPacket(opcode: OpCode.serverRemove, tags: [try serverTag(ip: ip, port: port)])
    }

    public static func serverUpdateFromURL(url: String, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.serverUpdateFromURL)
        return ECPacket(opcode: OpCode.serverUpdateFromURL, tags: [
            ECTag(name: TagName.serversUpdateURL, type: .string, value: .string(url))
        ])
    }

    public static func serverSetStatic(ecid: Int, isStatic: Bool, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.serverSetStatic)
        return ECPacket(opcode: OpCode.serverSetStaticPriority, tags: [
            ECTag.integer(name: TagName.server, value: UInt64(max(0, ecid))),
            ECTag.integer(name: TagName.serverStatic, value: isStatic ? 1 : 0),
        ])
    }

    public static func serverSetPriority(ecid: Int, priority: Int, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.serverSetPriority)
        return ECPacket(opcode: OpCode.serverSetStaticPriority, tags: [
            ECTag.integer(name: TagName.server, value: UInt64(max(0, ecid))),
            ECTag.integer(name: TagName.serverPriority, value: UInt64(max(0, priority))),
        ])
    }

    public static func serverInfo(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.serverInfo)
        return ECPacket(opcode: OpCode.getServerInfo)
    }

    public static func clearServerInfo(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.clearServerInfo)
        return ECPacket(opcode: OpCode.clearServerInfo)
    }

    public static func kadStart(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.kadStart)
        return ECPacket(opcode: OpCode.kadStart)
    }

    public static func kadStop(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.kadStop)
        return ECPacket(opcode: OpCode.kadStop)
    }

    public static func kadBootstrap(ip: String, port: Int, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.kadBootstrap)
        let parts = ip.split(separator: ".").compactMap { UInt8($0) }
        guard parts.count == 4, (1...65535).contains(port) else {
            throw ECOperationError.invalidServerEndpoint("\(ip):\(port)")
        }
        return ECPacket(opcode: OpCode.kadBootstrapFromIP, tags: [
            ECTag(name: TagName.serverIP, type: .ipv4, value: .ipv4(ECIPv4Address(parts[0], parts[1], parts[2], parts[3], port: UInt16(port))))
        ])
    }

    public static func kadUpdateFromURL(url: String, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.kadUpdateFromURL)
        return ECPacket(opcode: OpCode.kadUpdateFromURL, tags: [
            ECTag(name: TagName.kademliaUpdateURL, type: .string, value: .string(url))
        ])
    }

    public static func prefsConnectionGet(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.prefsConnectionGet)
        return ECPacket(opcode: OpCode.getPreferences, tags: [
            ECTag.integer(name: TagName.detailLevel, value: DetailLevel.command.rawValue),
            ECTag.integer(name: TagName.selectPrefs, value: allRemotePreferenceGroups),
        ])
    }

    public static func prefsConnectionSet(maxDownload: Int?, maxUpload: Int?, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.prefsConnectionSet)
        var prefsChildren: [ECTag] = []
        if let maxDownload { prefsChildren.append(ECTag.integer(name: TagName.connMaxDownload, value: UInt64(max(0, maxDownload)))) }
        if let maxUpload { prefsChildren.append(ECTag.integer(name: TagName.connMaxUpload, value: UInt64(max(0, maxUpload)))) }
        return ECPacket(opcode: OpCode.setPreferences, tags: [
            ECTag.integer(name: TagName.detailLevel, value: DetailLevel.full.rawValue),
            ECTag.integer(name: TagName.selectPrefs, value: prefsConnections),
            ECTag(name: TagName.prefsConnections, type: .custom, children: prefsChildren),
        ])
    }

    public static func prefsConnectionSet(prefs: ECConnectionPrefs, group: PreferencesGroup, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.prefsConnectionSet)
        return ECPacket(opcode: OpCode.setPreferences, tags: [
            ECTag.integer(name: TagName.detailLevel, value: DetailLevel.full.rawValue),
            ECTag.integer(name: TagName.selectPrefs, value: group.mask),
            preferenceGroupTag(prefs: prefs, group: group),
        ])
    }

    private static func preferenceGroupTag(prefs: ECConnectionPrefs, group: PreferencesGroup) -> ECTag {
        switch group {
        case .connection:
            var children: [ECTag] = [
                ECTag.integer(name: TagName.connMaxDownload, value: UInt64(max(0, prefs.maxDownload))),
                ECTag.integer(name: TagName.connMaxUpload, value: UInt64(max(0, prefs.maxUpload))),
            ]
            if let tcpPort = prefs.tcpPort { children.append(ECTag.integer(name: TagName.connTCPPort, value: UInt64(max(0, tcpPort)))) }
            if let udpPort = prefs.udpPort { children.append(ECTag.integer(name: TagName.connUDPPort, value: UInt64(max(0, udpPort)))) }
            appendBool(prefs.udpEnabled.map { !$0 }, TagName.connUDPDisable, to: &children)
            appendBool(prefs.ed2kEnabled, TagName.networkED2K, to: &children)
            appendBool(prefs.kadEnabled, TagName.networkKademlia, to: &children)
            return ECTag(name: TagName.prefsConnections, type: .custom, children: children)
        case .directories:
            var children: [ECTag] = []
            if let incomingDirectory = prefs.incomingDirectory {
                children.append(ECTag(name: TagName.directoriesIncoming, type: .string, value: .string(incomingDirectory)))
            }
            if let tempDirectory = prefs.tempDirectory {
                children.append(ECTag(name: TagName.directoriesTemp, type: .string, value: .string(tempDirectory)))
            }
            if let sharedDirectories = prefs.sharedDirectories {
                children.append(ECTag.integer(name: TagName.directoriesShared, value: UInt64(sharedDirectories.count), children: sharedDirectories.map {
                    ECTag(name: TagName.string, type: .string, value: .string($0))
                }))
            }
            if let shareHiddenFiles = prefs.shareHiddenFiles {
                children.append(ECTag.integer(name: TagName.directoriesShareHidden, value: shareHiddenFiles ? 1 : 0))
            }
            return ECTag(name: TagName.prefsDirectories, type: .custom, children: children)
        case .files:
            var children: [ECTag] = []
            appendBool(prefs.newFilesPaused, TagName.filesNewPaused, to: &children)
            appendBool(prefs.autoDownloadPriority, TagName.filesNewAutoDownloadPriority, to: &children)
            appendBool(prefs.previewPriority, TagName.filesPreviewPriority, to: &children)
            appendBool(prefs.autoUploadPriority, TagName.filesNewAutoUploadPriority, to: &children)
            appendBool(prefs.saveSources, TagName.filesSaveSources, to: &children)
            appendBool(prefs.extractMetadata, TagName.filesExtractMetadata, to: &children)
            appendBool(prefs.allocateFullFileSize, TagName.filesAllocateFullSize, to: &children)
            appendBool(prefs.checkFreeSpace, TagName.filesCheckFreeSpace, to: &children)
            if let minFreeDiskSpaceMB = prefs.minFreeDiskSpaceMB {
                children.append(ECTag.integer(name: TagName.filesMinFreeSpace, value: UInt64(max(0, minFreeDiskSpaceMB))))
            }
            appendBool(prefs.createSparseFiles.map { !$0 }, TagName.filesCreateNormal, to: &children)
            return ECTag(name: TagName.prefsFiles, type: .custom, children: children)
        case .servers:
            var children: [ECTag] = []
            appendBool(prefs.removeDeadServers, TagName.serversRemoveDead, to: &children)
            if let deadServerRetries = prefs.deadServerRetries {
                children.append(ECTag.integer(name: TagName.serversDeadServerRetries, value: UInt64(max(0, deadServerRetries))))
            }
            appendBool(prefs.autoUpdateServers, TagName.serversAutoUpdate, to: &children)
            appendBool(prefs.addServersFromServer, TagName.serversAddFromServer, to: &children)
            appendBool(prefs.addServersFromClient, TagName.serversAddFromClient, to: &children)
            appendBool(prefs.useServerPrioritySystem, TagName.serversUseScoreSystem, to: &children)
            appendBool(prefs.smartIdCheck, TagName.serversSmartIDCheck, to: &children)
            appendBool(prefs.safeServerConnect, TagName.serversSafeServerConnect, to: &children)
            appendBool(prefs.autoConnectStaticOnly, TagName.serversAutoConnectStaticOnly, to: &children)
            appendBool(prefs.manualHighPriority, TagName.serversManualHighPriority, to: &children)
            if let serverUpdateURL = prefs.serverUpdateURL {
                children.append(ECTag(name: TagName.serversUpdateURL, type: .string, value: .string(serverUpdateURL)))
            }
            return ECTag(name: TagName.prefsServers, type: .custom, children: children)
        case .security:
            var children: [ECTag] = []
            appendBool(prefs.filterClients, TagName.ipFilterClients, to: &children)
            appendBool(prefs.filterServers, TagName.ipFilterServers, to: &children)
            appendBool(prefs.ipFilterAutoUpdate, TagName.ipFilterAutoUpdate, to: &children)
            if let ipFilterUpdateURL = prefs.ipFilterUpdateURL {
                children.append(ECTag(name: TagName.ipFilterUpdateURL, type: .string, value: .string(ipFilterUpdateURL)))
            }
            if let ipFilterLevel = prefs.ipFilterLevel {
                children.append(ECTag.integer(name: TagName.ipFilterLevel, value: UInt64(max(0, ipFilterLevel))))
            }
            appendBool(prefs.filterLanIPs, TagName.ipFilterFilterLan, to: &children)
            appendBool(prefs.secureIdentEnabled, TagName.securityUseSecureIdent, to: &children)
            appendBool(prefs.obfuscationSupported, TagName.securityObfuscationSupported, to: &children)
            appendBool(prefs.obfuscationRequested, TagName.securityObfuscationRequested, to: &children)
            appendBool(prefs.obfuscationRequired, TagName.securityObfuscationRequired, to: &children)
            return ECTag(name: TagName.prefsSecurity, type: .custom, children: children)
        case .remoteControls:
            var children: [ECTag] = []
            appendBool(prefs.webServerEnabled, TagName.webServerAutorun, to: &children)
            if let webServerPort = prefs.webServerPort {
                children.append(ECTag.integer(name: TagName.webServerPort, value: UInt64(max(0, webServerPort))))
            }
            appendBool(prefs.webServerGuestEnabled, TagName.webServerGuest, to: &children)
            appendBool(prefs.webServerUseGzip, TagName.webServerUseGzip, to: &children)
            if let webServerRefreshSeconds = prefs.webServerRefreshSeconds {
                children.append(ECTag.integer(name: TagName.webServerRefresh, value: UInt64(max(0, webServerRefreshSeconds))))
            }
            if let webServerTemplate = prefs.webServerTemplate {
                children.append(ECTag(name: TagName.webServerTemplate, type: .string, value: .string(webServerTemplate)))
            }
            return ECTag(name: TagName.prefsRemoteControls, type: .custom, children: children)
        case .statistics:
            return ECTag(name: TagName.prefsStatistics, type: .custom, children: [])
        }
    }

    private static func appendBool(_ value: Bool?, _ name: UInt16, to children: inout [ECTag]) {
        if let value {
            children.append(ECTag.integer(name: name, value: value ? 1 : 0))
        }
    }

    public static func categories(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.categories)
        return ECPacket(opcode: OpCode.getPreferences, tags: [
            ECTag.integer(name: TagName.selectPrefs, value: prefsCategories),
        ])
    }

    public static func categoryCreate(name: String, path: String, comment: String, color: Int, priority: Int, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.categoryCreate)
        return ECPacket(opcode: OpCode.createCategory, tags: [
            categoryTag(id: 0, name: name, path: path, comment: comment, color: color, priority: priority)
        ])
    }

    public static func categoryUpdate(id: Int, name: String, path: String, comment: String, color: Int, priority: Int, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.categoryUpdate)
        return ECPacket(opcode: OpCode.updateCategory, tags: [
            categoryTag(id: id, name: name, path: path, comment: comment, color: color, priority: priority)
        ])
    }

    public static func categoryDelete(categoryID: Int, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.categoryDelete)
        return ECPacket(opcode: OpCode.deleteCategory, tags: [
            ECTag.integer(name: TagName.category, value: UInt64(max(0, categoryID)))
        ])
    }

    public static func ipfilterReload(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.ipfilterReload)
        return ECPacket(opcode: OpCode.ipfilterReload)
    }

    public static func ipfilterUpdate(url: String?, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.ipfilterUpdate)
        let tags = url.flatMap { $0.isEmpty ? nil : ECTag(name: TagName.string, type: .string, value: .string($0)) }
        return ECPacket(opcode: OpCode.ipfilterUpdate, tags: tags.map { [$0] } ?? [])
    }

    public static func resetLog(gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.resetLog)
        return ECPacket(opcode: OpCode.resetLog)
    }

    public static func friendRemove(friendID: Int, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.friendRemove)
        return ECPacket(opcode: OpCode.friend, tags: [
            ECTag(name: TagName.friendRemove, type: .custom, children: [
                ECTag.integer(name: TagName.friend, value: UInt64(max(0, friendID)))
            ])
        ])
    }

    public static func friendAdd(hash: String, ip: String, port: Int, name: String, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.friendAdd)
        guard isValidMD4Hash(hash) else { throw ECOperationError.invalidHash(hash) }
        guard (1...65535).contains(port) else {
            throw ECOperationError.invalidServerEndpoint("\(ip):\(port)")
        }
        return ECPacket(opcode: OpCode.friend, tags: [
            ECTag(name: TagName.friendAdd, type: .custom, children: [
                ECTag(name: TagName.friendHash, type: .hash16, value: .hash16(try hashData(hash))),
                ECTag.integer(name: TagName.friendIP, value: UInt64(try antiHostIPValue(ip))),
                ECTag.integer(name: TagName.friendPort, value: UInt64(port)),
                ECTag(name: TagName.friendName, type: .string, value: .string(name)),
            ])
        ])
    }

    public static func friendAdd(clientID: Int, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.friendAdd)
        return ECPacket(opcode: OpCode.friend, tags: [
            ECTag(name: TagName.friendAdd, type: .custom, children: [
                ECTag.integer(name: TagName.client, value: UInt64(max(0, clientID)))
            ])
        ])
    }

    public static func friendRequestSharedList(friendID: Int, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.friendShared)
        return ECPacket(opcode: OpCode.friend, tags: [
            ECTag(name: TagName.friendShared, type: .custom, children: [
                ECTag.integer(name: TagName.friend, value: UInt64(max(0, friendID)))
            ])
        ])
    }

    public static func friendRequestSharedList(clientID: Int, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.friendShared)
        return ECPacket(opcode: OpCode.friend, tags: [
            ECTag(name: TagName.friendShared, type: .custom, children: [
                ECTag.integer(name: TagName.client, value: UInt64(max(0, clientID)))
            ])
        ])
    }

    public static func friendSlot(friendID: Int, enabled: Bool, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.friendSlot)
        return ECPacket(opcode: OpCode.friend, tags: [
            ECTag.integer(name: TagName.friendSlot, value: enabled ? 1 : 0, children: [
                ECTag.integer(name: TagName.friend, value: UInt64(max(0, friendID)))
            ])
        ])
    }

    public static func statsTree(capping: Int? = nil, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.statsTree)
        return ECPacket(opcode: OpCode.getStatsTree, tags: [
            ECTag.integer(name: TagName.statsTreeCapping, value: UInt64(max(0, capping ?? 0)))
        ])
    }

    public static func statsGraphs(width: Int, scale: Int, last: Double?, gate: ECCapabilityGate? = nil) throws -> ECPacket {
        try gate?.require(.statsGraphs)
        var tags: [ECTag] = [
            ECTag.integer(name: TagName.statsGraphWidth, value: UInt64(max(1, width))),
            ECTag.integer(name: TagName.statsGraphScale, value: UInt64(max(1, scale))),
        ]
        if let last {
            tags.append(ECTag(name: TagName.statsGraphLast, type: .double, value: .double(last)))
        }
        return ECPacket(opcode: OpCode.getStatsGraphs, tags: tags)
    }

    private static func request(opcode: UInt8, detail: DetailLevel) -> ECPacket {
        if detail == .full {
            return ECPacket(opcode: opcode)
        }
        return ECPacket(opcode: opcode, tags: [ECTag.integer(name: TagName.detailLevel, value: detail.rawValue)])
    }

    private static func isValidMD4Hash(_ hash: String) -> Bool {
        hash.count == 32 && hash.allSatisfy { $0.isHexDigit }
    }

    private static func hashData(_ hash: String) throws -> Data {
        guard isValidMD4Hash(hash) else { throw ECOperationError.invalidHash(hash) }
        var bytes = Data(capacity: 16)
        var index = hash.startIndex
        while index < hash.endIndex {
            let next = hash.index(index, offsetBy: 2)
            guard let byte = UInt8(hash[index..<next], radix: 16) else {
                throw ECOperationError.invalidHash(hash)
            }
            bytes.append(byte)
            index = next
        }
        return bytes
    }

    private static func antiHostIPValue(_ ip: String) throws -> UInt32 {
        let parts = ip.split(separator: ".").compactMap { UInt8($0) }
        guard parts.count == 4 else {
            throw ECOperationError.invalidServerEndpoint(ip)
        }
        return UInt32(parts[0]) |
            UInt32(parts[1]) << 8 |
            UInt32(parts[2]) << 16 |
            UInt32(parts[3]) << 24
    }

    private static func partFileAction(opcode: UInt8, operation: ECOperationName, hash: String, gate: ECCapabilityGate?) throws -> ECPacket {
        try gate?.require(operation)
        return ECPacket(opcode: opcode, tags: [ECTag(name: TagName.partFile, type: .hash16, value: .hash16(try hashData(hash)))])
    }

    private static func serverTag(ip: String, port: Int) throws -> ECTag {
        let parts = ip.split(separator: ".").compactMap { UInt8($0) }
        guard parts.count == 4, (1...65535).contains(port) else {
            throw ECOperationError.invalidServerEndpoint("\(ip):\(port)")
        }
        return ECTag(name: TagName.server, type: .ipv4, value: .ipv4(ECIPv4Address(parts[0], parts[1], parts[2], parts[3], port: UInt16(port))))
    }

    private static func categoryTag(id: Int, name: String, path: String, comment: String, color: Int, priority: Int) -> ECTag {
        ECTag.integer(name: TagName.category, value: UInt64(max(0, id)), children: [
            ECTag(name: TagName.categoryTitle, type: .string, value: .string(name)),
            ECTag(name: TagName.categoryPath, type: .string, value: .string(path)),
            ECTag(name: TagName.categoryComment, type: .string, value: .string(comment)),
            ECTag.integer(name: TagName.categoryColor, value: UInt64(max(0, color))),
            ECTag.integer(name: TagName.categoryPriority, value: UInt64(max(0, priority))),
        ])
    }

    private static func normalizedED2KLink(_ link: String) -> String {
        var normalized = link
        if normalized.hasPrefix("ed2k://") {
            if normalized.contains("|h="), !normalized.contains("|/|h=") {
                normalized = normalized.replacingOccurrences(of: "|h=", with: "|/|h=")
            }
            if normalized.hasPrefix("ed2k://%7C") {
                normalized = normalized.replacingOccurrences(of: "%7C", with: "|")
            }
        }
        return normalized
    }
}
