import Foundation
import AMuleECClient

// MARK: - Type Aliases for SwiftEC Compatible Types
// These types are structurally identical between SwiftEC and the app

public typealias BridgeStatusPayload = ECStatus
public typealias BridgeSearchPayload = ECSearchResult
public typealias BridgeConnectionPrefsPayload = ECConnectionPrefs
public typealias BridgeDownloadSourcePayload = ECSource
public typealias BridgeServerPayload = ECServer
public typealias BridgeCapabilitiesPayload = ECCapabilities

// MARK: - BridgeDownloadPayload Compatibility
// ECDownload has required progressColors, BridgeDownloadPayload has optional
// We extend ECDownload to provide a compatible initializer

extension ECDownload {
    /// Creates an ECDownload from BridgeDownloadPayload fields for compatibility
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
