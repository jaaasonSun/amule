import Foundation
import AMuleECClient
import SharedCore
import SharedUI

struct BridgeStatsPayload: Decodable {
    let tree: BridgeStatsTreeNodePayload?
    let graphs: BridgeStatsGraphsPayload?
}

struct BridgeEnvelope: Decodable {
    let ok: Bool
    let error: String?
    let message: String?
    let schemaVersion: Int?
    let capabilities: BridgeCapabilitiesPayload?
    let status: BridgeStatusPayload?
    let downloads: [BridgeDownloadPayload]?
    let sources: [BridgeDownloadSourcePayload]?
    let uploads: [BridgeUploadPayload]?
    let sharedFiles: [BridgeSharedFilePayload]?
    let log: BridgeCoreLogPayload?
    let prefsConnection: BridgeConnectionPrefsPayload?
    let categories: [BridgeCategoryPayload]?
    let friends: [BridgeFriendPayload]?
    let stats: BridgeStatsPayload?
    let servers: [BridgeServerPayload]?
    let progress: Int?
    let results: [BridgeSearchPayload]?

    private enum CodingKeys: String, CodingKey {
        case ok, error, message, capabilities, status, downloads, sources, uploads, log, categories, friends, stats, servers, progress, results
        case schemaVersion = "schema_version"
        case sharedFiles = "shared_files"
        case prefsConnection = "prefs_connection"
    }
}


struct DownloadAlternativeName: Hashable, Identifiable {
    let name: String
    let count: Int

    var id: String { "\(name)|\(count)" }

    var meaningfulNameEncodingSuggestion: String? {
        FileNameEncodingRepair.repairedSuggestion(for: name)
    }
}

struct SearchResult: Identifiable, Hashable {
    let index: Int
    let hash: String
    let name: String
    let sizeBytes: UInt64
    let sources: Int
    let completeSources: Int
    let statusCode: Int
    let status: String
    let parentID: Int
    let alreadyHave: Bool

    var id: String { "\(index)" }

    var sizeDisplay: String {
        AMuleFormatter.fileSize(sizeBytes)
    }

    var alreadyHaveText: String {
        alreadyHave ? "Yes" : "No"
    }

    var haveSortValue: Int {
        alreadyHave ? 1 : 0
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

struct DownloadItem: Identifiable, Hashable, RenameVerifiableDownload {
    let ecid: Int
    let id: String
    let name: String
    let nameEncodingSuspect: Bool
    let nameEncodingSuggestion: String?
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

    var meaningfulNameEncodingSuggestion: String? {
        guard let suggestion = nameEncodingSuggestion else { return nil }
        let trimmedSuggestion = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSuggestion.isEmpty else { return nil }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedSuggestion == trimmedName ? nil : trimmedSuggestion
    }

    var hasMeaningfulNameEncodingSuggestion: Bool {
        meaningfulNameEncodingSuggestion != nil
    }

    var trimmedDisplayName: String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? nil : trimmedName
    }

    func displayedNameEncodingValue(alwaysShowDiagnostic: Bool) -> String? {
        if let suggestion = meaningfulNameEncodingSuggestion {
            return suggestion
        }

        guard alwaysShowDiagnostic else { return nil }
        return trimmedDisplayName
    }

    func usesDiagnosticNameEncodingFallback(alwaysShowDiagnostic: Bool) -> Bool {
        meaningfulNameEncodingSuggestion == nil && displayedNameEncodingValue(alwaysShowDiagnostic: alwaysShowDiagnostic) != nil
    }

    func hasDisplayedNameEncodingValue(alwaysShowDiagnostic: Bool) -> Bool {
        displayedNameEncodingValue(alwaysShowDiagnostic: alwaysShowDiagnostic) != nil
    }

    var progressDisplayValue: Double {
        let clamped = max(0, min(progressValue, 100))
        return floor(clamped * 10.0) / 10.0
    }

    var progressSortValue: Double {
        max(0, min(progressValue, 100))
    }

    var isCompletedLike: Bool {
        if isCompleted || statusCode >= 8 {
            return true
        }
        if sizeBytes > 0 && doneBytes >= sizeBytes {
            return true
        }
        return false
    }

    var speedSortValue: Int {
        if speedBytes > 0 {
            return 2_000_000_000 + max(0, speedBytes)
        }
        if isCompletedLike {
            return 1_000_000_000
        }
        return 0
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

extension DownloadItem: DownloadClassifiable {}

enum MacOSDownloadClassification {
    static func isCompleted(_ item: DownloadItem) -> Bool {
        DownloadClassification.isCompleted(item)
    }

    static func isPaused(_ item: DownloadItem) -> Bool {
        DownloadClassification.isPaused(item)
    }

    static func isDownloading(_ item: DownloadItem) -> Bool {
        DownloadClassification.isDownloading(item)
    }

    static func isPending(_ item: DownloadItem) -> Bool {
        DownloadClassification.isPending(item)
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

    var endpointText: String {
        if !address.isEmpty {
            return address
        }
        if !ip.isEmpty {
            return port > 0 ? "\(ip):\(port)" : ip
        }
        return "-"
    }

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
