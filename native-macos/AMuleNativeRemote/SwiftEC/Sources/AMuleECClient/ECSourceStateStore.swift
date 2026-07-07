import Foundation
import AMuleECProtocol

public struct ECSourceStateStore: Sendable {
    private var sourcesByClientID: [Int: ECSource] = [:]

    public init() {}

    public mutating func applyIncrementalUpdate(_ packet: ECPacket) {
        applyIncrementalUpdate(packet, contextRequestFileID: nil)
    }

    public mutating func applyIncrementalUpdate(_ packet: ECPacket, contextRequestFileID: Int?) {
        let clientTags = packet.tags.flatMap(Self.clientTags(in:))
        let safeContextRequestFileID = contextRequestFileID.flatMap { requestFileID in
            Self.canUseRequestContext(requestFileID, for: clientTags) ? requestFileID : nil
        }
        for tag in clientTags {
            applyClientDelta(tag, requestFileID: safeContextRequestFileID)
        }
    }

    public func sources(for requestFileID: Int) -> [ECSource] {
        sourcesByClientID.values
            .filter { $0.requestFileID == requestFileID }
            .sorted { lhs, rhs in
                if lhs.downloadState != rhs.downloadState { return lhs.downloadState < rhs.downloadState }
                if lhs.downSpeedKBps != rhs.downSpeedKBps { return lhs.downSpeedKBps > rhs.downSpeedKBps }
                if lhs.clientName != rhs.clientName { return lhs.clientName < rhs.clientName }
                return lhs.clientID < rhs.clientID
            }
    }

    private mutating func applyClientDelta(_ tag: ECTag, requestFileID contextRequestFileID: Int?) {
        let clientID = tag.intValue
        guard clientID > 0 else { return }

        if tag.children.isEmpty {
            sourcesByClientID.removeValue(forKey: clientID)
            return
        }

        let existing = sourcesByClientID[clientID]
        let explicitRequestFileID = tag.child(named: TagName.clientRequestFile)?.intValue
        if explicitRequestFileID == 0 {
            sourcesByClientID.removeValue(forKey: clientID)
            return
        }

        let requestFileID = explicitRequestFileID ?? contextRequestFileID ?? existing?.requestFileID ?? 0
        guard requestFileID > 0 else { return }

        let rank = tag.child(named: TagName.clientRemoteQueueRank)?.intValue ?? existing?.remoteQueueRank ?? 0
        let state = tag.child(named: TagName.clientDownloadState)?.intValue ?? existing?.downloadState ?? 0
        let from = tag.child(named: TagName.clientFrom)?.intValue ?? existing?.sourceFrom ?? 0
        let softwareCode = tag.child(named: TagName.clientSoftware)?.intValue
        let softwareVersion = tag.child(named: TagName.clientSoftwareVersion)?.stringValue ?? existing?.softwareVersion ?? ""
        let hasVersionFields = tag.child(named: TagName.clientSoftwareVersion) != nil ||
            tag.child(named: TagName.clientVersion) != nil ||
            tag.child(named: TagName.clientModVersion) != nil

        sourcesByClientID[clientID] = ECSource(
            clientID: clientID,
            requestFileID: requestFileID,
            clientName: tag.child(named: TagName.clientName)?.stringValue ?? existing?.clientName ?? "",
            userIP: tag.child(named: TagName.clientUserIP)?.ipStringValue ?? existing?.userIP ?? "",
            userPort: tag.child(named: TagName.clientUserPort)?.intValue ?? existing?.userPort ?? 0,
            serverName: tag.child(named: TagName.clientServerName)?.stringValue ?? existing?.serverName ?? "",
            serverIP: tag.child(named: TagName.clientServerIP)?.ipStringValue ?? existing?.serverIP ?? "",
            serverPort: tag.child(named: TagName.clientServerPort)?.intValue ?? existing?.serverPort ?? 0,
            software: softwareCode.map(Self.softwareText) ?? existing?.software ?? "Unknown",
            softwareVersion: softwareVersion,
            downloadedTotal: tag.child(named: TagName.clientDownloadTotal).map { Int(clamping: $0.uintValue ?? 0) } ?? existing?.downloadedTotal,
            uploadedTotal: tag.child(named: TagName.clientUploadTotal).map { Int(clamping: $0.uintValue ?? 0) } ?? existing?.uploadedTotal,
            versionString: hasVersionFields ? Self.sourceVersionString(
                softVersion: softwareVersion,
                clientVersion: tag.child(named: TagName.clientVersion)?.uintValue,
                modVersion: tag.child(named: TagName.clientModVersion)?.stringValue,
                existingVersionString: existing?.versionString
            ) : existing?.versionString,
            downloadState: state,
            downloadStateText: Self.downloadStateText(state, queueFull: rank == 0xffff),
            sourceFrom: from,
            sourceFromText: Self.sourceFromText(from),
            downSpeedKBps: tag.child(named: TagName.clientDownSpeed)?.doubleValue ?? existing?.downSpeedKBps ?? 0,
            availableParts: tag.child(named: TagName.clientAvailableParts)?.intValue ?? existing?.availableParts ?? 0,
            remoteQueueRank: rank,
            obfuscationStatus: tag.child(named: TagName.clientObfuscationStatus)?.intValue ?? existing?.obfuscationStatus ?? 0,
            extendedProtocol: tag.child(named: TagName.clientExtendedProtocol)?.boolValue ?? existing?.extendedProtocol ?? false,
            remoteFilename: tag.child(named: TagName.clientRemoteFilename)?.stringValue ?? existing?.remoteFilename ?? "",
            sharesFileList: tag.child(named: TagName.clientDisableViewShared).map { ($0.uintValue ?? 0) == 0 } ?? existing?.sharesFileList,
            clientHash: tag.child(named: TagName.clientHash)?.dataValue ?? existing?.clientHash ?? Data(),
            score: tag.child(named: TagName.clientScore)?.intValue ?? existing?.score ?? 0,
            friendSlot: tag.child(named: TagName.clientFriendSlot)?.boolValue ?? existing?.friendSlot ?? false,
            waitTime: tag.child(named: TagName.clientWaitTime)?.intValue ?? existing?.waitTime ?? 0,
            xferTime: tag.child(named: TagName.clientXferTime)?.intValue ?? existing?.xferTime ?? 0,
            queueTime: tag.child(named: TagName.clientQueueTime)?.intValue ?? existing?.queueTime ?? 0,
            lastTime: tag.child(named: TagName.clientLastTime)?.intValue ?? existing?.lastTime ?? 0,
            isModded: tag.child(named: TagName.clientMod)?.boolValue ?? existing?.isModded ?? false,
            uploadSession: tag.child(named: TagName.clientUploadSession)?.intValue ?? existing?.uploadSession ?? 0,
            uploadState: tag.child(named: TagName.clientUploadState)?.intValue ?? existing?.uploadState ?? 0,
            identState: tag.child(named: TagName.clientIdentState)?.intValue ?? existing?.identState ?? 0,
            uploadSpeed: tag.child(named: TagName.clientUpSpeed)?.intValue ?? existing?.uploadSpeed ?? 0,
            oldRemoteQueueRank: tag.child(named: TagName.clientOldRemoteQueueRank)?.intValue ?? existing?.oldRemoteQueueRank ?? 0,
            waitingPosition: tag.child(named: TagName.clientWaitingPosition)?.intValue ?? existing?.waitingPosition ?? 0,
            userID: tag.child(named: TagName.clientUserID)?.intValue ?? existing?.userID ?? 0,
            kadPort: tag.child(named: TagName.clientKadPort)?.intValue ?? existing?.kadPort ?? 0,
            osInfo: tag.child(named: TagName.clientOSInfo)?.stringValue ?? existing?.osInfo ?? "",
            partStatus: tag.child(named: TagName.clientPartStatus)?.dataValue ?? existing?.partStatus ?? Data(),
            nextRequestedPart: tag.child(named: TagName.clientNextRequestedPart)?.intValue ?? existing?.nextRequestedPart ?? 0,
            lastDownloadingPart: tag.child(named: TagName.clientLastDownloadingPart)?.intValue ?? existing?.lastDownloadingPart ?? 0,
            a4afFiles: tag.child(named: TagName.clientA4AFFiles)?.dataValue ?? existing?.a4afFiles ?? Data(),
            uploadPartStatus: tag.child(named: TagName.clientUploadPartStatus)?.dataValue ?? existing?.uploadPartStatus ?? Data()
        )
    }

    private static func clientTags(in tag: ECTag) -> [ECTag] {
        guard tag.name == TagName.client else { return [] }
        let nested = tag.children.filter { $0.name == TagName.client }
        return nested.isEmpty ? [tag] : nested
    }

    private static func canUseRequestContext(_ requestFileID: Int, for tags: [ECTag]) -> Bool {
        guard requestFileID > 0 else { return false }
        return tags.allSatisfy { tag in
            guard let explicitRequestFileID = tag.child(named: TagName.clientRequestFile)?.intValue, explicitRequestFileID > 0 else {
                return true
            }
            return explicitRequestFileID == requestFileID
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

    private static func sourceVersionString(softVersion: String, clientVersion: UInt64?, modVersion: String?, existingVersionString: String?) -> String? {
        var text = softVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty, let clientVersion, clientVersion > 0 {
            text = String(clientVersion)
        }
        if text.isEmpty {
            text = existingVersionString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }

        let modText = modVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !modText.isEmpty, text.isEmpty {
            text = modText
        } else if !modText.isEmpty, text.range(of: modText, options: [.caseInsensitive, .diacriticInsensitive]) == nil {
            text += " - \(modText)"
        }

        return text.isEmpty ? nil : text
    }

    private enum TagName {
        static let clientVersion: UInt16 = 0x0101
        static let clientMod: UInt16 = 0x0102
        static let client: UInt16 = 0x0600
        static let clientSoftware: UInt16 = 0x0601
        static let clientScore: UInt16 = 0x0602
        static let clientHash: UInt16 = 0x0603
        static let clientFriendSlot: UInt16 = 0x0604
        static let clientWaitTime: UInt16 = 0x0605
        static let clientXferTime: UInt16 = 0x0606
        static let clientQueueTime: UInt16 = 0x0607
        static let clientLastTime: UInt16 = 0x0608
        static let clientUploadSession: UInt16 = 0x0609
        static let clientUploadTotal: UInt16 = 0x060A
        static let clientDownloadTotal: UInt16 = 0x060B
        static let clientName: UInt16 = 0x0100
        static let clientDownloadState: UInt16 = 0x060C
        static let clientUpSpeed: UInt16 = 0x060D
        static let clientDownSpeed: UInt16 = 0x060E
        static let clientFrom: UInt16 = 0x060F
        static let clientUserIP: UInt16 = 0x0610
        static let clientUserPort: UInt16 = 0x0611
        static let clientServerIP: UInt16 = 0x0612
        static let clientServerPort: UInt16 = 0x0613
        static let clientServerName: UInt16 = 0x0614
        static let clientSoftwareVersion: UInt16 = 0x0615
        static let clientWaitingPosition: UInt16 = 0x0616
        static let clientIdentState: UInt16 = 0x0617
        static let clientObfuscationStatus: UInt16 = 0x0618
        static let clientRemoteQueueRank: UInt16 = 0x061A
        static let clientDisableViewShared: UInt16 = 0x061B
        static let clientUploadState: UInt16 = 0x061C
        static let clientExtendedProtocol: UInt16 = 0x061D
        static let clientUserID: UInt16 = 0x061E
        static let clientRequestFile: UInt16 = 0x0620
        static let clientA4AFFiles: UInt16 = 0x0621
        static let clientOldRemoteQueueRank: UInt16 = 0x0622
        static let clientKadPort: UInt16 = 0x0623
        static let clientPartStatus: UInt16 = 0x0624
        static let clientNextRequestedPart: UInt16 = 0x0625
        static let clientLastDownloadingPart: UInt16 = 0x0626
        static let clientRemoteFilename: UInt16 = 0x0627
        static let clientModVersion: UInt16 = 0x0628
        static let clientOSInfo: UInt16 = 0x0629
        static let clientAvailableParts: UInt16 = 0x062A
        static let clientUploadPartStatus: UInt16 = 0x062B
    }
}

private extension ECTag {
    func child(named name: UInt16) -> ECTag? {
        children.first { $0.name == name }
    }

    var uintValue: UInt64? {
        if case .uint(let value) = value { return value }
        return nil
    }

    var intValue: Int {
        Int(uintValue ?? 0)
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

    var boolValue: Bool? {
        guard let uintValue else { return nil }
        return uintValue != 0
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
        guard let raw = uintValue, raw != 0 else { return nil }
        return [24, 16, 8, 0]
            .map { String((raw >> UInt64($0)) & 0xff) }
            .joined(separator: ".")
    }
}
