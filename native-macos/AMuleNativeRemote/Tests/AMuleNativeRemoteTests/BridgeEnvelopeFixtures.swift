import Foundation
import AMuleECBridgeAdapter
import AMuleECClient
import enum AMuleECBridgeAdapter.RenameAcknowledgement
import SharedModels
import SharedServices

@testable import AMuleNativeRemote

enum BridgeEnvelopeFixtures {
    static let activePartHash = "ACTIVEPART000000000000000000000001"
    static let linuxISOHash = "LINUXISOZIP0000000000000000000002"
    static let completedMovieHash = "FINISHEDMOVIE000000000000000000001"

    static func download(
        ecid: Int,
        hash: String,
        name: String,
        size: UInt64,
        done: UInt64,
        transferred: UInt64,
        progress: Double,
        sourcesCurrent: Int,
        sourcesTotal: Int,
        sourcesTransferring: Int,
        sourcesA4AF: Int = 0,
        statusCode: Int,
        isCompleted: Bool,
        status: String,
        speed: Int,
        priority: Int = 0,
        category: Int = 0,
        partMet: String,
        lastSeenComplete: UInt64 = 0,
        lastReceived: UInt64 = 0,
        activeSeconds: Int = 0,
        availableParts: Int = 0,
        shared: Bool,
        nameEncodingSuspect: Bool? = nil,
        nameEncodingSuggestion: String? = nil,
        alternativeNames: [[String: Any]] = [],
        progressColors: [UInt32] = []
    ) -> [String: Any] {
        var result: [String: Any] = [
            "ecid": ecid,
            "hash": hash,
            "name": name,
            "size": size,
            "done": done,
            "transferred": transferred,
            "progress": progress,
            "sources_current": sourcesCurrent,
            "sources_total": sourcesTotal,
            "sources_transferring": sourcesTransferring,
            "sources_a4af": sourcesA4AF,
            "status_code": statusCode,
            "is_completed": isCompleted,
            "status": status,
            "speed": speed,
            "priority": priority,
            "category": category,
            "part_met": partMet,
            "last_seen_complete": lastSeenComplete,
            "last_received": lastReceived,
            "active_seconds": activeSeconds,
            "available_parts": availableParts,
            "shared": shared,
            "alternative_names": alternativeNames,
            "progress_colors": progressColors,
        ]
        if let nameEncodingSuspect {
            result["name_encoding_suspect"] = nameEncodingSuspect
        }
        if let nameEncodingSuggestion {
            result["name_encoding_suggestion"] = nameEncodingSuggestion
        }
        return result
    }

    static func activePart() -> [String: Any] {
        download(
            ecid: 101,
            hash: activePartHash,
            name: "Active Part.iso",
            size: 2_097_152,
            done: 524_288,
            transferred: 262_144,
            progress: 25,
            sourcesCurrent: 12,
            sourcesTotal: 18,
            sourcesTransferring: 3,
            statusCode: 3,
            isCompleted: false,
            status: "Downloading",
            speed: 4_096,
            partMet: "101.part.met",
            lastSeenComplete: 0,
            lastReceived: 0,
            activeSeconds: 60,
            availableParts: 8,
            shared: false,
            progressColors: [65_280]
        )
    }

    static func linuxISO() -> [String: Any] {
        download(
            ecid: 102,
            hash: linuxISOHash,
            name: "Linux ISO.zip",
            size: 4_194_304,
            done: 1_048_576,
            transferred: 786_432,
            progress: 25,
            sourcesCurrent: 8,
            sourcesTotal: 11,
            sourcesTransferring: 2,
            statusCode: 3,
            isCompleted: false,
            status: "Downloading",
            speed: 2_048,
            partMet: "102.part.met",
            lastSeenComplete: 0,
            lastReceived: 0,
            activeSeconds: 120,
            availableParts: 6,
            shared: false,
            progressColors: [32_768]
        )
    }

    static func completedMovie(name: String = "Finished Movie.mkv", ecid: Int = 202) -> [String: Any] {
        download(
            ecid: ecid,
            hash: completedMovieHash,
            name: name,
            size: 1_048_576,
            done: 1_048_576,
            transferred: 1_048_576,
            progress: 100,
            sourcesCurrent: 0,
            sourcesTotal: 0,
            sourcesTransferring: 0,
            statusCode: 9,
            isCompleted: true,
            status: "Completed",
            speed: 0,
            partMet: "202.part.met",
            lastSeenComplete: 1_716_681_600,
            lastReceived: 1_716_681_600,
            activeSeconds: 3_600,
            availableParts: 0,
            shared: true,
            progressColors: [255]
        )
    }

    static func malformedSparseRows() -> [[String: Any]] {
        [
            download(ecid: 303, hash: "SPARSEROW000000000000000000000003", name: "", size: 0, done: 0, transferred: 0, progress: 0, sourcesCurrent: 0, sourcesTotal: 0, sourcesTransferring: 0, statusCode: 0, isCompleted: false, status: "", speed: 0, partMet: "", shared: false),
            download(ecid: 404, hash: "WHITESPACEROW00000000000000000004", name: "   ", size: 123, done: 0, transferred: 0, progress: 0, sourcesCurrent: 0, sourcesTotal: 0, sourcesTransferring: 0, statusCode: 0, isCompleted: false, status: "Waiting", speed: 0, partMet: "404.part.met", shared: false),
            download(ecid: 505, hash: "SHAREDWITHOUTPARTMET000000000005", name: "Shared Row.bin", size: 123, done: 123, transferred: 123, progress: 100, sourcesCurrent: 0, sourcesTotal: 0, sourcesTransferring: 0, statusCode: 9, isCompleted: true, status: "Completed", speed: 0, partMet: "", shared: true),
        ]
    }

    static func downloadEnvelope(downloads: [[String: Any]]) throws -> String {
        try jsonString(["ok": true, "downloads": downloads])
    }

    private static func jsonString(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        guard let string = String(data: data, encoding: .utf8) else {
            throw FixtureError.invalidUTF8
        }
        return string
    }

    private enum FixtureError: Error {
        case invalidUTF8
    }
}

final class RecordingFakeBridgeAdapter: BridgeProtocol, @unchecked Sendable {
    var capabilitiesResult: (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String)
    var statusResult: (BridgeStatusPayload, String)
    var searchResult: (progress: Int, results: [BridgeSearchPayload], raw: String)
    var messageRaw: String
    var renameResult: RenameAcknowledgement
    var renameCalls: [(hash: String, name: String)] = []
    var clearCompletedCalls: [[Int]] = []
    var sourceCalls: [String] = []
    var lastSearchRequest: ECSearchRequest?
    var sourcesResult: Result<([BridgeDownloadSourcePayload], String), Error> = .success(([], #"{"ok":true,"sources":[]}"#))
    private var queuedDownloadsResults: [([BridgeDownloadPayload], String)]

    init(
        downloadsResults: [([BridgeDownloadPayload], String)] = [],
        messageRaw: String = #"{"ok":true,"message":"ok"}"#,
        capabilitiesResult: (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String)? = nil,
        statusResult: (BridgeStatusPayload, String)? = nil,
        searchResult: (progress: Int, results: [BridgeSearchPayload], raw: String)? = nil
    ) {
        let base = FakeBridgeAdapter(capabilitiesResult: capabilitiesResult, statusResult: statusResult)
        self.capabilitiesResult = base.capabilitiesResult
        self.statusResult = base.statusResult
        self.searchResult = searchResult ?? base.searchResult
        self.messageRaw = messageRaw
        self.renameResult = .success(message: "ok", raw: messageRaw)
        self.queuedDownloadsResults = downloadsResults
    }

    func connect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func disconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func capabilities(config: AMuleConnectionConfig) async throws -> (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String) { capabilitiesResult }
    func status(config: AMuleConnectionConfig) async throws -> (BridgeStatusPayload, String) { statusResult }
    func downloads(config: AMuleConnectionConfig) async throws -> ([BridgeDownloadPayload], String) {
        guard !queuedDownloadsResults.isEmpty else { return ([], try BridgeEnvelopeFixtures.downloadEnvelope(downloads: [])) }
        return queuedDownloadsResults.removeFirst()
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
    func rename(hash: String, name: String, config: AMuleConnectionConfig) async throws -> RenameAcknowledgement {
        renameCalls.append((hash, name))
        return renameResult
    }
    func pause(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func resume(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func stop(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func swapA4AF(hash: String, mode: ECOperations.A4AFSwapMode, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func downloadSetCategory(hash: String, categoryID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func cancel(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func servers(config: AMuleConnectionConfig) async throws -> ([BridgeServerPayload], String) { ([], #"{"ok":true,"servers":[]}"#) }
    func serverConnect(ip: String?, port: Int?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func serverDisconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func serverAdd(address: String, name: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func serverRemove(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func serverSetStatic(ecid: Int, isStatic: Bool, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func serverSetPriority(ecid: Int, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func serverUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func sources(hash: String, config: AMuleConnectionConfig) async throws -> ([BridgeDownloadSourcePayload], String) {
        sourceCalls.append(hash)
        return try sourcesResult.get()
    }
    func prefsConnectionGet(config: AMuleConnectionConfig) async throws -> (BridgeConnectionPrefsPayload, String) {
        (BridgeConnectionPrefsPayload(maxDownload: 0, maxUpload: 0), #"{"ok":true,"prefs_connection":{"max_dl":0,"max_ul":0}}"#)
    }
    func prefsConnectionSet(maxDownload: Int, maxUpload: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func prefsConnectionSet(prefs: BridgeConnectionPrefsPayload, group: ECOperations.PreferencesGroup, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func kadStart(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func kadStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func kadBootstrap(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func kadUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func uploads(config: AMuleConnectionConfig) async throws -> ([BridgeUploadPayload], String) { ([], #"{"ok":true,"uploads":[]}"#) }
    func sharedFiles(config: AMuleConnectionConfig) async throws -> ([BridgeSharedFilePayload], String) { ([], #"{"ok":true,"shared_files":[]}"#) }
    func sharedFilesReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func coreLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) { (BridgeCoreLogPayload(kind: "log", lines: []), #"{"ok":true,"log":{"kind":"log","lines":[]}}"#) }
    func debugLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) { (BridgeCoreLogPayload(kind: "debug", lines: []), #"{"ok":true,"log":{"kind":"debug","lines":[]}}"#) }
    func serverInfo(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) { (BridgeCoreLogPayload(kind: "server-info", lines: ["server log"]), messageRaw) }
    func clearServerInfo(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func resetLog(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func shutdown(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func connectionState(config: AMuleConnectionConfig) async throws -> (BridgeConnectionStatePayload, String) { (ECConnectionState(ed2kConnected: false, ed2kConnecting: false, kadConnected: false, kadFirewalled: false, kadRunning: false), "{}") }
    func lastLogEntry(config: AMuleConnectionConfig) async throws -> String { "last log entry" }
    func resetDebugLog(config: AMuleConnectionConfig) async throws { }
    func categories(config: AMuleConnectionConfig) async throws -> ([BridgeCategoryPayload], String) { ([], #"{"ok":true,"categories":[]}"#) }
    func categoryCreate(name: String, path: String, comment: String, color: Int, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func categoryUpdate(id: Int, name: String, path: String, comment: String, color: Int, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func categoryDelete(categoryID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func ipfilterReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func ipfilterUpdate(url: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func friends(config: AMuleConnectionConfig) async throws -> ([BridgeFriendPayload], String) { ([], #"{"ok":true,"friends":[]}"#) }
    func friendAdd(hash: String, ip: String, port: Int, name: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func friendRemove(friendID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func friendRequestSharedList(friendID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func friendSlot(friendID: Int, enabled: Bool, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func clearCompleted(ecids: [Int], config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        clearCompletedCalls.append(ecids)
        return ("ok", messageRaw)
    }
    func priority(hash: String, value: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func sharedFilePriority(hash: String, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func sharedFileCommentRating(hash: String, comment: String, rating: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func statsTree(capping: Int?, config: AMuleConnectionConfig) async throws -> (BridgeStatsTreeNodePayload, String) {
        (BridgeStatsTreeNodePayload(id: 0, label: "", value: 0, children: []), #"{"ok":true,"stats":{"tree":{"id":0,"label":"","value":0,"children":[]}}}"#)
    }
    func statsGraphs(width: Int, scale: Int, last: Double?, config: AMuleConnectionConfig) async throws -> (BridgeStatsGraphsPayload, String) {
        (BridgeStatsGraphsPayload(last: 0, samples: []), #"{"ok":true,"stats":{"graphs":{"last":0,"samples":[]}}}"#)
    }
}
