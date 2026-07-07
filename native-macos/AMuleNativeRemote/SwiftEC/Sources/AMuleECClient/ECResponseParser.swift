import Foundation
import AMuleECProtocol

public enum ECResponseParserError: Error, Equatable, LocalizedError, Sendable {
    case unexpectedOpcode(expected: UInt8, actual: UInt8)
    case downloadNotFound(hash: String)
    case operationFailed(String)
    case missingPreferences

    public var errorDescription: String? {
        switch self {
        case .unexpectedOpcode(let expected, let actual): return "Unexpected opcode: expected \(expected), got \(actual)"
        case .downloadNotFound(let hash): return "File not found in download queue: \(hash)"
        case .operationFailed(let message): return message
        case .missingPreferences: return "Connection preferences missing from core reply"
        }
    }
}

public enum ECResponseParser {
    public enum TagName {
        public static let connState: UInt16 = 0x0005
        public static let ecid: UInt16 = 0x000F
        public static let ed2kID: UInt16 = 0x000F
        public static let statsUploadSpeed: UInt16 = 0x0200
        public static let statsDownloadSpeed: UInt16 = 0x0201
        public static let statsUploadSpeedLimit: UInt16 = 0x0202
        public static let statsDownloadSpeedLimit: UInt16 = 0x0203
        public static let statsUpOverhead: UInt16 = 0x0204
        public static let statsDownOverhead: UInt16 = 0x0205
        public static let statsTotalSourceCount: UInt16 = 0x0206
        public static let statsBannedCount: UInt16 = 0x0207
        public static let statsUploadQueueLength: UInt16 = 0x0208
        public static let statsED2KUsers: UInt16 = 0x0209
        public static let statsKadUsers: UInt16 = 0x020A
        public static let statsED2KFiles: UInt16 = 0x020B
        public static let statsKadFiles: UInt16 = 0x020C
        public static let statsKadFirewalledUDP: UInt16 = 0x020E
        public static let statsLoggerMessage: UInt16 = 0x020D
        public static let statsKadIndexedSources: UInt16 = 0x020F
        public static let statsKadIndexedKeywords: UInt16 = 0x0210
        public static let statsKadIndexedNotes: UInt16 = 0x0211
        public static let statsKadIndexedLoad: UInt16 = 0x0212
        public static let statsKadIP: UInt16 = 0x0213
        public static let statsBuddyStatus: UInt16 = 0x0214
        public static let statsBuddyIP: UInt16 = 0x0215
        public static let statsBuddyPort: UInt16 = 0x0216
        public static let statsKadInLANMode: UInt16 = 0x0217
        public static let statsTotalSentBytes: UInt16 = 0x0218
        public static let statsTotalReceivedBytes: UInt16 = 0x0219
        public static let statsSharedFileCount: UInt16 = 0x021A
        public static let statsKadNodes: UInt16 = 0x021B
        public static let partFile: UInt16 = 0x0300
        public static let partFileName: UInt16 = 0x0301
        public static let partFilePartMetID: UInt16 = 0x0302
        public static let partFileSizeFull: UInt16 = 0x0303
        public static let partFileSizeTransfer: UInt16 = 0x0304
        public static let partFileSizeXferUp: UInt16 = 0x0305
        public static let partFileSizeDone: UInt16 = 0x0306
        public static let partFileSpeed: UInt16 = 0x0307
        public static let partFileStatus: UInt16 = 0x0308
        public static let partFilePriority: UInt16 = 0x0309
        public static let partFileSourceCount: UInt16 = 0x030A
        public static let partFileSourceCountA4AF: UInt16 = 0x030B
        public static let partFileSourceCountNotCurrent: UInt16 = 0x030C
        public static let partFileSourceCountTransfer: UInt16 = 0x030D
        public static let partFileEd2kLink: UInt16 = 0x030E
        public static let partFileCategory: UInt16 = 0x030F
        public static let partFileLastReceived: UInt16 = 0x0310
        public static let partFileLastSeenComplete: UInt16 = 0x0311
        public static let partFilePartStatus: UInt16 = 0x0312
        public static let partFileGapStatus: UInt16 = 0x0313
        public static let partFileRequestStatus: UInt16 = 0x0314
        public static let partFileSourceNames: UInt16 = 0x0315
        public static let partFileA4AFAuto: UInt16 = 0x0321
        public static let partFileComments: UInt16 = 0x0316
        public static let partFileStopped: UInt16 = 0x0317
        public static let partFileDownloadActive: UInt16 = 0x0318
        public static let partFileLostCorruption: UInt16 = 0x0319
        public static let partFileGainedCompression: UInt16 = 0x031A
        public static let partFileSavedICH: UInt16 = 0x031B
        public static let partFileSourceNameCounts: UInt16 = 0x031C
        public static let partFileAvailableParts: UInt16 = 0x031D
        public static let partFileHash: UInt16 = 0x031E
        public static let partFileShared: UInt16 = 0x031F
        public static let partFileHashedPartCount: UInt16 = 0x0320
        public static let partFileA4AFSources: UInt16 = 0x0322
        public static let knownFile: UInt16 = 0x0400
        public static let knownFileXferred: UInt16 = 0x0401
        public static let knownFileXferredAll: UInt16 = 0x0402
        public static let knownFileRequests: UInt16 = 0x0403
        public static let knownFileRequestsAll: UInt16 = 0x0404
        public static let knownFileAccepts: UInt16 = 0x0405
        public static let knownFileAcceptsAll: UInt16 = 0x0406
        public static let knownFileAICHMasterHash: UInt16 = 0x0407
        public static let knownFileFilename: UInt16 = 0x0408
        public static let knownFileOnQueue: UInt16 = 0x0409
        public static let knownFileCompleteSources: UInt16 = 0x040A
        public static let knownFilePriority: UInt16 = 0x040B
        public static let knownFileCompleteSourcesLow: UInt16 = 0x040C
        public static let knownFileCompleteSourcesHigh: UInt16 = 0x040D
        public static let knownFileComment: UInt16 = 0x040E
        public static let knownFileRating: UInt16 = 0x040F
        public static let server: UInt16 = 0x0500
        public static let serverName: UInt16 = 0x0501
        public static let serverDescription: UInt16 = 0x0502
        public static let serverAddress: UInt16 = 0x0503
        public static let serverPing: UInt16 = 0x0504
        public static let serverUsers: UInt16 = 0x0505
        public static let serverMaxUsers: UInt16 = 0x0506
        public static let serverFiles: UInt16 = 0x0507
        public static let serverPriority: UInt16 = 0x0508
        public static let serverFailed: UInt16 = 0x0509
        public static let serverStatic: UInt16 = 0x050A
        public static let serverVersion: UInt16 = 0x050B
        public static let serverIP: UInt16 = 0x050C
        public static let serverPort: UInt16 = 0x050D
        public static let searchFile: UInt16 = 0x0700
        public static let searchStatus: UInt16 = 0x0708
        public static let searchParent: UInt16 = 0x0709
        public static let string: UInt16 = 0x0000
        public static let clientVersion: UInt16 = 0x0101
        public static let clientMod: UInt16 = 0x0102
        public static let prefsGeneral: UInt16 = 0x1200
        public static let userNick: UInt16 = 0x1201
        public static let userHash: UInt16 = 0x1202
        public static let userHost: UInt16 = 0x1203
        public static let generalCheckNewVersion: UInt16 = 0x1204
        public static let prefsConnections: UInt16 = 0x1300
        public static let connMaxDownload: UInt16 = 0x1303
        public static let connMaxUpload: UInt16 = 0x1304
        public static let connTCPPort: UInt16 = 0x1306
        public static let connUDPPort: UInt16 = 0x1307
        public static let connUDPDisable: UInt16 = 0x1308
        public static let connDLCap: UInt16 = 0x1301
        public static let connULCap: UInt16 = 0x1302
        public static let connSlotAllocation: UInt16 = 0x1305
        public static let connMaxFileSources: UInt16 = 0x1309
        public static let connMaxConn: UInt16 = 0x130A
        public static let connAutoConnect: UInt16 = 0x130B
        public static let connReconnect: UInt16 = 0x130C
        public static let networkED2K: UInt16 = 0x130D
        public static let networkKademlia: UInt16 = 0x130E
        public static let prefsMessageFilter: UInt16 = 0x1400
        public static let msgFilterEnabled: UInt16 = 0x1401
        public static let msgFilterAll: UInt16 = 0x1402
        public static let msgFilterFriends: UInt16 = 0x1403
        public static let msgFilterSecure: UInt16 = 0x1404
        public static let msgFilterByKeyword: UInt16 = 0x1405
        public static let msgFilterKeywords: UInt16 = 0x1406
        public static let prefsRemoteControls: UInt16 = 0x1500
        public static let webServerAutorun: UInt16 = 0x1501
        public static let webServerPort: UInt16 = 0x1502
        public static let webServerGuest: UInt16 = 0x1503
        public static let webServerUseGzip: UInt16 = 0x1504
        public static let webServerRefresh: UInt16 = 0x1505
        public static let webServerTemplate: UInt16 = 0x1506
        public static let prefsOnlineSignature: UInt16 = 0x1600
        public static let onlineSignatureEnabled: UInt16 = 0x1601
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
        public static let coreTweaksMaxConnPerFive: UInt16 = 0x1D01
        public static let coreTweaksVerbose: UInt16 = 0x1D02
        public static let coreTweaksFileBuffer: UInt16 = 0x1D03
        public static let coreTweaksUploadQueue: UInt16 = 0x1D04
        public static let coreTweaksServerKeepaliveTimeout: UInt16 = 0x1D05
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
        public static let client: UInt16 = 0x0600
        public static let clientSoftware: UInt16 = 0x0601
        public static let clientScore: UInt16 = 0x0602
        public static let clientHash: UInt16 = 0x0603
        public static let clientFriendSlot: UInt16 = 0x0604
        public static let clientWaitTime: UInt16 = 0x0605
        public static let clientXferTime: UInt16 = 0x0606
        public static let clientQueueTime: UInt16 = 0x0607
        public static let clientLastTime: UInt16 = 0x0608
        public static let clientUploadSession: UInt16 = 0x0609
        public static let clientName: UInt16 = 0x0100
        public static let clientDownloadState: UInt16 = 0x060C
        public static let clientUpSpeed: UInt16 = 0x060D
        public static let clientDownSpeed: UInt16 = 0x060E
        public static let clientFrom: UInt16 = 0x060F
        public static let clientUserIP: UInt16 = 0x0610
        public static let clientUserPort: UInt16 = 0x0611
        public static let clientServerIP: UInt16 = 0x0612
        public static let clientServerPort: UInt16 = 0x0613
        public static let clientServerName: UInt16 = 0x0614
        public static let clientSoftwareVersion: UInt16 = 0x0615
        public static let clientWaitingPosition: UInt16 = 0x0616
        public static let clientIdentState: UInt16 = 0x0617
        public static let clientObfuscationStatus: UInt16 = 0x0618
        public static let clientRemoteQueueRank: UInt16 = 0x061A
        public static let clientDisableViewShared: UInt16 = 0x061B
        public static let clientUploadState: UInt16 = 0x061C
        public static let clientExtendedProtocol: UInt16 = 0x061D
        public static let clientUserID: UInt16 = 0x061E
        public static let clientUploadFile: UInt16 = 0x061F
        public static let clientRequestFile: UInt16 = 0x0620
        public static let clientA4AFFiles: UInt16 = 0x0621
        public static let clientOldRemoteQueueRank: UInt16 = 0x0622
        public static let clientKadPort: UInt16 = 0x0623
        public static let clientPartStatus: UInt16 = 0x0624
        public static let clientNextRequestedPart: UInt16 = 0x0625
        public static let clientLastDownloadingPart: UInt16 = 0x0626
        public static let clientRemoteFilename: UInt16 = 0x0627
        public static let clientModVersion: UInt16 = 0x0628
        public static let clientOSInfo: UInt16 = 0x0629
        public static let clientAvailableParts: UInt16 = 0x062A
        public static let clientUploadPartStatus: UInt16 = 0x062B
        public static let clientUploadTotal: UInt16 = 0x060A
        public static let clientDownloadTotal: UInt16 = 0x060B
        public static let friend: UInt16 = 0x0800
        public static let friendName: UInt16 = 0x0801
        public static let friendHash: UInt16 = 0x0802
        public static let friendIP: UInt16 = 0x0803
        public static let friendPort: UInt16 = 0x0804
        public static let friendClient: UInt16 = 0x0805
        public static let friendSlot: UInt16 = 0x0808
        public static let prefsCategories: UInt16 = 0x1100
        public static let category: UInt16 = 0x1101
        public static let categoryTitle: UInt16 = 0x1102
        public static let categoryPath: UInt16 = 0x1103
        public static let categoryComment: UInt16 = 0x1104
        public static let categoryColor: UInt16 = 0x1105
        public static let categoryPriority: UInt16 = 0x1106
        public static let statsGraphLast: UInt16 = 0x1B03
        public static let statsGraphData: UInt16 = 0x1B04
        public static let statsTreeNode: UInt16 = 0x1B06
        public static let statsNodeValue: UInt16 = 0x1B07
        public static let statsTreeNodeID: UInt16 = 0x1B09
    }

    public static func parseStatus(_ packet: ECPacket) throws -> ECStatus {
        try requireOpcode(packet, ECOperations.OpCode.stats)
        let connState = packet.tags.first(named: TagName.connState)
        let state = connState?.uintValue ?? 0
        let ed2kConnected = (state & 0x01) != 0
        let ed2kConnecting = (state & 0x02) != 0
        let kadConnected = (state & 0x04) != 0
        let kadFirewalled = (state & 0x08) != 0
        let kadRunning = (state & 0x10) != 0
        let server = connState?.child(named: TagName.server).map(parseStatusServer)
        let idStatus = connState?.child(named: TagName.ed2kID).flatMap { tag -> String? in
            let value = tag.uintValue
            guard value != 0xffffffff else { return nil }
            return value < 0x1000000 ? "LowID" : "HighID"
        }

        return ECStatus(
            connected: ed2kConnected,
            ed2k: ed2kStatusText(connected: ed2kConnected, connecting: ed2kConnecting, server: server, idStatus: idStatus),
            kad: kadStatusText(running: kadRunning, connected: kadConnected, firewalled: kadFirewalled),
            currentServer: ed2kConnected ? server : nil,
            idStatus: idStatus,
            downloadSpeed: packet.tags.first(named: TagName.statsDownloadSpeed)?.intValue ?? 0,
            uploadSpeed: packet.tags.first(named: TagName.statsUploadSpeed)?.intValue ?? 0,
            queue: packet.tags.first(named: TagName.statsUploadQueueLength)?.intValue ?? 0,
            sources: packet.tags.first(named: TagName.statsTotalSourceCount)?.intValue ?? 0,
            uploadSpeedLimit: packet.tags.first(named: TagName.statsUploadSpeedLimit)?.intValue ?? 0,
            downloadSpeedLimit: packet.tags.first(named: TagName.statsDownloadSpeedLimit)?.intValue ?? 0,
            uploadOverhead: packet.tags.first(named: TagName.statsUpOverhead)?.intValue ?? 0,
            downloadOverhead: packet.tags.first(named: TagName.statsDownOverhead)?.intValue ?? 0,
            bannedCount: packet.tags.first(named: TagName.statsBannedCount)?.intValue ?? 0,
            ed2kUsers: packet.tags.first(named: TagName.statsED2KUsers)?.intValue ?? 0,
            kadUsers: packet.tags.first(named: TagName.statsKadUsers)?.intValue ?? 0,
            ed2kFiles: packet.tags.first(named: TagName.statsED2KFiles)?.intValue ?? 0,
            kadFiles: packet.tags.first(named: TagName.statsKadFiles)?.intValue ?? 0,
            kadFirewalledUDP: (packet.tags.first(named: TagName.statsKadFirewalledUDP)?.intValue ?? 0) != 0,
            totalSentBytes: packet.tags.first(named: TagName.statsTotalSentBytes)?.uintValue ?? 0,
            totalReceivedBytes: packet.tags.first(named: TagName.statsTotalReceivedBytes)?.uintValue ?? 0,
            sharedFileCount: packet.tags.first(named: TagName.statsSharedFileCount)?.intValue ?? 0,
            kadNodes: packet.tags.first(named: TagName.statsKadNodes)?.intValue ?? 0,
            loggerMessage: packet.tags.first(named: TagName.statsLoggerMessage)?.stringValue,
            kadIndexedSources: packet.tags.first(named: TagName.statsKadIndexedSources)?.intValue ?? 0,
            kadIndexedKeywords: packet.tags.first(named: TagName.statsKadIndexedKeywords)?.intValue ?? 0,
            kadIndexedNotes: packet.tags.first(named: TagName.statsKadIndexedNotes)?.intValue ?? 0,
            kadIndexedLoad: packet.tags.first(named: TagName.statsKadIndexedLoad)?.intValue ?? 0,
            kadIP: packet.tags.first(named: TagName.statsKadIP)?.ipStringValue,
            buddyStatus: packet.tags.first(named: TagName.statsBuddyStatus)?.intValue ?? 0,
            buddyIP: packet.tags.first(named: TagName.statsBuddyIP)?.ipStringValue,
            buddyPort: packet.tags.first(named: TagName.statsBuddyPort)?.intValue ?? 0,
            kadInLANMode: (packet.tags.first(named: TagName.statsKadInLANMode)?.intValue ?? 0) != 0
        )
    }

    private static func parseStatusServer(_ tag: ECTag) -> ECServer {
        let endpoint = tag.ipv4Value
        let ip = endpoint?.host ?? tag.child(named: TagName.serverIP)?.ipStringValue ?? ""
        let port = endpoint?.port ?? tag.child(named: TagName.serverPort)?.intValue ?? 0
        let explicitAddress = tag.child(named: TagName.serverAddress)?.stringValue ?? ""
        let address = explicitAddress.isEmpty ? endpointText(ip: ip, port: port) : explicitAddress
        return ECServer(
            id: 0,
            name: tag.child(named: TagName.serverName)?.stringValue ?? "",
            description: tag.child(named: TagName.serverDescription)?.stringValue ?? "",
            version: tag.child(named: TagName.serverVersion)?.stringValue ?? "",
            address: address,
            ip: ip,
            port: port,
            users: tag.child(named: TagName.serverUsers)?.intValue ?? 0,
            maxUsers: tag.child(named: TagName.serverMaxUsers)?.intValue ?? 0,
            files: tag.child(named: TagName.serverFiles)?.intValue ?? 0,
            ping: tag.child(named: TagName.serverPing)?.intValue ?? 0,
            failed: tag.child(named: TagName.serverFailed)?.intValue ?? 0,
            priority: tag.child(named: TagName.serverPriority)?.intValue ?? 0,
            isStatic: (tag.child(named: TagName.serverStatic)?.intValue ?? 0) != 0
        )
    }

    private static func ed2kStatusText(connected: Bool, connecting: Bool, server: ECServer?, idStatus: String?) -> String {
        if connected {
            var text = "Connected"
            if let server, !server.name.isEmpty {
                text += " to \(server.name)"
            }
            if let endpoint = serverEndpointText(server) {
                text += " [\(endpoint)]"
            }
            if let idStatus {
                text += " \(idStatus)"
            }
            return text
        }

        if connecting {
            var text = "Connecting"
            if let server, !server.name.isEmpty {
                text += " to \(server.name)"
            }
            if let endpoint = serverEndpointText(server) {
                text += " [\(endpoint)]"
            }
            return text
        }

        return "Not connected"
    }

    private static func serverEndpointText(_ server: ECServer?) -> String? {
        guard let server, !server.ip.isEmpty, server.port > 0 else { return nil }
        return "\(server.ip):\(server.port)"
    }

    private static func kadStatusText(running: Bool, connected: Bool, firewalled: Bool) -> String {
        guard running else { return "Off" }
        if connected {
            return firewalled ? "Connected (firewalled)" : "Connected"
        }
        return "Connecting"
    }

    public static func parseDownloads(_ packet: ECPacket) throws -> [ECDownload] {
        try checkFailure(packet)
        guard packet.opcode == ECOperations.OpCode.downloadQueue || packet.opcode == ECOperations.OpCode.sharedFiles else {
            throw ECResponseParserError.unexpectedOpcode(expected: ECOperations.OpCode.downloadQueue, actual: packet.opcode)
        }
        return packet.tags.compactMap(parseDownloadTag)
    }

    public static func parseDownloadFileID(hash: String, in packet: ECPacket) throws -> Int {
        try requireOpcode(packet, ECOperations.OpCode.downloadQueue)
        let normalizedHash = hash.lowercased()
        for tag in packet.tags {
            guard let download = parseDownloadTag(tag), download.hash.lowercased() == normalizedHash else { continue }
            return download.ecid
        }
        throw ECResponseParserError.downloadNotFound(hash: hash)
    }

    public static func parseSources(_ packet: ECPacket, requestFileID: Int) throws -> [ECSource] {
        try requireOpcode(packet, ECOperations.OpCode.sharedFiles)
        let clientTags = packet.tags.flatMap { tag -> [ECTag] in
            guard tag.name == TagName.client else { return [] }
            let nested = tag.children.filter { $0.name == TagName.client }
            return nested.isEmpty ? [tag] : nested
        }

        let useRequestContextForMissingFileID = clientTags.allSatisfy { tag in
            guard let tagRequestFileID = tag.child(named: TagName.clientRequestFile)?.intValue, tagRequestFileID > 0 else { return true }
            return tagRequestFileID == requestFileID
        }

        return clientTags.compactMap { tag in
            parseSourceTag(
                tag,
                requestFileID: requestFileID,
                useRequestContextWhenMissingFileID: useRequestContextForMissingFileID
            )
        }.sorted { lhs, rhs in
            if lhs.downloadState != rhs.downloadState { return lhs.downloadState < rhs.downloadState }
            if lhs.downSpeedKBps != rhs.downSpeedKBps { return lhs.downSpeedKBps > rhs.downSpeedKBps }
            if lhs.clientName != rhs.clientName { return lhs.clientName < rhs.clientName }
            return lhs.clientID < rhs.clientID
        }
    }

    private static func parseSourceTag(_ tag: ECTag, requestFileID: Int, useRequestContextWhenMissingFileID: Bool) -> ECSource? {
        guard let resolvedRequestFileID = sourceRequestFileID(
            in: tag,
            matching: requestFileID,
            useRequestContextWhenMissingFileID: useRequestContextWhenMissingFileID
        ) else { return nil }
        let state = tag.child(named: TagName.clientDownloadState)?.intValue ?? 0
        let from = tag.child(named: TagName.clientFrom)?.intValue ?? 0
        let rank = tag.child(named: TagName.clientRemoteQueueRank)?.intValue ?? 0
        let softwareVersion = tag.child(named: TagName.clientSoftwareVersion)?.stringValue ?? ""
        return ECSource(
            clientID: tag.intValue,
            requestFileID: resolvedRequestFileID,
            clientName: tag.child(named: TagName.clientName)?.stringValue ?? "",
            userIP: tag.child(named: TagName.clientUserIP)?.ipStringValue ?? "",
            userPort: tag.child(named: TagName.clientUserPort)?.intValue ?? 0,
            serverName: tag.child(named: TagName.clientServerName)?.stringValue ?? "",
            serverIP: tag.child(named: TagName.clientServerIP)?.ipStringValue ?? "",
            serverPort: tag.child(named: TagName.clientServerPort)?.intValue ?? 0,
            software: softwareText(tag.child(named: TagName.clientSoftware)?.intValue ?? 0),
            softwareVersion: softwareVersion,
            downloadedTotal: tag.child(named: TagName.clientDownloadTotal).map { Int(clamping: $0.uintValue) },
            uploadedTotal: tag.child(named: TagName.clientUploadTotal).map { Int(clamping: $0.uintValue) },
            versionString: sourceVersionString(
                softVersion: softwareVersion,
                clientVersion: tag.child(named: TagName.clientVersion)?.uintValue,
                modVersion: tag.child(named: TagName.clientModVersion)?.stringValue
            ),
            downloadState: state,
            downloadStateText: downloadStateText(state, queueFull: rank == 0xffff),
            sourceFrom: from,
            sourceFromText: sourceFromText(from),
            downSpeedKBps: tag.child(named: TagName.clientDownSpeed)?.doubleValue ?? 0,
            availableParts: tag.child(named: TagName.clientAvailableParts)?.intValue ?? 0,
            remoteQueueRank: rank,
            obfuscationStatus: tag.child(named: TagName.clientObfuscationStatus)?.intValue ?? 0,
            extendedProtocol: (tag.child(named: TagName.clientExtendedProtocol)?.intValue ?? 0) != 0,
            remoteFilename: tag.child(named: TagName.clientRemoteFilename)?.stringValue ?? "",
            sharesFileList: tag.child(named: TagName.clientDisableViewShared).map { $0.uintValue == 0 },
            clientHash: tag.child(named: TagName.clientHash)?.dataValue ?? Data(),
            score: tag.child(named: TagName.clientScore)?.intValue ?? 0,
            friendSlot: (tag.child(named: TagName.clientFriendSlot)?.intValue ?? 0) != 0,
            waitTime: tag.child(named: TagName.clientWaitTime)?.intValue ?? 0,
            xferTime: tag.child(named: TagName.clientXferTime)?.intValue ?? 0,
            queueTime: tag.child(named: TagName.clientQueueTime)?.intValue ?? 0,
            lastTime: tag.child(named: TagName.clientLastTime)?.intValue ?? 0,
            isModded: (tag.child(named: TagName.clientMod)?.intValue ?? 0) != 0,
            uploadSession: tag.child(named: TagName.clientUploadSession)?.intValue ?? 0,
            uploadState: tag.child(named: TagName.clientUploadState)?.intValue ?? 0,
            identState: tag.child(named: TagName.clientIdentState)?.intValue ?? 0,
            uploadSpeed: tag.child(named: TagName.clientUpSpeed)?.intValue ?? 0,
            oldRemoteQueueRank: tag.child(named: TagName.clientOldRemoteQueueRank)?.intValue ?? 0,
            waitingPosition: tag.child(named: TagName.clientWaitingPosition)?.intValue ?? 0,
            userID: tag.child(named: TagName.clientUserID)?.intValue ?? 0,
            kadPort: tag.child(named: TagName.clientKadPort)?.intValue ?? 0,
            osInfo: tag.child(named: TagName.clientOSInfo)?.stringValue ?? "",
            partStatus: tag.child(named: TagName.clientPartStatus)?.dataValue ?? Data(),
            nextRequestedPart: tag.child(named: TagName.clientNextRequestedPart)?.intValue ?? 0,
            lastDownloadingPart: tag.child(named: TagName.clientLastDownloadingPart)?.intValue ?? 0,
            a4afFiles: tag.child(named: TagName.clientA4AFFiles)?.dataValue ?? Data(),
            uploadPartStatus: tag.child(named: TagName.clientUploadPartStatus)?.dataValue ?? Data()
        )
    }

    private static func sourceVersionString(softVersion: String, clientVersion: UInt64?, modVersion: String?) -> String? {
        var text = softVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty, let clientVersion, clientVersion > 0 {
            text = String(clientVersion)
        }

        let modText = modVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !modText.isEmpty, text.isEmpty {
            text = modText
        } else if !modText.isEmpty, text.range(of: modText, options: [.caseInsensitive, .diacriticInsensitive]) == nil {
            text += " - \(modText)"
        }

        return text.isEmpty ? nil : text
    }

    private static func sourceRequestFileID(in tag: ECTag, matching requestFileID: Int, useRequestContextWhenMissingFileID: Bool) -> Int? {
        if let tagRequestFileID = tag.child(named: TagName.clientRequestFile)?.intValue {
            return tagRequestFileID == requestFileID ? tagRequestFileID : nil
        }
        return useRequestContextWhenMissingFileID && requestFileID > 0 ? requestFileID : nil
    }

    public static func parseServers(_ packet: ECPacket) throws -> [ECServer] {
        try requireOpcode(packet, ECOperations.OpCode.serverList)
        return packet.tags.enumerated().compactMap { index, tag in
            guard tag.name == TagName.server else { return nil }
            let endpoint = tag.ipv4Value
            let ip = endpoint?.host ?? tag.child(named: TagName.serverIP)?.ipStringValue ?? ""
            let port = endpoint?.port ?? tag.child(named: TagName.serverPort)?.intValue ?? 0
            let explicitAddress = tag.child(named: TagName.serverAddress)?.stringValue ?? ""
            let address = explicitAddress.isEmpty ? endpointText(ip: ip, port: port) : explicitAddress
            return ECServer(
                id: index + 1,
                name: tag.child(named: TagName.serverName)?.stringValue ?? "",
                description: tag.child(named: TagName.serverDescription)?.stringValue ?? "",
                version: tag.child(named: TagName.serverVersion)?.stringValue ?? "",
                address: address,
                ip: ip,
                port: port,
                users: tag.child(named: TagName.serverUsers)?.intValue ?? 0,
                maxUsers: tag.child(named: TagName.serverMaxUsers)?.intValue ?? 0,
                files: tag.child(named: TagName.serverFiles)?.intValue ?? 0,
                ping: tag.child(named: TagName.serverPing)?.intValue ?? 0,
                failed: tag.child(named: TagName.serverFailed)?.intValue ?? 0,
                priority: tag.child(named: TagName.serverPriority)?.intValue ?? 0,
                isStatic: (tag.child(named: TagName.serverStatic)?.intValue ?? 0) != 0
            )
        }
    }

    public static func parseUploads(_ packet: ECPacket) throws -> [ECUpload] {
        try requireOpcode(packet, ECOperations.OpCode.uploadQueue)
        return packet.tags.compactMap { tag in
            guard tag.name == TagName.client else { return nil }
            return ECUpload(
                clientID: tag.intValue,
                clientName: tag.child(named: TagName.clientName)?.stringValue ?? "",
                userIP: tag.child(named: TagName.clientUserIP)?.ipStringValue ?? "",
                userPort: tag.child(named: TagName.clientUserPort)?.intValue ?? 0,
                serverIP: tag.child(named: TagName.clientServerIP)?.ipStringValue ?? "",
                serverPort: tag.child(named: TagName.clientServerPort)?.intValue ?? 0,
                serverName: tag.child(named: TagName.clientServerName)?.stringValue ?? "",
                speedUp: tag.child(named: TagName.clientUpSpeed)?.intValue ?? 0,
                xferUp: tag.child(named: TagName.clientUploadTotal)?.uintValue ?? 0,
                xferDown: tag.child(named: TagName.clientDownloadTotal)?.uintValue ?? 0,
                uploadFile: tag.child(named: TagName.clientUploadFile)?.intValue
            )
        }
    }

    public static func parseSharedFiles(_ packet: ECPacket) throws -> [ECSharedFile] {
        try requireOpcode(packet, ECOperations.OpCode.sharedFiles)
        return packet.tags.compactMap { tag in
            guard tag.name == TagName.knownFile else { return nil }
            let path = tag.child(named: TagName.knownFileFilename)?.stringValue ?? ""
            let name = URL(fileURLWithPath: path).lastPathComponent.isEmpty ? path : URL(fileURLWithPath: path).lastPathComponent
            let hash = tag.hashStringValue
            let size = tag.child(named: TagName.partFileSizeFull)?.uintValue ?? 0
            return ECSharedFile(
                hash: hash,
                name: name,
                path: path,
                size: size,
                ed2kLink: hash.isEmpty || name.isEmpty ? "" : "ed2k://|file|\(name)|\(size)|\(hash.uppercased())|/",
                priority: tag.child(named: TagName.knownFilePriority)?.intValue ?? 0,
                requests: tag.child(named: TagName.knownFileRequests)?.intValue ?? 0,
                requestsAll: tag.child(named: TagName.knownFileRequestsAll)?.intValue ?? 0,
                accepts: tag.child(named: TagName.knownFileAccepts)?.intValue ?? 0,
                acceptsAll: tag.child(named: TagName.knownFileAcceptsAll)?.intValue ?? 0,
                xferred: tag.child(named: TagName.knownFileXferred)?.uintValue ?? 0,
                xferredAll: tag.child(named: TagName.knownFileXferredAll)?.uintValue ?? 0,
                aichMasterHash: tag.child(named: TagName.knownFileAICHMasterHash)?.hashStringValue,
                onQueue: tag.child(named: TagName.knownFileOnQueue)?.intValue ?? 0,
                completeSources: tag.child(named: TagName.knownFileCompleteSources)?.intValue ?? 0,
                completeSourcesLow: tag.child(named: TagName.knownFileCompleteSourcesLow)?.intValue ?? 0,
                completeSourcesHigh: tag.child(named: TagName.knownFileCompleteSourcesHigh)?.intValue ?? 0,
                comment: tag.child(named: TagName.knownFileComment)?.stringValue,
                rating: tag.child(named: TagName.knownFileRating)?.intValue
            )
        }
    }

    public static func parseCoreLog(_ packet: ECPacket, kind: String) throws -> ECCoreLog {
        try requireOpcode(packet, kind == "debug" ? ECOperations.OpCode.debugLog : ECOperations.OpCode.log)
        return ECCoreLog(kind: kind, lines: packet.tags.compactMap(\.stringValue))
    }

    public static func parseLastLogEntry(_ packet: ECPacket) throws -> String {
        try requireOpcode(packet, ECOperations.OpCode.log)
        return packet.tags.compactMap(\.stringValue).joined(separator: "\n")
    }

    public static func parseConnectionState(_ packet: ECPacket) throws -> ECConnectionState {
        try requireOpcode(packet, ECOperations.OpCode.miscData)
        let state = packet.tags.first(named: TagName.connState)?.uintValue ?? 0
        return ECConnectionState(
            ed2kConnected: (state & 0x01) != 0,
            ed2kConnecting: (state & 0x02) != 0,
            kadConnected: (state & 0x04) != 0,
            kadFirewalled: (state & 0x08) != 0,
            kadRunning: (state & 0x10) != 0
        )
    }

    public static func parseServerInfo(_ packet: ECPacket) throws -> ECCoreLog {
        try requireOpcode(packet, ECOperations.OpCode.serverInfo)
        let text = packet.tags.first { $0.name == ECOperations.TagName.string }?.stringValue ?? ""
        return ECCoreLog(kind: "server-info", lines: text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init))
    }

    public static func parseCategories(_ packet: ECPacket) throws -> [ECCategory] {
        try requireOpcode(packet, ECOperations.OpCode.setPreferences)
        guard let categories = packet.tags.first(named: TagName.prefsCategories) else { return [] }
        return categories.children.compactMap { tag in
            guard tag.name == TagName.category else { return nil }
            return ECCategory(
                id: tag.intValue,
                title: tag.child(named: TagName.categoryTitle)?.stringValue ?? "",
                path: tag.child(named: TagName.categoryPath)?.stringValue ?? "",
                comment: tag.child(named: TagName.categoryComment)?.stringValue ?? "",
                color: tag.child(named: TagName.categoryColor)?.intValue ?? 0,
                priority: tag.child(named: TagName.categoryPriority)?.intValue ?? 0
            )
        }
    }

    public static func parseFriends(_ packet: ECPacket) throws -> [ECFriend] {
        try requireOpcode(packet, ECOperations.OpCode.sharedFiles)
        let friendTags = packet.tags.flatMap { tag -> [ECTag] in
            guard tag.name == TagName.friend else { return [] }
            let nested = tag.children.filter { $0.name == TagName.friend }
            return nested.isEmpty ? [tag] : nested
        }
        return friendTags.compactMap { tag in
            let id = tag.intValue
            guard id > 0 else { return nil }
            return ECFriend(
                id: id,
                name: tag.child(named: TagName.friendName)?.stringValue ?? "",
                hash: tag.child(named: TagName.friendHash)?.hashStringValue ?? "",
                ip: tag.child(named: TagName.friendIP)?.ipStringValue ?? "",
                port: tag.child(named: TagName.friendPort)?.intValue ?? 0,
                client: String(tag.child(named: TagName.friendClient)?.intValue ?? 0),
                friendSlot: (tag.child(named: TagName.friendSlot)?.intValue ?? 0) != 0
            )
        }
    }

    public static func parseStatsTree(_ packet: ECPacket) throws -> ECStatsTreeNode {
        try requireOpcode(packet, ECOperations.OpCode.statsTree)
        guard let root = packet.tags.first(named: TagName.statsTreeNode) else {
            throw ECResponseParserError.operationFailed("Statistics tree missing from core reply")
        }
        return parseStatsTreeNode(root)
    }

    public static func parseStatsGraphs(_ packet: ECPacket) throws -> ECStatsGraphs {
        try requireOpcode(packet, ECOperations.OpCode.statsGraphs)
        let last = packet.tags.first(named: TagName.statsGraphLast)?.doubleValue ?? 0
        let bytes = packet.tags.first(named: TagName.statsGraphData)?.customData ?? Data()
        let values = stride(from: 0, to: bytes.count - (bytes.count % 4), by: 4).map { offset -> Int in
            let slice = bytes[offset..<offset + 4]
            return Int(slice.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) })
        }
        let samples = stride(from: 0, to: values.count - (values.count % 4), by: 4).map { index in
            ECStatsGraphSample(dl: values[index], ul: values[index + 1], connections: values[index + 2], kad: values[index + 3])
        }
        return ECStatsGraphs(last: last, samples: samples)
    }

    public static func parseMutationResponse(
        _ packet: ECPacket,
        successMessage: String,
        expectedSuccessOpcodes: Set<UInt8> = [ECOperations.OpCode.noop]
    ) throws -> String {
        try checkFailure(packet)
        guard expectedSuccessOpcodes.contains(packet.opcode) else {
            throw ECResponseParserError.unexpectedOpcode(
                expected: expectedSuccessOpcodes.sorted().first ?? ECOperations.OpCode.noop,
                actual: packet.opcode
            )
        }
        return successMessage
    }

    public static func parseSearchProgress(_ packet: ECPacket) throws -> Int {
        try requireOpcode(packet, ECOperations.OpCode.searchProgress)
        return packet.tags.first(named: TagName.searchStatus)?.intValue ?? 0
    }

    public static func parseSearchResults(_ packet: ECPacket) throws -> [ECSearchResult] {
        try requireOpcode(packet, ECOperations.OpCode.searchResults)
        return packet.tags.compactMap { tag in
            guard tag.name == TagName.searchFile else { return nil }
            let statusCode = tag.child(named: TagName.partFileStatus)?.intValue ?? 0
            return ECSearchResult(
                id: tag.intValue,
                hash: tag.child(named: TagName.partFileHash)?.hashStringValue ?? tag.hashStringValue,
                name: tag.child(named: TagName.partFileName)?.stringValue ?? "",
                size: tag.child(named: TagName.partFileSizeFull)?.uintValue ?? 0,
                sources: tag.child(named: TagName.partFileSourceCount)?.intValue ?? 0,
                completeSources: tag.child(named: TagName.partFileSourceCountTransfer)?.intValue ?? 0,
                statusCode: statusCode,
                status: searchStatusText(statusCode),
                parentID: tag.child(named: TagName.searchParent)?.intValue ?? 0,
                alreadyHave: statusCode != 0
            )
        }
    }

    public static func parseConnectionPrefs(_ packet: ECPacket) throws -> ECConnectionPrefs {
        try requireOpcode(packet, ECOperations.OpCode.setPreferences)
        let general = packet.tags.first(named: TagName.prefsGeneral)
        let connection = packet.tags.first(named: TagName.prefsConnections)
        let messageFilter = packet.tags.first(named: TagName.prefsMessageFilter)
        let onlineSignature = packet.tags.first(named: TagName.prefsOnlineSignature)
        let directories = packet.tags.first(named: TagName.prefsDirectories)
        let files = packet.tags.first(named: TagName.prefsFiles)
        let coreTweaks = packet.tags.first(named: TagName.prefsCoreTweaks)
        let servers = packet.tags.first(named: TagName.prefsServers)
        let security = packet.tags.first(named: TagName.prefsSecurity)
        let remoteControls = packet.tags.first(named: TagName.prefsRemoteControls)
        let statistics = packet.tags.first(named: TagName.prefsStatistics)
        let kademlia = packet.tags.first(named: TagName.prefsKademlia)
        guard general != nil || connection != nil || messageFilter != nil || onlineSignature != nil || directories != nil || files != nil || coreTweaks != nil || servers != nil || security != nil || remoteControls != nil || statistics != nil || kademlia != nil else {
            throw ECResponseParserError.missingPreferences
        }
        let hasConnectionNetworkFields = connection.map {
            $0.child(named: TagName.connTCPPort) != nil ||
                $0.child(named: TagName.connUDPPort) != nil ||
                $0.child(named: TagName.connUDPDisable) != nil ||
                $0.child(named: TagName.networkED2K) != nil ||
                $0.child(named: TagName.networkKademlia) != nil
        } ?? false
        let userNick = general?.child(named: TagName.userNick)?.stringValue
        let userHash = general?.child(named: TagName.userHash)?.hashStringValue
        let userHost = general?.child(named: TagName.userHost)?.stringValue
        let checkNewVersion = general.flatMap { preferenceBool($0, TagName.generalCheckNewVersion) }
        let maxDownload = connection?.child(named: TagName.connMaxDownload)?.intValue ?? 0
        let maxUpload = connection?.child(named: TagName.connMaxUpload)?.intValue ?? 0
        let tcpPort = connection?.child(named: TagName.connTCPPort)?.intValue
        let udpPort = connection?.child(named: TagName.connUDPPort)?.intValue
        let udpEnabled = hasConnectionNetworkFields ? connection.map { !(preferenceBool($0, TagName.connUDPDisable) ?? false) } : nil
        let ed2kEnabled = hasConnectionNetworkFields ? connection.flatMap { preferenceBool($0, TagName.networkED2K) } : nil
        let kadEnabled = hasConnectionNetworkFields ? connection.flatMap { preferenceBool($0, TagName.networkKademlia) } : nil
        let messageFilterEnabled = messageFilter.flatMap { preferenceBool($0, TagName.msgFilterEnabled) }
        let messageFilterAll = messageFilter.flatMap { preferenceBool($0, TagName.msgFilterAll) }
        let messageFilterFriends = messageFilter.flatMap { preferenceBool($0, TagName.msgFilterFriends) }
        let messageFilterSecure = messageFilter.flatMap { preferenceBool($0, TagName.msgFilterSecure) }
        let messageFilterByKeyword = messageFilter.flatMap { preferenceBool($0, TagName.msgFilterByKeyword) }
        let messageFilterKeywords = messageFilter?.child(named: TagName.msgFilterKeywords)?.stringValue
        let onlineSignatureEnabled = onlineSignature.flatMap { preferenceBool($0, TagName.onlineSignatureEnabled) }
        let incomingDirectory = directories?.child(named: TagName.directoriesIncoming)?.stringValue
        let tempDirectory = directories?.child(named: TagName.directoriesTemp)?.stringValue
        let sharedDirectories = directories?.child(named: TagName.directoriesShared)?.children.compactMap(\.stringValue)
        let shareHiddenFiles = directories?.child(named: TagName.directoriesShareHidden).map { $0.intValue != 0 }
        let newFilesPaused = files.flatMap { preferenceBool($0, TagName.filesNewPaused) }
        let autoDownloadPriority = files.flatMap { preferenceBool($0, TagName.filesNewAutoDownloadPriority) }
        let previewPriority = files.flatMap { preferenceBool($0, TagName.filesPreviewPriority) }
        let autoUploadPriority = files.flatMap { preferenceBool($0, TagName.filesNewAutoUploadPriority) }
        let saveSources = files.flatMap { preferenceBool($0, TagName.filesSaveSources) }
        let extractMetadata = files.flatMap { preferenceBool($0, TagName.filesExtractMetadata) }
        let allocateFullFileSize = files.flatMap { preferenceBool($0, TagName.filesAllocateFullSize) }
        let checkFreeSpace = files.flatMap { preferenceBool($0, TagName.filesCheckFreeSpace) }
        let minFreeDiskSpaceMB = files?.child(named: TagName.filesMinFreeSpace)?.intValue
        let createSparseFiles = files.map { !(preferenceBool($0, TagName.filesCreateNormal) ?? false) }
        let maxConnectionsPerFive = coreTweaks?.child(named: TagName.coreTweaksMaxConnPerFive)?.intValue
        let verboseLogging = coreTweaks.flatMap { preferenceBool($0, TagName.coreTweaksVerbose) }
        let fileBufferSize = coreTweaks?.child(named: TagName.coreTweaksFileBuffer)?.intValue
        let uploadQueueSize = coreTweaks?.child(named: TagName.coreTweaksUploadQueue)?.intValue
        let serverKeepaliveTimeout = coreTweaks?.child(named: TagName.coreTweaksServerKeepaliveTimeout)?.intValue
        let serverUpdateURL = servers?.child(named: TagName.serversUpdateURL)?.stringValue
        let removeDeadServers = servers.flatMap { preferenceBool($0, TagName.serversRemoveDead) }
        let deadServerRetries = servers?.child(named: TagName.serversDeadServerRetries)?.intValue
        let autoUpdateServers = servers.flatMap { preferenceBool($0, TagName.serversAutoUpdate) }
        let addServersFromServer = servers.flatMap { preferenceBool($0, TagName.serversAddFromServer) }
        let addServersFromClient = servers.flatMap { preferenceBool($0, TagName.serversAddFromClient) }
        let useServerPrioritySystem = servers.flatMap { preferenceBool($0, TagName.serversUseScoreSystem) }
        let smartIdCheck = servers.flatMap { preferenceBool($0, TagName.serversSmartIDCheck) }
        let safeServerConnect = servers.flatMap { preferenceBool($0, TagName.serversSafeServerConnect) }
        let autoConnectStaticOnly = servers.flatMap { preferenceBool($0, TagName.serversAutoConnectStaticOnly) }
        let manualHighPriority = servers.flatMap { preferenceBool($0, TagName.serversManualHighPriority) }
        let ipFilterLevel = security?.child(named: TagName.ipFilterLevel)?.intValue
        let filterClients = security.flatMap { preferenceBool($0, TagName.ipFilterClients) }
        let filterServers = security.flatMap { preferenceBool($0, TagName.ipFilterServers) }
        let ipFilterAutoUpdate = security.flatMap { preferenceBool($0, TagName.ipFilterAutoUpdate) }
        let ipFilterUpdateURL = security?.child(named: TagName.ipFilterUpdateURL)?.stringValue
        let filterLanIPs = security.flatMap { preferenceBool($0, TagName.ipFilterFilterLan) }
        let secureIdentEnabled = security.flatMap { preferenceBool($0, TagName.securityUseSecureIdent) }
        let obfuscationSupported = security.flatMap { preferenceBool($0, TagName.securityObfuscationSupported) }
        let obfuscationRequested = security.flatMap { preferenceBool($0, TagName.securityObfuscationRequested) }
        let obfuscationRequired = security.flatMap { preferenceBool($0, TagName.securityObfuscationRequired) }
        let webServerEnabled = remoteControls.flatMap { preferenceBool($0, TagName.webServerAutorun) }
        let webServerPort = remoteControls?.child(named: TagName.webServerPort)?.intValue
        let webServerGuestEnabled = remoteControls.flatMap { preferenceBool($0, TagName.webServerGuest) }
        let webServerUseGzip = remoteControls.flatMap { preferenceBool($0, TagName.webServerUseGzip) }
        let webServerRefreshSeconds = remoteControls?.child(named: TagName.webServerRefresh)?.intValue
        let webServerTemplate = remoteControls?.child(named: TagName.webServerTemplate)?.stringValue
        let kademliaUpdateURL = kademlia?.child(named: TagName.kademliaUpdateURL)?.stringValue
        let dlCap = connection?.child(named: TagName.connDLCap)?.intValue
        let ulCap = connection?.child(named: TagName.connULCap)?.intValue
        let slotAllocation = connection?.child(named: TagName.connSlotAllocation)?.intValue
        let maxFileSources = connection?.child(named: TagName.connMaxFileSources)?.intValue
        let maxConn = connection?.child(named: TagName.connMaxConn)?.intValue
        let autoConnect = connection.flatMap { preferenceBool($0, TagName.connAutoConnect) }
        let reconnect = connection.flatMap { preferenceBool($0, TagName.connReconnect) }
        let canSeeShares = security.flatMap { preferenceBool($0, TagName.securityCanSeeShares) }
        return ECConnectionPrefs(
            userNick: userNick,
            userHash: userHash,
            userHost: userHost,
            checkNewVersion: checkNewVersion,
            maxDownload: maxDownload,
            maxUpload: maxUpload,
            tcpPort: tcpPort,
            udpPort: udpPort,
            udpEnabled: udpEnabled,
            ed2kEnabled: ed2kEnabled,
            kadEnabled: kadEnabled,
            messageFilterEnabled: messageFilterEnabled,
            messageFilterAll: messageFilterAll,
            messageFilterFriends: messageFilterFriends,
            messageFilterSecure: messageFilterSecure,
            messageFilterByKeyword: messageFilterByKeyword,
            messageFilterKeywords: messageFilterKeywords,
            onlineSignatureEnabled: onlineSignatureEnabled,
            incomingDirectory: incomingDirectory,
            tempDirectory: tempDirectory,
            sharedDirectories: sharedDirectories,
            shareHiddenFiles: shareHiddenFiles,
            newFilesPaused: newFilesPaused,
            autoDownloadPriority: autoDownloadPriority,
            previewPriority: previewPriority,
            autoUploadPriority: autoUploadPriority,
            saveSources: saveSources,
            extractMetadata: extractMetadata,
            allocateFullFileSize: allocateFullFileSize,
            checkFreeSpace: checkFreeSpace,
            minFreeDiskSpaceMB: minFreeDiskSpaceMB,
            createSparseFiles: createSparseFiles,
            maxConnectionsPerFive: maxConnectionsPerFive,
            verboseLogging: verboseLogging,
            fileBufferSize: fileBufferSize,
            uploadQueueSize: uploadQueueSize,
            serverKeepaliveTimeout: serverKeepaliveTimeout,
            serverUpdateURL: serverUpdateURL,
            removeDeadServers: removeDeadServers,
            deadServerRetries: deadServerRetries,
            autoUpdateServers: autoUpdateServers,
            addServersFromServer: addServersFromServer,
            addServersFromClient: addServersFromClient,
            useServerPrioritySystem: useServerPrioritySystem,
            smartIdCheck: smartIdCheck,
            safeServerConnect: safeServerConnect,
            autoConnectStaticOnly: autoConnectStaticOnly,
            manualHighPriority: manualHighPriority,
            ipFilterLevel: ipFilterLevel,
            filterClients: filterClients,
            filterServers: filterServers,
            ipFilterAutoUpdate: ipFilterAutoUpdate,
            ipFilterUpdateURL: ipFilterUpdateURL,
            filterLanIPs: filterLanIPs,
            secureIdentEnabled: secureIdentEnabled,
            obfuscationSupported: obfuscationSupported,
            obfuscationRequested: obfuscationRequested,
            obfuscationRequired: obfuscationRequired,
            webServerEnabled: webServerEnabled,
            webServerPort: webServerPort,
            webServerGuestEnabled: webServerGuestEnabled,
            webServerUseGzip: webServerUseGzip,
            webServerRefreshSeconds: webServerRefreshSeconds,
            webServerTemplate: webServerTemplate,
            remoteAuthMetadata: nil,
            dlCap: dlCap,
            ulCap: ulCap,
            slotAllocation: slotAllocation,
            maxFileSources: maxFileSources,
            maxConn: maxConn,
            autoConnect: autoConnect,
            reconnect: reconnect,
            canSeeShares: canSeeShares,
            statisticsSupported: false,
            statsGraphUpdateInterval: nil,
            statsDisplayLimit: nil,
            kademliaUpdateURL: kademliaUpdateURL
        )
    }

    private static func preferenceBool(_ parent: ECTag, _ name: UInt16) -> Bool? {
        guard let tag = parent.child(named: name) else { return false }
        if case .uint(let value) = tag.value {
            return value != 0
        }
        return true
    }

    public static func validateSharedFilesUpdate(_ packet: ECPacket) throws {
        try requireOpcode(packet, ECOperations.OpCode.sharedFiles)
    }

    private static func parseDownloadTag(_ tag: ECTag) -> ECDownload? {
        guard tag.name == TagName.partFile else { return nil }
        let name = tag.child(named: TagName.partFileName)?.stringValue ?? ""
        let size = tag.child(named: TagName.partFileSizeFull)?.uintValue ?? 0
        let hasStatus = tag.child(named: TagName.partFileStatus) != nil
        let statusCode = tag.child(named: TagName.partFileStatus)?.intValue ?? 0
        let done = tag.child(named: TagName.partFileSizeDone)?.uintValue ?? 0
        let sourceTotal = tag.child(named: TagName.partFileSourceCount)?.intValue ?? 0
        let sourceNotCurrent = tag.child(named: TagName.partFileSourceCountNotCurrent)?.intValue ?? 0
        let sourcesTransferring = tag.child(named: TagName.partFileSourceCountTransfer)?.intValue ?? 0
        let isStopped = (tag.child(named: TagName.partFileStopped)?.intValue ?? 0) != 0
        let hashingProgressParts = tag.child(named: TagName.partFileHashedPartCount)?.intValue ?? 0
        let displayProgress = hashingProgressParts > 0
            ? progressPercent(done: UInt64(hashingProgressParts) * partSize, size: size, isCompleted: statusCode == 9)
            : nil
        return ECDownload(
            ecid: tag.intValue,
            hash: tag.child(named: TagName.partFileHash)?.hashStringValue ?? tag.hashStringValue,
            name: name,
            size: size,
            done: done,
            transferred: tag.child(named: TagName.partFileSizeTransfer)?.uintValue ?? 0,
            transferredUp: tag.child(named: TagName.partFileSizeXferUp)?.uintValue ?? 0,
            progress: size > 0 ? 100.0 * Double(done) / Double(size) : 0,
            sourcesCurrent: sourceTotal - sourceNotCurrent,
            sourcesTotal: sourceTotal,
            sourcesTransferring: sourcesTransferring,
            sourcesA4AF: tag.child(named: TagName.partFileSourceCountA4AF)?.intValue ?? 0,
            a4afAuto: (tag.child(named: TagName.partFileA4AFAuto)?.intValue ?? 0) != 0,
            downloadActive: (tag.child(named: TagName.partFileDownloadActive)?.intValue ?? 0) != 0,
            statusCode: statusCode,
            isCompleted: statusCode == 9,
            status: partFileStatusText(statusCode, sourcesTransferring: sourcesTransferring, isStopped: isStopped),
            speed: tag.child(named: TagName.partFileSpeed)?.intValue ?? 0,
            priority: tag.child(named: TagName.partFilePriority)?.intValue ?? 0,
            category: tag.child(named: TagName.partFileCategory)?.intValue ?? 0,
            partMet: tag.child(named: TagName.partFilePartMetID)?.stringValue ?? "",
            lastSeenComplete: tag.child(named: TagName.partFileLastSeenComplete)?.uintValue ?? 0,
            lastReceived: tag.child(named: TagName.partFileLastReceived)?.uintValue ?? 0,
            lostCorruption: tag.child(named: TagName.partFileLostCorruption)?.uintValue ?? 0,
            gainedCompression: tag.child(named: TagName.partFileGainedCompression)?.uintValue ?? 0,
            savedICH: tag.child(named: TagName.partFileSavedICH)?.uintValue ?? 0,
            activeSeconds: 0,
            availableParts: tag.child(named: TagName.partFileAvailableParts)?.intValue ?? 0,
            shared: (tag.child(named: TagName.partFileShared)?.intValue ?? 0) != 0,
            ed2kLink: tag.child(named: TagName.partFileEd2kLink)?.stringValue,
            comments: tag.child(named: TagName.partFileComments)?.stringValue,
            a4afSources: tag.child(named: TagName.partFileA4AFSources)?.children.map(\.intValue),
            alternativeNames: parseAlternativeNames(in: tag, currentName: name),
            progressColors: hasStatus || hasProgressStatusTags(tag) ? buildProgressSegments(from: tag, fileSize: size, statusCode: statusCode, isStopped: isStopped, hashingProgressParts: hashingProgressParts) : [],
            isStopped: isStopped,
            hashingProgressParts: hashingProgressParts,
            displayProgress: displayProgress
        )
    }

    private static func progressPercent(done: UInt64, size: UInt64, isCompleted: Bool) -> Double {
        guard size > 0 else { return 0 }
        if isCompleted { return 100 }
        let percent = 100.0 * Double(done) / Double(size)
        return percent > 99.9 ? 99.9 : percent
    }

    private static func hasProgressStatusTags(_ tag: ECTag) -> Bool {
        tag.child(named: TagName.partFileGapStatus) != nil ||
            tag.child(named: TagName.partFilePartStatus) != nil ||
            tag.child(named: TagName.partFileRequestStatus) != nil ||
            tag.child(named: TagName.partFileStopped) != nil ||
            tag.child(named: TagName.partFileHashedPartCount) != nil
    }

    private static func parseAlternativeNames(in tag: ECTag, currentName: String) -> [ECDownload.AlternativeName] {
        guard let sourceNamesTag = tag.child(named: TagName.partFileSourceNames) else { return [] }
        let names = sourceNamesTag.children.compactMap { entry -> ECDownload.AlternativeName? in
            guard entry.name == TagName.partFileSourceNames else { return nil }
            guard let name = entry.child(named: TagName.partFileSourceNames)?.stringValue, !name.isEmpty, name != currentName else {
                return nil
            }
            let count = entry.child(named: TagName.partFileSourceNameCounts)?.intValue ?? 0
            guard count > 0 else { return nil }
            return ECDownload.AlternativeName(name: name, count: count)
        }
        return Array(names.sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.name < rhs.name
        }.prefix(12))
    }

    private static func buildProgressSegments(from tag: ECTag, fileSize: UInt64, statusCode: Int, isStopped: Bool, hashingProgressParts: Int) -> [UInt32] {
        let segmentCount = 64
        let progressColor = packedColor(r: 0, g: 224, b: 0)
        let downloadedColor = packedColor(r: 104, g: 104, b: 104)
        let requestedColor = isStopped ? blendColor(r: 255, g: 208, b: 0, percentage: 50) : packedColor(r: 255, g: 208, b: 0)
        if statusCode == 8 || statusCode == 9 {
            return Array(repeating: progressColor, count: segmentCount)
        }

        if hashingProgressParts > 0 {
            guard fileSize > 0 else { return Array(repeating: progressColor, count: segmentCount) }
            let hashedEnd = min(UInt64(hashingProgressParts) * partSize, fileSize - 1)
            return rasterizedProgressRanges(
                [
                    ColoredProgressRange(start: 0, end: hashedEnd, color: progressColor),
                    ColoredProgressRange(start: min(hashedEnd + 1, fileSize - 1), end: fileSize - 1, color: requestedColor),
                ],
                fileSize: fileSize,
                segmentCount: segmentCount,
                defaultColor: requestedColor
            )
        }

        let gaps = decodeUInt64RLE(tag.child(named: TagName.partFileGapStatus)?.customData)
        let partInfo = decodeByteRLE(tag.child(named: TagName.partFilePartStatus)?.customData)
        let requests = decodeUInt64RLE(tag.child(named: TagName.partFileRequestStatus)?.customData)
        guard !gaps.isEmpty || !partInfo.isEmpty || !requests.isEmpty else { return [] }

        var colorLine = Array(repeating: downloadedColor, count: segmentCount)
        guard fileSize > 0 else { return colorLine }

        var gapRanges: [ColoredProgressRange] = []
        for pairIndex in stride(from: 0, to: gaps.count - (gaps.count % 2), by: 2) {
            let gapStart = gaps[pairIndex]
            let gapEnd = gaps[pairIndex + 1]
            guard gapEnd > gapStart else { continue }

            let startPart = Int(gapStart / partSize)
            let endPart = Int((gapEnd / partSize) + 1)
            guard endPart > startPart else { continue }

            for part in startPart..<endPart {
                var color = packedColor(r: 255, g: 0, b: 0)
                if part < partInfo.count, partInfo[part] > 0 {
                    let green = max(0, 210 - (22 * (Int(partInfo[part]) - 1)))
                    color = packedColor(r: 0, g: green, b: 255)
                }
                if isStopped {
                    color = blendPackedColor(color, percentage: 50)
                }

                let partStart = UInt64(part) * partSize
                let partEnd = UInt64(part + 1) * partSize
                let fillStart = part == startPart ? gapStart : partStart
                let fillEnd = part == endPart - 1 ? gapEnd : partEnd
                guard fillEnd > fillStart else { continue }

                if let last = gapRanges.last, last.end == fillStart, last.color == color {
                    gapRanges[gapRanges.count - 1].end = fillEnd
                } else {
                    gapRanges.append(ColoredProgressRange(start: fillStart, end: fillEnd, color: color))
                }
            }
        }

        var requestRanges: [ColoredProgressRange] = []
        for pairIndex in stride(from: 0, to: requests.count - (requests.count % 2), by: 2) {
            let requestStart = requests[pairIndex]
            let requestEnd = requests[pairIndex + 1]
            guard requestEnd > requestStart else { continue }
            requestRanges.append(ColoredProgressRange(start: requestStart, end: requestEnd, color: requestedColor))
        }

        if fileSize < UInt64(segmentCount) {
            if !requestRanges.isEmpty {
                return Array(repeating: requestedColor, count: segmentCount)
            }
            if let firstGap = gapRanges.first {
                return Array(repeating: firstGap.color, count: segmentCount)
            }
            return colorLine
        }

        let factor = fileSize / UInt64(segmentCount)
        guard factor > 0 else { return colorLine }

        func paint(_ ranges: [ColoredProgressRange]) {
            for range in ranges {
                var start = Int(range.start / factor)
                var end = Int(range.end / factor)
                guard start < segmentCount else { continue }
                start = max(0, start)
                end = min(segmentCount, end)
                if end <= start {
                    end = min(segmentCount, start + 1)
                }
                guard end > start else { continue }
                for position in start..<end {
                    colorLine[position] = range.color
                }
            }
        }

        paint(gapRanges)
        paint(requestRanges)
        return colorLine
    }

    private static func rasterizedProgressRanges(_ ranges: [ColoredProgressRange], fileSize: UInt64, segmentCount: Int, defaultColor: UInt32) -> [UInt32] {
        var colorLine = Array(repeating: defaultColor, count: segmentCount)
        guard fileSize >= UInt64(segmentCount) else {
            if let first = ranges.first {
                return Array(repeating: first.color, count: segmentCount)
            }
            return colorLine
        }
        let factor = fileSize / UInt64(segmentCount)
        guard factor > 0 else { return colorLine }
        for range in ranges where range.end >= range.start {
            var start = Int(range.start / factor)
            var end = Int(range.end / factor)
            guard start < segmentCount else { continue }
            start = max(0, start)
            end = min(segmentCount, end)
            if end <= start {
                end = min(segmentCount, start + 1)
            }
            guard end > start else { continue }
            for position in start..<end {
                colorLine[position] = range.color
            }
        }
        return colorLine
    }

    private static func parseStatsTreeNode(_ tag: ECTag) -> ECStatsTreeNode {
        ECStatsTreeNode(
            id: tag.child(named: TagName.statsTreeNodeID)?.intValue ?? tag.intValue,
            label: tag.stringValue ?? "",
            value: tag.child(named: TagName.statsNodeValue)?.doubleValue ?? Double(tag.child(named: TagName.statsNodeValue)?.uintValue ?? 0),
            children: tag.children.filter { $0.name == TagName.statsTreeNode }.map(parseStatsTreeNode)
        )
    }

    private static let partSize: UInt64 = 9_728_000

    private struct ColoredProgressRange {
        let start: UInt64
        var end: UInt64
        let color: UInt32
    }

    private static func decodeByteRLE(_ data: Data?) -> [UInt8] {
        guard let data else { return [] }
        let bytes = [UInt8](data)
        var decoded: [UInt8] = []
        var index = 0
        while index < bytes.count {
            if index < bytes.count - 2, bytes[index + 1] == bytes[index] {
                decoded.append(contentsOf: repeatElement(bytes[index], count: Int(bytes[index + 2])))
                index += 3
            } else {
                decoded.append(bytes[index])
                index += 1
            }
        }
        return decoded
    }

    private static func decodeUInt64RLE(_ data: Data?) -> [UInt64] {
        let bytes = decodeByteRLE(data)
        guard !bytes.isEmpty, bytes.count % 8 == 0 else { return [] }
        let count = bytes.count / 8
        return (0..<count).map { index in
            var value: UInt64 = 0
            for byteIndex in stride(from: 7, through: 0, by: -1) {
                value <<= 8
                value |= UInt64(bytes[index + byteIndex * count])
            }
            return value
        }
    }

    private static func packedColor(r: Int, g: Int, b: Int) -> UInt32 {
        (UInt32(b & 0xff) << 16) | (UInt32(g & 0xff) << 8) | UInt32(r & 0xff)
    }

    private static func checkFailure(_ packet: ECPacket) throws {
        if packet.opcode == ECOperations.OpCode.failed {
            throw ECResponseParserError.operationFailed(packet.tags.first?.stringValue ?? "Request failed")
        }
    }

    private static func requireOpcode(_ packet: ECPacket, _ expected: UInt8) throws {
        try checkFailure(packet)
        guard packet.opcode == expected else {
            throw ECResponseParserError.unexpectedOpcode(expected: expected, actual: packet.opcode)
        }
    }

    private static func searchStatusText(_ status: Int) -> String {
        switch status {
        case 1: return "Downloaded"
        case 2: return "Queued"
        case 3: return "Canceled"
        case 4: return "Queued (Canceled)"
        default: return "New"
        }
    }

    private static func endpointText(ip: String, port: Int) -> String {
        guard !ip.isEmpty else { return "" }
        return port > 0 ? "\(ip):\(port)" : ip
    }

    private static func partFileStatusText(_ status: Int, sourcesTransferring: Int, isStopped: Bool = false) -> String {
        if isStopped, status != 9 { return "Stopped" }
        switch status {
        case 0, 1:
            return sourcesTransferring > 0 ? "Downloading" : "Waiting"
        case 2, 3: return "Hashing"
        case 4: return "Erroneous"
        case 5: return "Insufficient disk space"
        case 6: return "Unknown"
        case 7: return "Paused"
        case 8: return "Completing"
        case 9: return "Complete"
        case 10: return "Allocating"
        default: return String(status)
        }
    }

    private static func softwareText(_ code: Int) -> String {
        code == 0 ? "Unknown" : String(code)
    }

    private static func sourceFromText(_ code: Int) -> String {
        switch code {
        case 0: return "None"
        case 1: return "Server"
        case 2: return "Kad"
        case 3: return "Source exchange"
        case 4: return "Passive"
        default: return String(code)
        }
    }

    private static func downloadStateText(_ code: Int, queueFull: Bool) -> String {
        if queueFull { return "Remote queue full" }
        switch code {
        case 0: return "None"
        case 1: return "Connecting"
        case 2: return "On queue"
        case 3: return "Downloading"
        case 4: return "No needed parts"
        default: return String(code)
        }
    }

    private static func blendPackedColor(_ color: UInt32, percentage: Int) -> UInt32 {
        let red = Int(color & 0xff)
        let green = Int((color >> 8) & 0xff)
        let blue = Int((color >> 16) & 0xff)
        return blendColor(r: red, g: green, b: blue, percentage: percentage)
    }

    private static func blendColor(r: Int, g: Int, b: Int, percentage: Int) -> UInt32 {
        packedColor(
            r: min(255, (r * percentage) / 100),
            g: min(255, (g * percentage) / 100),
            b: min(255, (b * percentage) / 100)
        )
    }
}

private extension Array where Element == ECTag {
    func first(named name: UInt16) -> ECTag? {
        first { $0.name == name }
    }
}

private extension ECTag {
    func child(named name: UInt16) -> ECTag? {
        children.first { $0.name == name }
    }

    var uintValue: UInt64 {
        if case .uint(let value) = value { return value }
        return 0
    }

    var intValue: Int {
        Int(uintValue)
    }

    var stringValue: String? {
        if case .string(let value) = value { return value }
        return nil
    }

    var doubleValue: Double? {
        switch value {
        case .double(let value): return value
        case .uint(let value): return Double(value)
        default: return nil
        }
    }

    var customData: Data? {
        if case .custom(let data) = value { return data }
        return nil
    }

    var dataValue: Data? {
        switch value {
        case .custom(let data), .hash16(let data), .uint128(let data): return data
        case .empty: return Data()
        default: return nil
        }
    }

    var ipv4Value: (host: String, port: Int)? {
        if case .ipv4(let value) = value {
            return ("\(value.octets.0).\(value.octets.1).\(value.octets.2).\(value.octets.3)", Int(value.port))
        }
        return nil
    }

    var ipStringValue: String? {
        if let endpoint = ipv4Value { return endpoint.host }
        let raw = uintValue
        guard raw != 0 else { return nil }
        return [24, 16, 8, 0]
            .map { String((raw >> UInt64($0)) & 0xff) }
            .joined(separator: ".")
    }

    var hashStringValue: String {
        if case .hash16(let data) = value {
            return data.map { String(format: "%02x", $0) }.joined()
        }
        return ""
    }
}
