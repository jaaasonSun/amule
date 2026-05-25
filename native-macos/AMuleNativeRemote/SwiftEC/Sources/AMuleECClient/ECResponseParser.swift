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
        public static let statsUploadSpeed: UInt16 = 0x0200
        public static let statsDownloadSpeed: UInt16 = 0x0201
        public static let statsTotalSourceCount: UInt16 = 0x0206
        public static let statsUploadQueueLength: UInt16 = 0x0208
        public static let partFile: UInt16 = 0x0300
        public static let partFileName: UInt16 = 0x0301
        public static let partFilePartMetID: UInt16 = 0x0302
        public static let partFileSizeFull: UInt16 = 0x0303
        public static let partFileSizeTransfer: UInt16 = 0x0304
        public static let partFileSizeDone: UInt16 = 0x0306
        public static let partFileSpeed: UInt16 = 0x0307
        public static let partFileStatus: UInt16 = 0x0308
        public static let partFilePriority: UInt16 = 0x0309
        public static let partFileSourceCount: UInt16 = 0x030A
        public static let partFileSourceCountA4AF: UInt16 = 0x030B
        public static let partFileSourceCountNotCurrent: UInt16 = 0x030C
        public static let partFileSourceCountTransfer: UInt16 = 0x030D
        public static let partFileCategory: UInt16 = 0x030F
        public static let partFileLastReceived: UInt16 = 0x0310
        public static let partFileLastSeenComplete: UInt16 = 0x0311
        public static let partFilePartStatus: UInt16 = 0x0312
        public static let partFileGapStatus: UInt16 = 0x0313
        public static let partFileRequestStatus: UInt16 = 0x0314
        public static let partFileSourceNames: UInt16 = 0x0315
        public static let partFileSourceNameCounts: UInt16 = 0x031C
        public static let partFileAvailableParts: UInt16 = 0x031D
        public static let partFileHash: UInt16 = 0x031E
        public static let partFileShared: UInt16 = 0x031F
        public static let knownFile: UInt16 = 0x0400
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
        public static let prefsConnections: UInt16 = 0x1300
        public static let connMaxDownload: UInt16 = 0x1303
        public static let connMaxUpload: UInt16 = 0x1304
        public static let client: UInt16 = 0x0600
        public static let clientSoftware: UInt16 = 0x0601
        public static let clientName: UInt16 = 0x0100
        public static let clientDownloadState: UInt16 = 0x060C
        public static let clientDownSpeed: UInt16 = 0x060E
        public static let clientFrom: UInt16 = 0x060F
        public static let clientUserIP: UInt16 = 0x0610
        public static let clientUserPort: UInt16 = 0x0611
        public static let clientServerIP: UInt16 = 0x0612
        public static let clientServerPort: UInt16 = 0x0613
        public static let clientServerName: UInt16 = 0x0614
        public static let clientSoftwareVersion: UInt16 = 0x0615
        public static let clientObfuscationStatus: UInt16 = 0x0618
        public static let clientRemoteQueueRank: UInt16 = 0x061A
        public static let clientExtendedProtocol: UInt16 = 0x061D
        public static let clientUploadFile: UInt16 = 0x061F
        public static let clientRequestFile: UInt16 = 0x0620
        public static let clientRemoteFilename: UInt16 = 0x0627
        public static let clientAvailableParts: UInt16 = 0x062A
        public static let clientUploadTotal: UInt16 = 0x060A
        public static let clientDownloadTotal: UInt16 = 0x060B
        public static let clientUpSpeed: UInt16 = 0x060D
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
        let state = packet.tags.first(named: TagName.connState)?.uintValue ?? 0
        return ECStatus(
            connected: state != 0,
            ed2k: state != 0 ? "Connected" : "Not connected",
            kad: "Unknown",
            downloadSpeed: packet.tags.first(named: TagName.statsDownloadSpeed)?.intValue ?? 0,
            uploadSpeed: packet.tags.first(named: TagName.statsUploadSpeed)?.intValue ?? 0,
            queue: packet.tags.first(named: TagName.statsUploadQueueLength)?.intValue ?? 0,
            sources: packet.tags.first(named: TagName.statsTotalSourceCount)?.intValue ?? 0
        )
    }

    public static func parseDownloads(_ packet: ECPacket) throws -> [ECDownload] {
        try requireOpcode(packet, ECOperations.OpCode.downloadQueue)
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

        return clientTags.compactMap { tag in
            guard tag.child(named: TagName.clientRequestFile)?.intValue == requestFileID else { return nil }
            let state = tag.child(named: TagName.clientDownloadState)?.intValue ?? 0
            let from = tag.child(named: TagName.clientFrom)?.intValue ?? 0
            let rank = tag.child(named: TagName.clientRemoteQueueRank)?.intValue ?? 0
            return ECSource(
                clientID: tag.intValue,
                requestFileID: requestFileID,
                clientName: tag.child(named: TagName.clientName)?.stringValue ?? "",
                userIP: tag.child(named: TagName.clientUserIP)?.ipStringValue ?? "",
                userPort: tag.child(named: TagName.clientUserPort)?.intValue ?? 0,
                serverName: tag.child(named: TagName.clientServerName)?.stringValue ?? "",
                serverIP: tag.child(named: TagName.clientServerIP)?.ipStringValue ?? "",
                serverPort: tag.child(named: TagName.clientServerPort)?.intValue ?? 0,
                software: softwareText(tag.child(named: TagName.clientSoftware)?.intValue ?? 0),
                softwareVersion: tag.child(named: TagName.clientSoftwareVersion)?.stringValue ?? "",
                downloadState: state,
                downloadStateText: downloadStateText(state, queueFull: rank == 0xffff),
                sourceFrom: from,
                sourceFromText: sourceFromText(from),
                downSpeedKBps: tag.child(named: TagName.clientDownSpeed)?.doubleValue ?? 0,
                availableParts: tag.child(named: TagName.clientAvailableParts)?.intValue ?? 0,
                remoteQueueRank: rank,
                obfuscationStatus: tag.child(named: TagName.clientObfuscationStatus)?.intValue ?? 0,
                extendedProtocol: (tag.child(named: TagName.clientExtendedProtocol)?.intValue ?? 0) != 0,
                remoteFilename: tag.child(named: TagName.clientRemoteFilename)?.stringValue ?? ""
            )
        }.sorted { lhs, rhs in
            if lhs.downloadState != rhs.downloadState { return lhs.downloadState < rhs.downloadState }
            if lhs.downSpeedKBps != rhs.downSpeedKBps { return lhs.downSpeedKBps > rhs.downSpeedKBps }
            if lhs.clientName != rhs.clientName { return lhs.clientName < rhs.clientName }
            return lhs.clientID < rhs.clientID
        }
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
                comment: tag.child(named: TagName.knownFileComment)?.stringValue,
                rating: tag.child(named: TagName.knownFileRating)?.intValue
            )
        }
    }

    public static func parseCoreLog(_ packet: ECPacket, kind: String) throws -> ECCoreLog {
        try requireOpcode(packet, kind == "debug" ? ECOperations.OpCode.debugLog : ECOperations.OpCode.log)
        return ECCoreLog(kind: kind, lines: packet.tags.compactMap(\.stringValue))
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
        guard let prefs = packet.tags.first(named: TagName.prefsConnections) else {
            throw ECResponseParserError.missingPreferences
        }
        guard let maxDL = prefs.child(named: TagName.connMaxDownload), let maxUL = prefs.child(named: TagName.connMaxUpload) else {
            throw ECResponseParserError.missingPreferences
        }
        return ECConnectionPrefs(maxDownload: maxDL.intValue, maxUpload: maxUL.intValue)
    }

    public static func validateSharedFilesUpdate(_ packet: ECPacket) throws {
        try requireOpcode(packet, ECOperations.OpCode.sharedFiles)
    }

    private static func parseDownloadTag(_ tag: ECTag) -> ECDownload? {
        guard tag.name == TagName.partFile || tag.child(named: TagName.partFileHash) != nil else { return nil }
        guard tag.child(named: TagName.partFileHash) != nil else { return nil }
        let size = tag.child(named: TagName.partFileSizeFull)?.uintValue ?? 0
        let hasStatus = tag.child(named: TagName.partFileStatus) != nil
        let statusCode = tag.child(named: TagName.partFileStatus)?.intValue ?? 9
        let done = tag.child(named: TagName.partFileSizeDone)?.uintValue ?? (hasStatus ? 0 : size)
        let sourceTotal = tag.child(named: TagName.partFileSourceCount)?.intValue ?? 0
        let sourceNotCurrent = tag.child(named: TagName.partFileSourceCountNotCurrent)?.intValue ?? 0
        let name = tag.child(named: TagName.partFileName)?.stringValue ?? ""
        return ECDownload(
            ecid: tag.intValue,
            hash: tag.child(named: TagName.partFileHash)?.hashStringValue ?? tag.hashStringValue,
            name: name,
            size: size,
            done: done,
            transferred: tag.child(named: TagName.partFileSizeTransfer)?.uintValue ?? (hasStatus ? 0 : size),
            progress: size > 0 ? 100.0 * Double(done) / Double(size) : 0,
            sourcesCurrent: hasStatus ? sourceTotal - sourceNotCurrent : 0,
            sourcesTotal: hasStatus ? sourceTotal : 0,
            sourcesTransferring: hasStatus ? (tag.child(named: TagName.partFileSourceCountTransfer)?.intValue ?? 0) : 0,
            sourcesA4AF: hasStatus ? (tag.child(named: TagName.partFileSourceCountA4AF)?.intValue ?? 0) : 0,
            statusCode: statusCode,
            isCompleted: statusCode == 9,
            status: partFileStatusText(statusCode, sourcesTransferring: hasStatus ? (tag.child(named: TagName.partFileSourceCountTransfer)?.intValue ?? 0) : 0),
            speed: hasStatus ? (tag.child(named: TagName.partFileSpeed)?.intValue ?? 0) : 0,
            priority: hasStatus ? (tag.child(named: TagName.partFilePriority)?.intValue ?? 0) : 0,
            category: hasStatus ? (tag.child(named: TagName.partFileCategory)?.intValue ?? 0) : 0,
            partMet: hasStatus ? (tag.child(named: TagName.partFilePartMetID)?.stringValue ?? "") : "",
            lastSeenComplete: hasStatus ? (tag.child(named: TagName.partFileLastSeenComplete)?.uintValue ?? 0) : 0,
            lastReceived: hasStatus ? (tag.child(named: TagName.partFileLastReceived)?.uintValue ?? 0) : 0,
            activeSeconds: 0,
            availableParts: hasStatus ? (tag.child(named: TagName.partFileAvailableParts)?.intValue ?? 0) : 0,
            shared: hasStatus ? ((tag.child(named: TagName.partFileShared)?.intValue ?? 0) != 0) : false,
            alternativeNames: parseAlternativeNames(in: tag, currentName: name),
            progressColors: hasStatus ? buildProgressSegments(from: tag, fileSize: size) : []
        )
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

    private static func buildProgressSegments(from tag: ECTag, fileSize: UInt64) -> [UInt32] {
        let gaps = decodeUInt64RLE(tag.child(named: TagName.partFileGapStatus)?.customData)
        let partInfo = decodeByteRLE(tag.child(named: TagName.partFilePartStatus)?.customData)
        let requests = decodeUInt64RLE(tag.child(named: TagName.partFileRequestStatus)?.customData)
        guard !gaps.isEmpty || !partInfo.isEmpty || !requests.isEmpty else { return [] }

        let segmentCount = 64
        let downloadedColor = packedColor(r: 104, g: 104, b: 104)
        let requestedColor = packedColor(r: 255, g: 208, b: 0)
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

    private static func partFileStatusText(_ status: Int, sourcesTransferring: Int) -> String {
        switch status {
        case 0, 1:
            return sourcesTransferring > 0 ? "Downloading" : "Waiting"
        case 2: return "Waiting for hash"
        case 3: return "Hashing"
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
