import XCTest
import enum AMuleECBridgeAdapter.RenameAcknowledgement
import AMuleECClient
import SharedCore
@testable import AMuleRemoteIOSShared

final class SerializedBridgeAdapterTests: XCTestCase {
    func testOperationsDoNotOverlap() async throws {
        let probe = BridgeConcurrencyProbe()
        let adapter = SerializedBridgeAdapter(wrapping: DelayedBridge(probe: probe))
        let config = AMuleConnectionConfig(host: "127.0.0.1", port: 4712, password: "secret")

        async let rename: RenameAcknowledgement = adapter.rename(hash: "hash", name: "renamed.iso", config: config)
        async let downloads: ([BridgeDownloadPayload], String) = adapter.downloads(config: config)
        _ = try await (rename, downloads)

        let maximumConcurrentOperations = await probe.maximumConcurrentOperations()
        XCTAssertEqual(maximumConcurrentOperations, 1)
    }
}

private actor BridgeConcurrencyProbe {
    private var activeOperations = 0
    private var maximumConcurrentOperationCount = 0

    func enter() async throws {
        activeOperations += 1
        maximumConcurrentOperationCount = max(maximumConcurrentOperationCount, activeOperations)
        try await Task.sleep(nanoseconds: 20_000_000)
    }

    func leave() {
        activeOperations -= 1
    }

    func maximumConcurrentOperations() -> Int {
        maximumConcurrentOperationCount
    }
}

private struct DelayedBridge: BridgeProtocol {
    let probe: BridgeConcurrencyProbe

    func connect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await run { ("ok", "{}") } }
    func disconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await run { ("ok", "{}") } }
    func capabilities(config: AMuleConnectionConfig) async throws -> (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String) {
        try await run { (1, BridgeCapabilitiesPayload(), "{}") }
    }
    func status(config: AMuleConnectionConfig) async throws -> (BridgeStatusPayload, String) {
        try await run { (BridgeStatusPayload(connected: true, ed2k: "Connected", kad: "Connected", downloadSpeed: 0, uploadSpeed: 0, queue: 0, sources: 0), "{}") }
    }
    func downloads(config: AMuleConnectionConfig) async throws -> ([BridgeDownloadPayload], String) { try await run { ([], "{}") } }
    func search(scope: String, query: String, polls: Int, pollIntervalMs: Int, config: AMuleConnectionConfig) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String) {
        try await run { (0, [], "{}") }
    }
    func searchStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await run { ("ok", "{}") } }
    func download(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await run { ("ok", "{}") } }
    func addLink(link: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await run { ("ok", "{}") } }
    func rename(hash: String, name: String, config: AMuleConnectionConfig) async throws -> RenameAcknowledgement {
        try await run { .success(message: "ok", raw: "{}") }
    }
    func pause(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await run { ("ok", "{}") } }
    func resume(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await run { ("ok", "{}") } }
    func cancel(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await run { ("ok", "{}") } }
    func servers(config: AMuleConnectionConfig) async throws -> ([BridgeServerPayload], String) { try await run { ([], "{}") } }
    func serverConnect(ip: String?, port: Int?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await run { ("ok", "{}") } }
    func serverDisconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await run { ("ok", "{}") } }
    func serverAdd(address: String, name: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await run { ("ok", "{}") } }
    func serverRemove(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await run { ("ok", "{}") } }
    func serverUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await run { ("ok", "{}") } }
    func sources(hash: String, config: AMuleConnectionConfig) async throws -> ([DownloadSourceItem], String) { try await run { ([], "{}") } }
    func prefsConnectionGet(config: AMuleConnectionConfig) async throws -> (BridgeConnectionPrefsPayload, String) {
        try await run { (BridgeConnectionPrefsPayload(maxDownload: 0, maxUpload: 0), "{}") }
    }
    func prefsConnectionSet(maxDownload: Int, maxUpload: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await run { ("ok", "{}") } }
    func kadStart(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await run { ("ok", "{}") } }
    func kadStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await run { ("ok", "{}") } }
    func kadBootstrap(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await run { ("ok", "{}") } }
    func kadUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await run { ("ok", "{}") } }
    func uploads(config: AMuleConnectionConfig) async throws -> ([BridgeUploadPayload], String) { try await run { ([], "{}") } }
    func sharedFiles(config: AMuleConnectionConfig) async throws -> ([BridgeSharedFilePayload], String) { try await run { ([], "{}") } }
    func sharedFilesReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await run { ("ok", "{}") } }
    func coreLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) { try await run { (BridgeCoreLogPayload(kind: "core", lines: []), "{}") } }
    func debugLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) { try await run { (BridgeCoreLogPayload(kind: "debug", lines: []), "{}") } }
    func categories(config: AMuleConnectionConfig) async throws -> ([BridgeCategoryPayload], String) { try await run { ([], "{}") } }
    func categoryCreate(name: String, path: String, comment: String, color: Int, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await run { ("ok", "{}") } }
    func categoryDelete(categoryID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await run { ("ok", "{}") } }
    func ipfilterReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await run { ("ok", "{}") } }
    func ipfilterUpdate(url: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await run { ("ok", "{}") } }
    func friends(config: AMuleConnectionConfig) async throws -> ([BridgeFriendPayload], String) { try await run { ([], "{}") } }
    func friendRemove(friendID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await run { ("ok", "{}") } }
    func friendSlot(friendID: Int, enabled: Bool, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await run { ("ok", "{}") } }
    func clearCompleted(ecids: [Int], config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await run { ("ok", "{}") } }
    func priority(hash: String, value: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await run { ("ok", "{}") } }
    func statsTree(capping: Int?, config: AMuleConnectionConfig) async throws -> (BridgeStatsTreeNodePayload, String) { try await run { (BridgeStatsTreeNodePayload(id: 0, label: "", value: 0, children: []), "{}") } }
    func statsGraphs(width: Int, scale: Int, last: Double?, config: AMuleConnectionConfig) async throws -> (BridgeStatsGraphsPayload, String) { try await run { (BridgeStatsGraphsPayload(last: 0, samples: []), "{}") } }

    private func run<T>(_ operation: () -> T) async throws -> T {
        try await probe.enter()
        let value = operation()
        await probe.leave()
        return value
    }
}
