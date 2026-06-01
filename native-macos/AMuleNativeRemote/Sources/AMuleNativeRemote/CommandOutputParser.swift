import Foundation
import AMuleECClient
import AMuleECBridgeAdapter
import SharedModels
import SharedServices
import SharedViews

typealias DownloadAlternativeName = SharedModels.DownloadAlternativeName
typealias SearchResult = SharedModels.SearchResult
typealias DownloadItem = SharedModels.DownloadItem
typealias ServerItem = SharedModels.ServerItem

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
extension DownloadItem: @retroactive RenameVerifiableDownload {}
extension DownloadItem: @retroactive DownloadClassifiable {}

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
