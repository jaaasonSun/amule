import XCTest
import AMuleECBridgeAdapter
import AMuleECClient
import SharedServices
@testable import AMuleRemoteiOS

final class RenameVerificationTests: XCTestCase {
    func testRenameIsVerifiedByMatchingHashAndNewName() {
        let downloads = [
            DownloadItemFixtures.download(id: "other", name: "Corrected.mkv"),
            DownloadItemFixtures.download(id: "hash", name: "Corrected.mkv"),
        ]

        XCTAssertTrue(RenameVerification.wasApplied(downloadID: "hash", newName: "Corrected.mkv", downloads: downloads))
    }

    func testRenameIsNotVerifiedWhenNameRemainsUnchanged() {
        let downloads = [
            DownloadItemFixtures.download(id: "hash", name: "Original.mkv"),
        ]

        XCTAssertFalse(RenameVerification.wasApplied(downloadID: "hash", newName: "Corrected.mkv", downloads: downloads))
    }

    @MainActor
    func testRenameDownloadWaitsForDelayedServerUpdateAfterSuccessAcknowledgement() async throws {
        let bridge = IOSRecordingRenameBridge(downloadsResults: [
            [.download(name: "Original.mkv")],
            [.download(name: "Corrected.mkv")],
        ])
        let model = IOSAppModel(bridge: bridge, credentialStorage: InMemoryCredentialStorage())
        model.renameVerificationRetryDelayNanoseconds = 0
        model.downloads = [DownloadItemFixtures.download(id: IOSRecordingRenameBridge.hash, name: "Original.mkv")]

        let item = try XCTUnwrap(model.downloads.first)
        model.renameDownload(item, to: "Corrected.mkv")
        await waitForDownloads(in: model, expectedNames: ["Corrected.mkv"])

        XCTAssertEqual(bridge.renameCalls.map(\.hash), [IOSRecordingRenameBridge.hash])
        XCTAssertEqual(bridge.renameCalls.map(\.name), ["Corrected.mkv"])
        XCTAssertEqual(model.lastError, "")
    }

    @MainActor
    private func waitForDownloads(in model: IOSAppModel, expectedNames: [String]) async {
        for _ in 0..<200 {
            if !model.isBusy, model.downloads.map(\.name) == expectedNames {
                return
            }
            await Task.yield()
        }

        XCTFail("Timed out waiting for downloads: \(model.downloads.map(\.name))")
    }
}

private final class IOSRecordingRenameBridge: BridgeProtocol, @unchecked Sendable {
    static let hash = "00112233445566778899aabbccddeeff"

    var renameCalls: [(hash: String, name: String)] = []
    private let messageRaw = #"{"ok":true}"#
    private var queuedDownloadsResults: [[BridgeDownloadPayload]]

    init(downloadsResults: [[BridgeDownloadPayload]]) {
        self.queuedDownloadsResults = downloadsResults
    }

    func connect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func disconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func capabilities(config: AMuleConnectionConfig) async throws -> (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String) { (1, ECCapabilities(), "{}") }
    func status(config: AMuleConnectionConfig) async throws -> (BridgeStatusPayload, String) {
        (ECStatus(connected: true, ed2k: "Connected", kad: "Connected", downloadSpeed: 0, uploadSpeed: 0, queue: 0, sources: 0), "{}")
    }
    func downloads(config: AMuleConnectionConfig) async throws -> ([BridgeDownloadPayload], String) {
        guard !queuedDownloadsResults.isEmpty else { return ([], "{}") }
        return (queuedDownloadsResults.removeFirst(), "{}")
    }
    func search(request: ECSearchRequest, polls: Int, pollIntervalMs: Int, config: AMuleConnectionConfig) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String) { (0, [], "{}") }
    func search(scope: String, query: String, polls: Int, pollIntervalMs: Int, config: AMuleConnectionConfig) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String) {
        try await search(request: ECSearchRequest(scope: scope, query: query), polls: polls, pollIntervalMs: pollIntervalMs, config: config)
    }
    func searchStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func download(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func addLink(link: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func rename(hash: String, name: String, config: AMuleConnectionConfig) async throws -> RenameAcknowledgement {
        renameCalls.append((hash, name))
        return .success(message: "Rename requested", raw: "{}")
    }
    func pause(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func resume(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func stop(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func swapA4AF(hash: String, mode: ECOperations.A4AFSwapMode, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func downloadSetCategory(hash: String, categoryID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func serverConnect(ip: String?, port: Int?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func serverDisconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func serverAdd(address: String, name: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func serverRemove(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func serverSetStatic(ecid: Int, isStatic: Bool, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func serverSetPriority(ecid: Int, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func prefsConnectionGet(config: AMuleConnectionConfig) async throws -> (BridgeConnectionPrefsPayload, String) { (ECConnectionPrefs(maxDownload: 0, maxUpload: 0), "{}") }
    func prefsConnectionSet(maxDownload: Int, maxUpload: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func cancel(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func servers(config: AMuleConnectionConfig) async throws -> ([BridgeServerPayload], String) { ([], "{}") }
    func sources(hash: String, config: AMuleConnectionConfig) async throws -> ([BridgeDownloadSourcePayload], String) { ([], "{}") }
    func serverUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func kadStart(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func kadStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func kadBootstrap(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func kadUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func uploads(config: AMuleConnectionConfig) async throws -> ([BridgeUploadPayload], String) { ([], "{}") }
    func sharedFiles(config: AMuleConnectionConfig) async throws -> ([BridgeSharedFilePayload], String) { ([], "{}") }
    func sharedFilesReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func coreLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) { (ECCoreLog(kind: "log", lines: []), "{}") }
    func debugLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) { (ECCoreLog(kind: "debug", lines: []), "{}") }
    func serverInfo(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) { (BridgeCoreLogPayload(kind: "server-info", lines: ["server log"]), messageRaw) }
    func clearServerInfo(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func resetLog(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func categories(config: AMuleConnectionConfig) async throws -> ([BridgeCategoryPayload], String) { ([], "{}") }
    func categoryCreate(name: String, path: String, comment: String, color: Int, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func categoryUpdate(id: Int, name: String, path: String, comment: String, color: Int, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func categoryDelete(categoryID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func ipfilterReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func ipfilterUpdate(url: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func friends(config: AMuleConnectionConfig) async throws -> ([BridgeFriendPayload], String) { ([], "{}") }
    func friendAdd(hash: String, ip: String, port: Int, name: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func friendRemove(friendID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func friendRequestSharedList(friendID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func friendSlot(friendID: Int, enabled: Bool, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func clearCompleted(ecids: [Int], config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func priority(hash: String, value: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func sharedFilePriority(hash: String, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func sharedFileCommentRating(hash: String, comment: String, rating: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func statsTree(capping: Int?, config: AMuleConnectionConfig) async throws -> (BridgeStatsTreeNodePayload, String) { (ECStatsTreeNode(id: 0, label: "", value: 0, children: []), "{}") }
    func statsGraphs(width: Int, scale: Int, last: Double?, config: AMuleConnectionConfig) async throws -> (BridgeStatsGraphsPayload, String) { (ECStatsGraphs(last: 0, samples: []), "{}") }
}

private extension BridgeDownloadPayload {
    static func download(name: String) -> BridgeDownloadPayload {
        BridgeDownloadPayload(
            ecid: 1,
            hash: IOSRecordingRenameBridge.hash,
            name: name,
            size: 100,
            done: 10,
            transferred: 10,
            progress: 10,
            sourcesCurrent: 0,
            sourcesTotal: 0,
            sourcesTransferring: 0,
            sourcesA4AF: 0,
            statusCode: 0,
            isCompleted: false,
            status: "Downloading",
            speed: 0,
            priority: 0,
            category: 0,
            partMet: "",
            lastSeenComplete: 0,
            lastReceived: 0,
            activeSeconds: 0,
            availableParts: 0,
            shared: false
        )
    }
}

private final class InMemoryCredentialStorage: CredentialStorage, @unchecked Sendable {
    private var values: [String: String] = [:]

    func readCredential(forKey key: String) -> String? {
        values[key]
    }

    func writeCredential(_ value: String, forKey key: String) {
        values[key] = value
    }

    func deleteCredential(forKey key: String) {
        values.removeValue(forKey: key)
    }
}
