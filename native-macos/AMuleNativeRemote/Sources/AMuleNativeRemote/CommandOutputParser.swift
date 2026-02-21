import Foundation

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

    var id: String { hash }

    var sizeDisplay: String {
        AMuleFormatter.fileSize(sizeBytes)
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
                    sources: $0.sources
                )
            }
    }
}

struct DownloadItem: Identifiable, Hashable {
    let ecid: Int
    let id: String
    let name: String
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

    var progressDisplayValue: Double {
        let clamped = max(0, min(progressValue, 100))
        return floor(clamped * 10.0) / 10.0
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
