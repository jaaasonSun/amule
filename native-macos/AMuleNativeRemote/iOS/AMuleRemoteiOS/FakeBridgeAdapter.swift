#if canImport(UIKit)
import Foundation
import AMuleRemoteIOSShared

/// Deterministic fake bridge for iOS UI development.
/// Returns mock data that exercises all UI paths without requiring a real aMule server.
final class FakeBridgeAdapter: BridgeProtocol, @unchecked Sendable {
    var capabilitiesResult: (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String)
    var statusResult: (BridgeStatusPayload, String)
    var downloadsResult: ([BridgeDownloadPayload], String)
    var searchResult: (progress: Int, results: [BridgeSearchPayload], raw: String)
    var prefsConnectionResult: BridgeConnectionPrefsPayload
    var messageRaw: String
    var cancelError: Error?
    private(set) var cancelledHashes: [String]

    init(
        capabilitiesResult: (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String)? = nil,
        statusResult: (BridgeStatusPayload, String)? = nil,
        downloadsResult: ([BridgeDownloadPayload], String)? = nil,
        searchResult: (progress: Int, results: [BridgeSearchPayload], raw: String)? = nil
    ) {
        self.capabilitiesResult = capabilitiesResult ?? (
            1,
            BridgeCapabilitiesPayload(
                bridgeVersion: "fake-1.0",
                clientName: "aMule Fake",
                defaultHost: "127.0.0.1",
                defaultPort: 4712,
                ops: ["capabilities", "status", "downloads", "search", "add-link", "pause", "resume", "server-connect"]
            ),
            #"{"ok":true,"schema_version":1,"capabilities":{"bridge_version":"fake-1.0","client_name":"aMule Fake","default_host":"127.0.0.1","default_port":4712,"ops":["capabilities","status","downloads","search","add-link","pause","resume","server-connect"]}}"#
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
        self.downloadsResult = downloadsResult ?? (
            Self.sampleDownloads,
            #"{"ok":true,"downloads":[]}"#
        )
        self.searchResult = searchResult ?? (
            100,
            Self.sampleSearchResults,
            #"{"ok":true,"progress":100,"results":[]}"#
        )
        self.prefsConnectionResult = BridgeConnectionPrefsPayload(maxDownload: 0, maxUpload: 0)
        self.messageRaw = #"{"ok":true,"message":"ok"}"#
        self.cancelError = nil
        self.cancelledHashes = []
    }

    func connect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        ("ok", messageRaw)
    }

    func disconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        ("ok", messageRaw)
    }

    func capabilities(config: AMuleConnectionConfig) async throws -> (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String) {
        capabilitiesResult
    }

    func status(config: AMuleConnectionConfig) async throws -> (BridgeStatusPayload, String) {
        statusResult
    }

    func downloads(config: AMuleConnectionConfig) async throws -> ([BridgeDownloadPayload], String) {
        downloadsResult
    }

    func search(scope: String, query: String, polls: Int, pollIntervalMs: Int, config: AMuleConnectionConfig) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String) {
        searchResult
    }

    func searchStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        ("ok", messageRaw)
    }

    func download(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        ("ok", messageRaw)
    }

    func addLink(link: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        ("ok", messageRaw)
    }

    func pause(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        ("ok", messageRaw)
    }

    func resume(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        ("ok", messageRaw)
    }

    func cancel(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        if let cancelError { throw cancelError }
        cancelledHashes.append(hash)
        downloadsResult.0.removeAll { $0.hash == hash }
        return ("Cancel requested", messageRaw)
    }

    func serverConnect(ip: String?, port: Int?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        ("ok", messageRaw)
    }

    func sources(hash: String, config: AMuleConnectionConfig) async throws -> ([DownloadSourceItem], String) {
        (Self.sampleSources, #"{"ok":true,"sources":[]}"#)
    }

    func prefsConnectionGet(config: AMuleConnectionConfig) async throws -> (BridgeConnectionPrefsPayload, String) {
        (prefsConnectionResult, #"{"ok":true,"prefs_connection":{"max_dl":0,"max_ul":0}}"#)
    }

    func prefsConnectionSet(maxDownload: Int, maxUpload: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        prefsConnectionResult = BridgeConnectionPrefsPayload(maxDownload: maxDownload, maxUpload: maxUpload)
        return ("Connection speed limits updated", #"{"ok":true,"message":"Connection speed limits updated"}"#)
    }

    // MARK: - Sample Data

    private static let sampleDownloads: [BridgeDownloadPayload] = [
        BridgeDownloadPayload(
            ecid: 1, hash: "ABCDEF0123456789ABCDEF0123456789",
            name: "Ubuntu 24.04 Desktop amd64.iso",
            nameEncodingSuspect: false, nameEncodingSuggestion: nil,
            size: 5_100_000_000, done: 3_060_000_000, transferred: 3_200_000_000,
            progress: 60.0, sourcesCurrent: 5, sourcesTotal: 42, sourcesTransferring: 3,
            sourcesA4AF: 0, statusCode: 4, isCompleted: false, status: "Downloading",
            speed: 512_000, priority: 1, category: 0, partMet: "001.part.met",
            lastSeenComplete: 0, lastReceived: 0, activeSeconds: 3600,
            availableParts: 200, shared: false, alternativeNames: [],
            progressColors: nil
        ),
        BridgeDownloadPayload(
            ecid: 2, hash: "FEDCBA9876543210FEDCBA9876543210",
            name: "Large Archive file.rar",
            nameEncodingSuspect: false, nameEncodingSuggestion: nil,
            size: 2_000_000_000, done: 2_000_000_000, transferred: 2_100_000_000,
            progress: 100.0, sourcesCurrent: 0, sourcesTotal: 15, sourcesTransferring: 0,
            sourcesA4AF: 0, statusCode: 9, isCompleted: true, status: "Completed",
            speed: 0, priority: 1, category: 0, partMet: "002.part.met",
            lastSeenComplete: 1_700_000_000, lastReceived: 1_700_000_000, activeSeconds: 7200,
            availableParts: 100, shared: true, alternativeNames: [],
            progressColors: nil
        ),
        BridgeDownloadPayload(
            ecid: 3, hash: "11111111111111111111111111111111",
            name: "Document Collection.pdf",
            nameEncodingSuspect: false, nameEncodingSuggestion: nil,
            size: 50_000_000, done: 0, transferred: 0,
            progress: 0.0, sourcesCurrent: 0, sourcesTotal: 8, sourcesTransferring: 0,
            sourcesA4AF: 0, statusCode: 7, isCompleted: false, status: "Paused",
            speed: 0, priority: 0, category: 0, partMet: "003.part.met",
            lastSeenComplete: 0, lastReceived: 0, activeSeconds: 0,
            availableParts: 0, shared: false, alternativeNames: [],
            progressColors: nil
        ),
        BridgeDownloadPayload(
            ecid: 4, hash: "22222222222222222222222222222222",
            name: "Music Album Collection.zip",
            nameEncodingSuspect: false, nameEncodingSuggestion: nil,
            size: 800_000_000, done: 200_000_000, transferred: 210_000_000,
            progress: 25.0, sourcesCurrent: 2, sourcesTotal: 20, sourcesTransferring: 1,
            sourcesA4AF: 3, statusCode: 4, isCompleted: false, status: "Downloading",
            speed: 128_000, priority: 1, category: 0, partMet: "004.part.met",
            lastSeenComplete: 0, lastReceived: 0, activeSeconds: 1800,
            availableParts: 50, shared: false, alternativeNames: [],
            progressColors: nil
        )
    ]

    private static let sampleSearchResults: [BridgeSearchPayload] = [
        BridgeSearchPayload(
            id: 1, hash: "AAAA000011112222AAAA000011112222",
            name: "Ubuntu 24.04 Desktop amd64.iso",
            size: 5_100_000_000, sources: 42, completeSources: 15,
            statusCode: 1, status: "Available", parentID: 0, alreadyHave: false
        ),
        BridgeSearchPayload(
            id: 2, hash: "BBBB000011112222BBBB000011112222",
            name: "Ubuntu 22.04 LTS Desktop.iso",
            size: 4_700_000_000, sources: 120, completeSources: 80,
            statusCode: 1, status: "Available", parentID: 0, alreadyHave: true
        ),
        BridgeSearchPayload(
            id: 3, hash: "CCCC000011112222CCCC000011112222",
            name: "Linux Mint 21.3 Cinnamon.iso",
            size: 2_800_000_000, sources: 35, completeSources: 10,
            statusCode: 1, status: "Available", parentID: 0, alreadyHave: false
        )
    ]

    private static let sampleSources: [DownloadSourceItem] = [
        DownloadSourceItem(
            id: 1, requestFileID: 1,
            clientName: "eMule v0.60a", userIP: "192.168.1.42", userPort: 4662,
            serverName: "eDonkey Server", serverIP: "195.245.244.1", serverPort: 4661,
            software: "eMule", softwareVersion: "0.60a",
            downloadState: 4, downloadStateText: "Downloading",
            sourceFrom: 1, sourceFromText: "Server",
            downSpeedKBps: 128.5, availableParts: 45,
            remoteQueueRank: 0, obfuscationStatus: 0,
            extendedProtocol: true, remoteFilename: "Ubuntu 24.04 Desktop amd64.iso"
        ),
        DownloadSourceItem(
            id: 2, requestFileID: 1,
            clientName: "aMule v2.3.2", userIP: "10.0.0.15", userPort: 4662,
            serverName: "TVU Donkey", serverIP: "91.200.42.2", serverPort: 4661,
            software: "aMule", softwareVersion: "2.3.2",
            downloadState: 2, downloadStateText: "On Queue",
            sourceFrom: 2, sourceFromText: "Kad",
            downSpeedKBps: 0, availableParts: 30,
            remoteQueueRank: 156, obfuscationStatus: 1,
            extendedProtocol: false, remoteFilename: "Ubuntu 24.04 Desktop amd64.iso"
        ),
        DownloadSourceItem(
            id: 3, requestFileID: 1,
            clientName: "(unknown)", userIP: "172.16.0.99", userPort: 0,
            serverName: "", serverIP: "", serverPort: 0,
            software: "eMule", softwareVersion: "0.50a",
            downloadState: 1, downloadStateText: "Connecting",
            sourceFrom: 3, sourceFromText: "Source Exchange",
            downSpeedKBps: 0, availableParts: 0,
            remoteQueueRank: 0xffff, obfuscationStatus: 0,
            extendedProtocol: false, remoteFilename: ""
        )
    ]
}

func platformDefaultBridgeAdapter() -> BridgeProtocol {
    IOSInProcessBridgeAdapter()
}
#endif
