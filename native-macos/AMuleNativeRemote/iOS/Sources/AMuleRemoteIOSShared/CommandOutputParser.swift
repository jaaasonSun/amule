import Foundation
import AMuleECClient
import SharedUI

public struct DownloadAlternativeName: Hashable, Identifiable {
    public let name: String
    public let count: Int

    public init(name: String, count: Int) {
        self.name = name
        self.count = count
    }

    public var id: String { "\(name)|\(count)" }

    public var meaningfulNameEncodingSuggestion: String? {
        FileNameEncodingRepair.repairedSuggestion(for: name)
    }
}

@available(macOS 12.0, iOS 15.0, *)
public struct SearchResult: Identifiable, Hashable {
    public let index: Int
    public let hash: String
    public let name: String
    public let sizeBytes: UInt64
    public let sources: Int
    public let completeSources: Int
    public let statusCode: Int
    public let status: String
    public let parentID: Int
    public let alreadyHave: Bool

    public var id: String { "\(index)" }

    public var sizeDisplay: String {
        AMuleFormatter.fileSize(sizeBytes)
    }

    public var alreadyHaveText: String {
        alreadyHave ? "Yes" : "No"
    }

    public var haveSortValue: Int {
        alreadyHave ? 1 : 0
    }

    public static func fromBridge(_ payload: [BridgeSearchPayload]) -> [SearchResult] {
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

@available(macOS 12.0, iOS 15.0, *)
public struct DownloadItem: Identifiable, Hashable {
    public let ecid: Int
    public let id: String
    public let name: String
    public let nameEncodingSuspect: Bool
    public let nameEncodingSuggestion: String?
    public let sizeBytes: UInt64
    public let doneBytes: UInt64
    public let transferredBytes: UInt64
    public let progressValue: Double
    public let sourceCurrent: Int
    public let sourceTotal: Int
    public let sourceTransferring: Int
    public let sourceA4AF: Int
    public let statusCode: Int
    public let isCompleted: Bool
    public let status: String
    public let speedBytes: Int
    public let priority: Int
    public let category: Int
    public let partMetName: String
    public let lastSeenComplete: UInt64
    public let lastReceived: UInt64
    public let activeSeconds: Int
    public let availableParts: Int
    public let shared: Bool
    public let alternativeNames: [DownloadAlternativeName]
    public let progressColors: [UInt32]

    public init(ecid: Int, id: String, name: String, nameEncodingSuspect: Bool, nameEncodingSuggestion: String?, sizeBytes: UInt64, doneBytes: UInt64, transferredBytes: UInt64, progressValue: Double, sourceCurrent: Int, sourceTotal: Int, sourceTransferring: Int, sourceA4AF: Int, statusCode: Int, isCompleted: Bool, status: String, speedBytes: Int, priority: Int, category: Int, partMetName: String, lastSeenComplete: UInt64, lastReceived: UInt64, activeSeconds: Int, availableParts: Int, shared: Bool, alternativeNames: [DownloadAlternativeName], progressColors: [UInt32]) {
        self.ecid = ecid
        self.id = id
        self.name = name
        self.nameEncodingSuspect = nameEncodingSuspect
        self.nameEncodingSuggestion = nameEncodingSuggestion
        self.sizeBytes = sizeBytes
        self.doneBytes = doneBytes
        self.transferredBytes = transferredBytes
        self.progressValue = progressValue
        self.sourceCurrent = sourceCurrent
        self.sourceTotal = sourceTotal
        self.sourceTransferring = sourceTransferring
        self.sourceA4AF = sourceA4AF
        self.statusCode = statusCode
        self.isCompleted = isCompleted
        self.status = status
        self.speedBytes = speedBytes
        self.priority = priority
        self.category = category
        self.partMetName = partMetName
        self.lastSeenComplete = lastSeenComplete
        self.lastReceived = lastReceived
        self.activeSeconds = activeSeconds
        self.availableParts = availableParts
        self.shared = shared
        self.alternativeNames = alternativeNames
        self.progressColors = progressColors
    }

    public var meaningfulNameEncodingSuggestion: String? {
        guard let suggestion = nameEncodingSuggestion else { return nil }
        let trimmedSuggestion = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSuggestion.isEmpty else { return nil }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedSuggestion == trimmedName ? nil : trimmedSuggestion
    }

    public var hasMeaningfulNameEncodingSuggestion: Bool {
        meaningfulNameEncodingSuggestion != nil
    }

    public var trimmedDisplayName: String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? nil : trimmedName
    }

    public func displayedNameEncodingValue(alwaysShowDiagnostic: Bool) -> String? {
        if let suggestion = meaningfulNameEncodingSuggestion {
            return suggestion
        }

        guard alwaysShowDiagnostic else { return nil }
        return trimmedDisplayName
    }

    public func usesDiagnosticNameEncodingFallback(alwaysShowDiagnostic: Bool) -> Bool {
        meaningfulNameEncodingSuggestion == nil && displayedNameEncodingValue(alwaysShowDiagnostic: alwaysShowDiagnostic) != nil
    }

    public func hasDisplayedNameEncodingValue(alwaysShowDiagnostic: Bool) -> Bool {
        displayedNameEncodingValue(alwaysShowDiagnostic: alwaysShowDiagnostic) != nil
    }

    public var progressDisplayValue: Double {
        let clamped = max(0, min(progressValue, 100))
        return floor(clamped * 10.0) / 10.0
    }

    public var progressSortValue: Double {
        max(0, min(progressValue, 100))
    }

    public var isCompletedLike: Bool {
        if isCompleted || statusCode == 9 {
            return true
        }
        if sizeBytes > 0 && doneBytes >= sizeBytes {
            return true
        }
        return false
    }

    public var speedSortValue: Int {
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

    public var progressText: String {
        String(format: "%.1f%%", progressDisplayValue)
    }

    public var sourcesText: String {
        "\(sourceCurrent)/\(sourceTotal)"
    }

    public var speedText: String {
        AMuleFormatter.speed(bytesPerSecond: speedBytes)
    }

    public var completionText: String {
        "\(AMuleFormatter.fileSize(doneBytes)) / \(AMuleFormatter.fileSize(sizeBytes))"
    }

    public var transferredText: String {
        AMuleFormatter.fileSize(transferredBytes)
    }

    public var activeTimeText: String {
        AMuleFormatter.duration(seconds: activeSeconds)
    }

    public var lastSeenCompleteText: String {
        AMuleFormatter.dateTime(unix: lastSeenComplete)
    }

    public var lastReceivedText: String {
        AMuleFormatter.dateTime(unix: lastReceived)
    }

    public var priorityText: String {
        AMuleFormatter.priority(priority)
    }

    public var ed2kLink: String {
        let sanitizedName = name
            .replacingOccurrences(of: "|", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
        let encodedName = sanitizedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? sanitizedName
        return "ed2k://|file|\(encodedName)|\(sizeBytes)|\(id)|/"
    }

    public static func fromBridge(_ payload: [BridgeDownloadPayload]) -> [DownloadItem] {
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
                progressColors: $0.progressColors
            )
        }
    }
}

@available(macOS 12.0, iOS 15.0, *)
public struct DownloadSourceItem: Identifiable, Hashable, Sendable {
    public let id: Int
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

    public init(id: Int, requestFileID: Int, clientName: String, userIP: String, userPort: Int, serverName: String, serverIP: String, serverPort: Int, software: String, softwareVersion: String, downloadState: Int, downloadStateText: String, sourceFrom: Int, sourceFromText: String, downSpeedKBps: Double, availableParts: Int, remoteQueueRank: Int, obfuscationStatus: Int, extendedProtocol: Bool, remoteFilename: String) {
        self.id = id
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

    public var clientDisplayName: String {
        clientName.isEmpty ? "(unknown client)" : clientName
    }

    public var endpoint: String {
        if !userIP.isEmpty, userPort > 0 {
            return "\(userIP):\(userPort)"
        }
        if !userIP.isEmpty {
            return userIP
        }
        return "-"
    }

    public var serverEndpoint: String {
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

    public var softwareDisplay: String {
        if softwareVersion.isEmpty {
            return software
        }
        return "\(software) \(softwareVersion)"
    }

    public var speedText: String {
        guard downSpeedKBps > 0 else { return "-" }
        let bytesPerSecond = Int((downSpeedKBps * 1024.0).rounded())
        return AMuleFormatter.speed(bytesPerSecond: bytesPerSecond)
    }

    public var queueRankText: String {
        remoteQueueRank == 0xffff ? "Full" : String(remoteQueueRank)
    }

    public static func fromBridge(_ payload: [BridgeDownloadSourcePayload]) -> [DownloadSourceItem] {
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

public enum SourceDownloadState: Int {
    case connecting          = 1
    case onQueue             = 2
    case downloading         = 4
    case tooManyConnections  = 5
}

public struct ServerItem: Identifiable, Hashable {
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

    public var endpointText: String {
        if !address.isEmpty {
            return address
        }
        if !ip.isEmpty {
            return port > 0 ? "\(ip):\(port)" : ip
        }
        return "-"
    }

    public var usersText: String {
        if maxUsers > 0 {
            return "\(users)/\(maxUsers)"
        }
        return String(users)
    }

    public static func fromBridge(_ payload: [BridgeServerPayload]) -> [ServerItem] {
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

@available(macOS 12.0, iOS 15.0, *)
public enum AMuleFormatter {
    public static func speed(bytesPerSecond: Int) -> String {
        guard bytesPerSecond > 0 else {
            return "-"
        }
        let text = ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .binary)
            .replacingOccurrences(of: " bytes", with: " B")
            .replacingOccurrences(of: " byte", with: " B")
        return "\(text)/s"
    }

    public static func fileSize(_ bytes: UInt64) -> String {
        if bytes > UInt64(Int64.max) {
            return ByteCountFormatter.string(fromByteCount: Int64.max, countStyle: .file)
        }
        return fileSize(Int64(bytes))
    }

    public static func fileSize(_ bytes: Int64) -> String {
        guard bytes > 0 else {
            return "-"
        }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    public static func duration(seconds: Int) -> String {
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

    @available(macOS 12.0, iOS 15.0, *)
    public static func dateTime(unix: UInt64) -> String {
        guard unix > 0 else {
            return "-"
        }
        let date = Date(timeIntervalSince1970: TimeInterval(unix))
        return date.formatted(date: .numeric, time: .standard)
    }

    public static func priority(_ value: Int) -> String {
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

extension DownloadItem: DownloadClassifiable {}
