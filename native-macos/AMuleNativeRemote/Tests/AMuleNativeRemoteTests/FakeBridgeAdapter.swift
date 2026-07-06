import Foundation
import AMuleECBridgeAdapter
import AMuleECClient
import enum AMuleECBridgeAdapter.RenameAcknowledgement
import SharedModels
import SharedServices

@testable import AMuleNativeRemote

final class FakeBridgeAdapter: BridgeProtocol, @unchecked Sendable {
    var capabilitiesResult: (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String)
    var statusResult: (BridgeStatusPayload, String)
    var downloadsResult: ([BridgeDownloadPayload], String) = ([], #"{"ok":true,"downloads":[]}"#)
    var categoriesResult: ([BridgeCategoryPayload], String) = ([], #"{"ok":true,"categories":[]}"#)
    var searchResult: (progress: Int, results: [BridgeSearchPayload], raw: String) = (0, [], #"{"ok":true,"progress":0,"results":[]}"#)
    var messageRaw: String = #"{"ok":true,"message":"ok"}"#
    var renameResult: RenameAcknowledgement = .success(message: "ok", raw: #"{"ok":true,"message":"ok"}"#)
    var invokedOperations: [String] = []
    var lastSearchRequest: ECSearchRequest?
    var lastDownloadCategoryID: Int?
    var lastA4AFMode: ECOperations.A4AFSwapMode?
    var lastSharedFilePriorityHash: String?
    var lastSharedFilePriority: Int?
    var lastSharedFileCommentHash: String?
    var lastSharedFileComment: String?
    var lastSharedFileRating: Int?
    var lastServerStaticECID: Int?
    var lastServerStatic: Bool?
    var lastServerPriorityECID: Int?
    var lastServerPriority: Int?
    var lastFriendAdd: (hash: String, ip: String, port: Int, name: String)?
    var lastFriendSharedListID: Int?
    var serverInfoResult: (BridgeCoreLogPayload, String) = (
        BridgeCoreLogPayload(kind: "server-info", lines: ["server log"]),
        #"{"ok":true,"log":{"kind":"server-info","lines":["server log"]}}"#
    )

    var capabilityOps: Set<String> {
        get { Set(capabilitiesResult.capabilities.ops) }
        set {
            let capabilities = capabilitiesResult.capabilities
            capabilitiesResult = (
                capabilitiesResult.schemaVersion,
                BridgeCapabilitiesPayload(
                    bridgeVersion: capabilities.bridgeVersion,
                    clientName: capabilities.clientName,
                    defaultHost: capabilities.defaultHost,
                    defaultPort: capabilities.defaultPort,
                    ops: newValue.sorted()
                ),
                capabilitiesResult.raw
            )
        }
    }

    init(
        capabilitiesResult: (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String)? = nil,
        statusResult: (BridgeStatusPayload, String)? = nil
    ) {
        self.capabilitiesResult = capabilitiesResult ?? (
            1,
            BridgeCapabilitiesPayload(
                bridgeVersion: "fake",
                clientName: "fake",
                defaultHost: "127.0.0.1",
                defaultPort: 4712,
                ops: ["capabilities", "status", "downloads", "search", "add-link", "rename", "pause", "resume", "cancel", "servers", "server-connect", "server-disconnect", "server-add", "server-remove", "server-update-from-url", "sources", "prefs-connection-get", "prefs-connection-set"]
            ),
            #"{"ok":true,"schema_version":1,"capabilities":{"bridge_version":"fake","client_name":"fake","default_host":"127.0.0.1","default_port":4712,"ops":[]}}"#
        )
        self.statusResult = statusResult ?? (
            BridgeStatusPayload(
                connected: false,
                ed2k: "Disconnected",
                kad: "Disconnected",
                downloadSpeed: 0,
                uploadSpeed: 0,
                queue: 0,
                sources: 0
            ),
            #"{"ok":true,"status":{}}"#
        )
    }

    func connect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func disconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func capabilities(config: AMuleConnectionConfig) async throws -> (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String) {
        invokedOperations.append("capabilities")
        return capabilitiesResult
    }
    func status(config: AMuleConnectionConfig) async throws -> (BridgeStatusPayload, String) {
        invokedOperations.append("status")
        return statusResult
    }
    func downloads(config: AMuleConnectionConfig) async throws -> ([BridgeDownloadPayload], String) {
        invokedOperations.append("downloads")
        return downloadsResult
    }
    func search(request: ECSearchRequest, polls: Int, pollIntervalMs: Int, config: AMuleConnectionConfig) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String) {
        lastSearchRequest = request
        return searchResult
    }
    func search(scope: String, query: String, polls: Int, pollIntervalMs: Int, config: AMuleConnectionConfig) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String) {
        try await search(request: ECSearchRequest(scope: scope, query: query), polls: polls, pollIntervalMs: pollIntervalMs, config: config)
    }
    func searchStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func download(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func addLink(link: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func rename(hash: String, name: String, config: AMuleConnectionConfig) async throws -> RenameAcknowledgement { renameResult }
    func pause(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func resume(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func stop(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        invokedOperations.append("download-stop")
        return ("ok", messageRaw)
    }
    func swapA4AF(hash: String, mode: ECOperations.A4AFSwapMode, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        invokedOperations.append("download-a4af")
        lastA4AFMode = mode
        return ("ok", messageRaw)
    }
    func downloadSetCategory(hash: String, categoryID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        invokedOperations.append("download-set-category")
        lastDownloadCategoryID = categoryID
        return ("ok", messageRaw)
    }
    func cancel(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func servers(config: AMuleConnectionConfig) async throws -> ([BridgeServerPayload], String) {
        invokedOperations.append("servers")
        return ([], #"{"ok":true,"servers":[]}"#)
    }
    func serverConnect(ip: String?, port: Int?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func serverDisconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func serverAdd(address: String, name: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func serverRemove(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func serverSetStatic(ecid: Int, isStatic: Bool, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        invokedOperations.append("server-set-static")
        lastServerStaticECID = ecid
        lastServerStatic = isStatic
        return ("ok", messageRaw)
    }
    func serverSetPriority(ecid: Int, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        invokedOperations.append("server-set-priority")
        lastServerPriorityECID = ecid
        lastServerPriority = priority
        return ("ok", messageRaw)
    }
    func serverUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func sources(hash: String, config: AMuleConnectionConfig) async throws -> ([BridgeDownloadSourcePayload], String) { ([], #"{"ok":true,"sources":[]}"#) }
    func prefsConnectionGet(config: AMuleConnectionConfig) async throws -> (BridgeConnectionPrefsPayload, String) {
        (BridgeConnectionPrefsPayload(maxDownload: 0, maxUpload: 0), #"{"ok":true,"prefs_connection":{"max_dl":0,"max_ul":0}}"#)
    }
    func prefsConnectionSet(maxDownload: Int, maxUpload: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func kadStart(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func kadStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func kadBootstrap(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func kadUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func uploads(config: AMuleConnectionConfig) async throws -> ([BridgeUploadPayload], String) { ([], #"{"ok":true,"uploads":[]}"#) }
    func sharedFiles(config: AMuleConnectionConfig) async throws -> ([BridgeSharedFilePayload], String) {
        invokedOperations.append("shared-files")
        return ([], #"{"ok":true,"shared_files":[]}"#)
    }
    func sharedFilesReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func coreLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) { (BridgeCoreLogPayload(kind: "log", lines: []), #"{"ok":true,"log":{"kind":"log","lines":[]}}"#) }
    func debugLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) { (BridgeCoreLogPayload(kind: "debug", lines: []), #"{"ok":true,"log":{"kind":"debug","lines":[]}}"#) }
    func serverInfo(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) {
        invokedOperations.append("server-info")
        return serverInfoResult
    }
    func clearServerInfo(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        invokedOperations.append("clear-server-info")
        return ("ok", messageRaw)
    }
    func resetLog(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func categories(config: AMuleConnectionConfig) async throws -> ([BridgeCategoryPayload], String) {
        invokedOperations.append("categories")
        return categoriesResult
    }
    func categoryCreate(name: String, path: String, comment: String, color: Int, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func categoryUpdate(id: Int, name: String, path: String, comment: String, color: Int, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func categoryDelete(categoryID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func ipfilterReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func ipfilterUpdate(url: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func friends(config: AMuleConnectionConfig) async throws -> ([BridgeFriendPayload], String) {
        invokedOperations.append("friends")
        return ([], #"{"ok":true,"friends":[]}"#)
    }
    func friendAdd(hash: String, ip: String, port: Int, name: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        invokedOperations.append("friend-add")
        lastFriendAdd = (hash, ip, port, name)
        return ("ok", messageRaw)
    }
    func friendRemove(friendID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func friendRequestSharedList(friendID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        invokedOperations.append("friend-shared")
        lastFriendSharedListID = friendID
        return ("ok", messageRaw)
    }
    func friendSlot(friendID: Int, enabled: Bool, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func clearCompleted(ecids: [Int], config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func priority(hash: String, value: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func sharedFilePriority(hash: String, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        invokedOperations.append("shared-file-priority")
        lastSharedFilePriorityHash = hash
        lastSharedFilePriority = priority
        return ("ok", messageRaw)
    }
    func sharedFileCommentRating(hash: String, comment: String, rating: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        invokedOperations.append("shared-file-comment-rating")
        lastSharedFileCommentHash = hash
        lastSharedFileComment = comment
        lastSharedFileRating = rating
        return ("ok", messageRaw)
    }
    func statsTree(capping: Int?, config: AMuleConnectionConfig) async throws -> (BridgeStatsTreeNodePayload, String) {
        (BridgeStatsTreeNodePayload(id: 0, label: "", value: 0, children: []), #"{"ok":true,"stats":{"tree":{"id":0,"label":"","value":0,"children":[]}}}"#)
    }
    func statsGraphs(width: Int, scale: Int, last: Double?, config: AMuleConnectionConfig) async throws -> (BridgeStatsGraphsPayload, String) {
        (BridgeStatsGraphsPayload(last: 0, samples: []), #"{"ok":true,"stats":{"graphs":{"last":0,"samples":[]}}}"#)
    }
}
