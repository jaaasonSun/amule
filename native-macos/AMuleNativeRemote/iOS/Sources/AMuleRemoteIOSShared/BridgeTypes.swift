import Foundation
import AMuleECClient

public typealias BridgeStatusPayload = ECStatus
public typealias BridgeSearchPayload = ECSearchResult
public typealias BridgeConnectionPrefsPayload = ECConnectionPrefs
public typealias BridgeDownloadSourcePayload = ECSource
public typealias BridgeServerPayload = ECServer
public typealias BridgeCapabilitiesPayload = ECCapabilities

extension ECDownload {
    public init(
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
        self.init(
            ecid: ecid,
            hash: hash,
            name: name,
            nameEncodingSuspect: nameEncodingSuspect,
            nameEncodingSuggestion: nameEncodingSuggestion,
            size: size,
            done: done,
            transferred: transferred,
            progress: progress,
            sourcesCurrent: sourcesCurrent,
            sourcesTotal: sourcesTotal,
            sourcesTransferring: sourcesTransferring,
            sourcesA4AF: sourcesA4AF,
            statusCode: statusCode,
            isCompleted: isCompleted,
            status: status,
            speed: speed,
            priority: priority,
            category: category,
            partMet: partMet,
            lastSeenComplete: lastSeenComplete,
            lastReceived: lastReceived,
            activeSeconds: activeSeconds,
            availableParts: availableParts,
            shared: shared,
            alternativeNames: alternativeNames,
            progressColors: progressColors ?? []
        )
    }
}

public typealias BridgeDownloadPayload = ECDownload
public typealias BridgeUploadPayload = ECUpload
public typealias BridgeSharedFilePayload = ECSharedFile
public typealias BridgeCoreLogPayload = ECCoreLog
public typealias BridgeCategoryPayload = ECCategory
public typealias BridgeFriendPayload = ECFriend
public typealias BridgeStatsTreeNodePayload = ECStatsTreeNode
public typealias BridgeStatsGraphSamplePayload = ECStatsGraphSample
public typealias BridgeStatsGraphsPayload = ECStatsGraphs

public struct BridgeStatsPayload: Decodable {
    public let tree: BridgeStatsTreeNodePayload?
    public let graphs: BridgeStatsGraphsPayload?
}

public struct BridgeEnvelope: Decodable {
    public let ok: Bool
    public let error: String?
    public let message: String?
    public let schemaVersion: Int?
    public let capabilities: BridgeCapabilitiesPayload?
    public let status: BridgeStatusPayload?
    public let downloads: [BridgeDownloadPayload]?
    public let sources: [BridgeDownloadSourcePayload]?
    public let uploads: [BridgeUploadPayload]?
    public let sharedFiles: [BridgeSharedFilePayload]?
    public let log: BridgeCoreLogPayload?
    public let prefsConnection: BridgeConnectionPrefsPayload?
    public let categories: [BridgeCategoryPayload]?
    public let friends: [BridgeFriendPayload]?
    public let stats: BridgeStatsPayload?
    public let servers: [BridgeServerPayload]?
    public let progress: Int?
    public let results: [BridgeSearchPayload]?

    private enum CodingKeys: String, CodingKey {
        case ok, error, message, capabilities, status, downloads, sources, uploads, log, categories, friends, stats, servers, progress, results
        case schemaVersion = "schema_version"
        case sharedFiles = "shared_files"
        case prefsConnection = "prefs_connection"
    }
}
