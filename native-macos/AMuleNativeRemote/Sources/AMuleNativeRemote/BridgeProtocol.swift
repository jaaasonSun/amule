import Foundation

protocol BridgeProtocol: Sendable {
    func connect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func disconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func capabilities(config: AMuleConnectionConfig) async throws -> (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String)
    func status(config: AMuleConnectionConfig) async throws -> (BridgeStatusPayload, String)
    func downloads(config: AMuleConnectionConfig) async throws -> ([BridgeDownloadPayload], String)
    func search(scope: String, query: String, polls: Int, pollIntervalMs: Int, config: AMuleConnectionConfig) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String)
    func searchStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func download(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func addLink(link: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func rename(hash: String, name: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func pause(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func resume(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func cancel(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func servers(config: AMuleConnectionConfig) async throws -> ([BridgeServerPayload], String)
    func serverConnect(ip: String?, port: Int?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func serverDisconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func serverAdd(address: String, name: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func serverRemove(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func serverUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func sources(hash: String, config: AMuleConnectionConfig) async throws -> ([DownloadSourceItem], String)
    func prefsConnectionGet(config: AMuleConnectionConfig) async throws -> (BridgeConnectionPrefsPayload, String)
    func prefsConnectionSet(maxDownload: Int, maxUpload: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func kadStart(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func kadStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func kadBootstrap(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func kadUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func uploads(config: AMuleConnectionConfig) async throws -> ([BridgeUploadPayload], String)
    func sharedFiles(config: AMuleConnectionConfig) async throws -> ([BridgeSharedFilePayload], String)
    func sharedFilesReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func coreLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String)
    func debugLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String)
    func categories(config: AMuleConnectionConfig) async throws -> ([BridgeCategoryPayload], String)
    func categoryCreate(name: String, path: String, comment: String, color: Int, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func categoryDelete(categoryID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func ipfilterReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func ipfilterUpdate(url: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func friends(config: AMuleConnectionConfig) async throws -> ([BridgeFriendPayload], String)
    func friendRemove(friendID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func friendSlot(friendID: Int, enabled: Bool, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func clearCompleted(ecids: [Int], config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func priority(hash: String, value: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    func statsTree(capping: Int?, config: AMuleConnectionConfig) async throws -> (BridgeStatsTreeNodePayload, String)
    func statsGraphs(width: Int, scale: Int, last: Double?, config: AMuleConnectionConfig) async throws -> (BridgeStatsGraphsPayload, String)
}

struct MacOSBridgeAdapter: BridgeProtocol {
    func connect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await AMuleECBridgeClient.connect(config: config)
    }

    func disconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await AMuleECBridgeClient.disconnect(config: config)
    }

    func capabilities(config: AMuleConnectionConfig) async throws -> (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String) {
        try await AMuleECBridgeClient.capabilities(config: config)
    }

    func status(config: AMuleConnectionConfig) async throws -> (BridgeStatusPayload, String) {
        try await AMuleECBridgeClient.status(config: config)
    }

    func downloads(config: AMuleConnectionConfig) async throws -> ([BridgeDownloadPayload], String) {
        try await AMuleECBridgeClient.downloads(config: config)
    }

    func search(scope: String, query: String, polls: Int, pollIntervalMs: Int, config: AMuleConnectionConfig) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String) {
        try await AMuleECBridgeClient.search(scope: scope, query: query, polls: polls, pollIntervalMs: pollIntervalMs, config: config)
    }

    func searchStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await AMuleECBridgeClient.searchStop(config: config)
    }

    func download(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await AMuleECBridgeClient.download(hash: hash, config: config)
    }

    func addLink(link: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await AMuleECBridgeClient.addLink(link: link, config: config)
    }

    func rename(hash: String, name: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await AMuleECBridgeClient.rename(hash: hash, name: name, config: config)
    }

    func pause(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await AMuleECBridgeClient.pause(hash: hash, config: config)
    }

    func resume(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await AMuleECBridgeClient.resume(hash: hash, config: config)
    }

    func cancel(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await AMuleECBridgeClient.cancel(hash: hash, config: config)
    }

    func servers(config: AMuleConnectionConfig) async throws -> ([BridgeServerPayload], String) {
        try await AMuleECBridgeClient.servers(config: config)
    }

    func serverConnect(ip: String?, port: Int?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await AMuleECBridgeClient.serverConnect(ip: ip, port: port, config: config)
    }

    func serverDisconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await AMuleECBridgeClient.serverDisconnect(config: config)
    }

    func serverAdd(address: String, name: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await AMuleECBridgeClient.serverAdd(address: address, name: name, config: config)
    }

    func serverRemove(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await AMuleECBridgeClient.serverRemove(ip: ip, port: port, config: config)
    }

    func serverUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await AMuleECBridgeClient.serverUpdateFromURL(url: url, config: config)
    }

    func sources(hash: String, config: AMuleConnectionConfig) async throws -> ([DownloadSourceItem], String) {
        let (payloads, raw) = try await AMuleECBridgeClient.sources(hash: hash, config: config)
        return (DownloadSourceItem.fromBridge(payloads), raw)
    }

    func prefsConnectionGet(config: AMuleConnectionConfig) async throws -> (BridgeConnectionPrefsPayload, String) {
        try await AMuleECBridgeClient.prefsConnectionGet(config: config)
    }

    func prefsConnectionSet(maxDownload: Int, maxUpload: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await AMuleECBridgeClient.prefsConnectionSet(maxDownload: maxDownload, maxUpload: maxUpload, config: config)
    }

    func kadStart(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await AMuleECBridgeClient.kadStart(config: config) }
    func kadStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await AMuleECBridgeClient.kadStop(config: config) }
    func kadBootstrap(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await AMuleECBridgeClient.kadBootstrap(ip: ip, port: port, config: config) }
    func kadUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await AMuleECBridgeClient.kadUpdateFromURL(url: url, config: config) }
    func uploads(config: AMuleConnectionConfig) async throws -> ([BridgeUploadPayload], String) { try await AMuleECBridgeClient.uploads(config: config) }
    func sharedFiles(config: AMuleConnectionConfig) async throws -> ([BridgeSharedFilePayload], String) { try await AMuleECBridgeClient.sharedFiles(config: config) }
    func sharedFilesReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await AMuleECBridgeClient.sharedFilesReload(config: config) }
    func coreLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) { try await AMuleECBridgeClient.log(config: config) }
    func debugLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) { try await AMuleECBridgeClient.debugLog(config: config) }
    func categories(config: AMuleConnectionConfig) async throws -> ([BridgeCategoryPayload], String) { try await AMuleECBridgeClient.categories(config: config) }
    func categoryCreate(name: String, path: String, comment: String, color: Int, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await AMuleECBridgeClient.categoryCreate(name: name, path: path, comment: comment, color: color, priority: priority, config: config) }
    func categoryDelete(categoryID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await AMuleECBridgeClient.categoryDelete(categoryID: categoryID, config: config) }
    func ipfilterReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await AMuleECBridgeClient.ipfilterReload(config: config) }
    func ipfilterUpdate(url: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await AMuleECBridgeClient.ipfilterUpdate(url: url, config: config) }
    func friends(config: AMuleConnectionConfig) async throws -> ([BridgeFriendPayload], String) { try await AMuleECBridgeClient.friends(config: config) }
    func friendRemove(friendID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await AMuleECBridgeClient.friendRemove(friendID: friendID, config: config) }
    func friendSlot(friendID: Int, enabled: Bool, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await AMuleECBridgeClient.friendSlot(friendID: friendID, enabled: enabled, config: config) }
    func clearCompleted(ecids: [Int], config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await AMuleECBridgeClient.clearCompleted(ecids: ecids, config: config) }
    func priority(hash: String, value: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await AMuleECBridgeClient.priority(hash: hash, value: value, config: config) }
    func statsTree(capping: Int?, config: AMuleConnectionConfig) async throws -> (BridgeStatsTreeNodePayload, String) { try await AMuleECBridgeClient.statsTree(capping: capping, config: config) }
    func statsGraphs(width: Int, scale: Int, last: Double?, config: AMuleConnectionConfig) async throws -> (BridgeStatsGraphsPayload, String) { try await AMuleECBridgeClient.statsGraphs(width: width, scale: scale, last: last, config: config) }
}

final class FakeBridgeAdapter: BridgeProtocol, @unchecked Sendable {
    var capabilitiesResult: (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String)
    var statusResult: (BridgeStatusPayload, String)
    var downloadsResult: ([BridgeDownloadPayload], String) = ([], #"{"ok":true,"downloads":[]}"#)
    var searchResult: (progress: Int, results: [BridgeSearchPayload], raw: String) = (0, [], #"{"ok":true,"progress":0,"results":[]}"#)
    var messageRaw: String = #"{"ok":true,"message":"ok"}"#

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
    func capabilities(config: AMuleConnectionConfig) async throws -> (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String) { capabilitiesResult }
    func status(config: AMuleConnectionConfig) async throws -> (BridgeStatusPayload, String) { statusResult }
    func downloads(config: AMuleConnectionConfig) async throws -> ([BridgeDownloadPayload], String) { downloadsResult }
    func search(scope: String, query: String, polls: Int, pollIntervalMs: Int, config: AMuleConnectionConfig) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String) { searchResult }
    func searchStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func download(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func addLink(link: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func rename(hash: String, name: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func pause(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func resume(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func cancel(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func servers(config: AMuleConnectionConfig) async throws -> ([BridgeServerPayload], String) { ([], #"{"ok":true,"servers":[]}"#) }
    func serverConnect(ip: String?, port: Int?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func serverDisconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func serverAdd(address: String, name: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func serverRemove(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func serverUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func sources(hash: String, config: AMuleConnectionConfig) async throws -> ([DownloadSourceItem], String) { ([], #"{"ok":true,"sources":[]}"#) }
    func prefsConnectionGet(config: AMuleConnectionConfig) async throws -> (BridgeConnectionPrefsPayload, String) {
        (BridgeConnectionPrefsPayload(maxDownload: 0, maxUpload: 0), #"{"ok":true,"prefs_connection":{"max_dl":0,"max_ul":0}}"#)
    }
    func prefsConnectionSet(maxDownload: Int, maxUpload: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func kadStart(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func kadStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func kadBootstrap(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func kadUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func uploads(config: AMuleConnectionConfig) async throws -> ([BridgeUploadPayload], String) { ([], #"{"ok":true,"uploads":[]}"#) }
    func sharedFiles(config: AMuleConnectionConfig) async throws -> ([BridgeSharedFilePayload], String) { ([], #"{"ok":true,"shared_files":[]}"#) }
    func sharedFilesReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func coreLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) { (BridgeCoreLogPayload(kind: "log", lines: []), #"{"ok":true,"log":{"kind":"log","lines":[]}}"#) }
    func debugLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) { (BridgeCoreLogPayload(kind: "debug", lines: []), #"{"ok":true,"log":{"kind":"debug","lines":[]}}"#) }
    func categories(config: AMuleConnectionConfig) async throws -> ([BridgeCategoryPayload], String) { ([], #"{"ok":true,"categories":[]}"#) }
    func categoryCreate(name: String, path: String, comment: String, color: Int, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func categoryDelete(categoryID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func ipfilterReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func ipfilterUpdate(url: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func friends(config: AMuleConnectionConfig) async throws -> ([BridgeFriendPayload], String) { ([], #"{"ok":true,"friends":[]}"#) }
    func friendRemove(friendID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func friendSlot(friendID: Int, enabled: Bool, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func clearCompleted(ecids: [Int], config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func priority(hash: String, value: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func statsTree(capping: Int?, config: AMuleConnectionConfig) async throws -> (BridgeStatsTreeNodePayload, String) {
        (BridgeStatsTreeNodePayload(id: 0, label: "", value: 0, children: []), #"{"ok":true,"stats":{"tree":{"id":0,"label":"","value":0,"children":[]}}}"#)
    }
    func statsGraphs(width: Int, scale: Int, last: Double?, config: AMuleConnectionConfig) async throws -> (BridgeStatsGraphsPayload, String) {
        (BridgeStatsGraphsPayload(last: 0, samples: []), #"{"ok":true,"stats":{"graphs":{"last":0,"samples":[]}}}"#)
    }
}

func platformDefaultBridgeAdapter() -> BridgeProtocol {
    BridgeAdapterFactory.makeBridgeAdapter()
}
