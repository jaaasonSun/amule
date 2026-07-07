import Foundation
import AMuleECClient
import AMuleECBridgeAdapter

public enum BridgeCapabilityGate {
    public static func isSupported(_ op: String, by supportedOps: Set<String>) -> Bool {
        supportedOps.isEmpty || supportedOps.contains(op)
    }
}

public struct StatusSnapshot: Sendable {
    public var connected: Bool
    public var ed2k: String
    public var kad: String
    public var downloadBytesPerSecond: Int?
    public var uploadBytesPerSecond: Int?
    public var queueCount: Int?
    public var sourcesCount: Int?
    public var uploadSpeedLimit: Int?
    public var downloadSpeedLimit: Int?
    public var uploadOverhead: Int?
    public var downloadOverhead: Int?
    public var bannedCount: Int?
    public var ed2kUsers: Int?
    public var kadUsers: Int?
    public var ed2kFiles: Int?
    public var kadFiles: Int?
    public var kadFirewalledUDP: Bool?
    public var totalSentBytes: UInt64?
    public var totalReceivedBytes: UInt64?
    public var sharedFileCount: Int?
    public var kadNodes: Int?
    public var loggerMessage: String?
    public var kadIndexedSources: Int?
    public var kadIndexedKeywords: Int?
    public var kadIndexedNotes: Int?
    public var kadIndexedLoad: Int?
    public var kadIP: String?
    public var buddyStatus: Int?
    public var buddyIP: String?
    public var buddyPort: Int?
    public var kadInLANMode: Bool?

    public init(
        connected: Bool = false,
        ed2k: String = "Unknown",
        kad: String = "Unknown",
        downloadBytesPerSecond: Int? = nil,
        uploadBytesPerSecond: Int? = nil,
        queueCount: Int? = nil,
        sourcesCount: Int? = nil,
        uploadSpeedLimit: Int? = nil,
        downloadSpeedLimit: Int? = nil,
        uploadOverhead: Int? = nil,
        downloadOverhead: Int? = nil,
        bannedCount: Int? = nil,
        ed2kUsers: Int? = nil,
        kadUsers: Int? = nil,
        ed2kFiles: Int? = nil,
        kadFiles: Int? = nil,
        kadFirewalledUDP: Bool? = nil,
        totalSentBytes: UInt64? = nil,
        totalReceivedBytes: UInt64? = nil,
        sharedFileCount: Int? = nil,
        kadNodes: Int? = nil,
        loggerMessage: String? = nil,
        kadIndexedSources: Int? = nil,
        kadIndexedKeywords: Int? = nil,
        kadIndexedNotes: Int? = nil,
        kadIndexedLoad: Int? = nil,
        kadIP: String? = nil,
        buddyStatus: Int? = nil,
        buddyIP: String? = nil,
        buddyPort: Int? = nil,
        kadInLANMode: Bool? = nil
    ) {
        self.connected = connected
        self.ed2k = ed2k
        self.kad = kad
        self.downloadBytesPerSecond = downloadBytesPerSecond
        self.uploadBytesPerSecond = uploadBytesPerSecond
        self.queueCount = queueCount
        self.sourcesCount = sourcesCount
        self.uploadSpeedLimit = uploadSpeedLimit
        self.downloadSpeedLimit = downloadSpeedLimit
        self.uploadOverhead = uploadOverhead
        self.downloadOverhead = downloadOverhead
        self.bannedCount = bannedCount
        self.ed2kUsers = ed2kUsers
        self.kadUsers = kadUsers
        self.ed2kFiles = ed2kFiles
        self.kadFiles = kadFiles
        self.kadFirewalledUDP = kadFirewalledUDP
        self.totalSentBytes = totalSentBytes
        self.totalReceivedBytes = totalReceivedBytes
        self.sharedFileCount = sharedFileCount
        self.kadNodes = kadNodes
        self.loggerMessage = loggerMessage
        self.kadIndexedSources = kadIndexedSources
        self.kadIndexedKeywords = kadIndexedKeywords
        self.kadIndexedNotes = kadIndexedNotes
        self.kadIndexedLoad = kadIndexedLoad
        self.kadIP = kadIP
        self.buddyStatus = buddyStatus
        self.buddyIP = buddyIP
        self.buddyPort = buddyPort
        self.kadInLANMode = kadInLANMode
    }

    public var downloadSpeed: String {
        guard let downloadBytesPerSecond else { return "-" }
        return AMuleFormatter.speed(bytesPerSecond: downloadBytesPerSecond)
    }

    public var uploadSpeed: String {
        guard let uploadBytesPerSecond else { return "-" }
        return AMuleFormatter.speed(bytesPerSecond: uploadBytesPerSecond)
    }

    public var queue: String {
        guard let queueCount else { return "-" }
        return String(queueCount)
    }

    public var sources: String {
        guard let sourcesCount else { return "-" }
        return String(sourcesCount)
    }

    public var looksConnected: Bool {
        connected
    }

    public static func fromBridge(_ payload: BridgeStatusPayload) -> StatusSnapshot {
        StatusSnapshot(
            connected: payload.connected,
            ed2k: payload.ed2k,
            kad: payload.kad,
            downloadBytesPerSecond: payload.downloadSpeed,
            uploadBytesPerSecond: payload.uploadSpeed,
            queueCount: payload.queue,
            sourcesCount: payload.sources,
            uploadSpeedLimit: payload.uploadSpeedLimit,
            downloadSpeedLimit: payload.downloadSpeedLimit,
            uploadOverhead: payload.uploadOverhead,
            downloadOverhead: payload.downloadOverhead,
            bannedCount: payload.bannedCount,
            ed2kUsers: payload.ed2kUsers,
            kadUsers: payload.kadUsers,
            ed2kFiles: payload.ed2kFiles,
            kadFiles: payload.kadFiles,
            kadFirewalledUDP: payload.kadFirewalledUDP,
            totalSentBytes: payload.totalSentBytes,
            totalReceivedBytes: payload.totalReceivedBytes,
            sharedFileCount: payload.sharedFileCount,
            kadNodes: payload.kadNodes,
            loggerMessage: payload.loggerMessage,
            kadIndexedSources: payload.kadIndexedSources,
            kadIndexedKeywords: payload.kadIndexedKeywords,
            kadIndexedNotes: payload.kadIndexedNotes,
            kadIndexedLoad: payload.kadIndexedLoad,
            kadIP: payload.kadIP,
            buddyStatus: payload.buddyStatus,
            buddyIP: payload.buddyIP,
            buddyPort: payload.buddyPort,
            kadInLANMode: payload.kadInLANMode
        )
    }
}
