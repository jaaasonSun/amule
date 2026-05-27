import XCTest
import enum AMuleECBridgeAdapter.RenameAcknowledgement

@testable import AMuleNativeRemote

final class SerializedBridgeAdapterTests: XCTestCase {
    func testOverlappingDownloadsRefreshesDoNotOverlap() async throws {
        try await assertSerialized(
            firstLabel: "downloads:first",
            secondLabel: "downloads:second",
            first: { adapter, config in _ = try await adapter.downloads(config: config) },
            second: { adapter, config in _ = try await adapter.downloads(config: config) }
        )
    }

    func testRenameWaitsBehindOverlappingDownloadsRefresh() async throws {
        try await assertSerialized(
            firstLabel: "downloads:first",
            secondLabel: "rename:hash:renamed.iso",
            first: { adapter, config in _ = try await adapter.downloads(config: config) },
            second: { adapter, config in _ = try await adapter.rename(hash: "hash", name: "renamed.iso", config: config) }
        )
    }

    func testPauseResumeCancelMutationsWaitBehindOverlappingDownloadsRefresh() async throws {
        try await assertSerialized(
            firstLabel: "downloads:first",
            secondLabels: ["pause:hash", "resume:hash", "cancel:hash"],
            first: { adapter, config in _ = try await adapter.downloads(config: config) },
            second: { adapter, config in
                _ = try await adapter.pause(hash: "hash", config: config)
                _ = try await adapter.resume(hash: "hash", config: config)
                _ = try await adapter.cancel(hash: "hash", config: config)
            }
        )
    }

    func testSourceRefreshWaitsBehindOverlappingDownloadsRefresh() async throws {
        try await assertSerialized(
            firstLabel: "downloads:first",
            secondLabel: "sources:hash",
            first: { adapter, config in _ = try await adapter.downloads(config: config) },
            second: { adapter, config in _ = try await adapter.sources(hash: "hash", config: config) }
        )
    }

    private func assertSerialized(
        firstLabel: String,
        secondLabel: String,
        first: @escaping @Sendable (SerializedBridgeAdapter, AMuleConnectionConfig) async throws -> Void,
        second: @escaping @Sendable (SerializedBridgeAdapter, AMuleConnectionConfig) async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        try await assertSerialized(
            firstLabel: firstLabel,
            secondLabels: [secondLabel],
            first: first,
            second: second,
            file: file,
            line: line
        )
    }

    private func assertSerialized(
        firstLabel: String,
        secondLabels: [String],
        first: @escaping @Sendable (SerializedBridgeAdapter, AMuleConnectionConfig) async throws -> Void,
        second: @escaping @Sendable (SerializedBridgeAdapter, AMuleConnectionConfig) async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let probe = BridgeOrderingProbe()
        let adapter = SerializedBridgeAdapter(wrapping: BlockingBridgeAdapter(probe: probe))
        let config = AMuleConnectionConfig(bridgePath: "", host: "127.0.0.1", port: 4712, password: "secret")

        let firstTask = Task { try await first(adapter, config) }
        await waitForEvents([firstLabel], in: probe, file: file, line: line)

        let secondTask = Task { try await second(adapter, config) }
        await assertEventsRemain([firstLabel], in: probe, file: file, line: line)

        await probe.releaseNext()
        try await firstTask.value
        await waitForEvents([firstLabel, secondLabels[0]], in: probe, file: file, line: line)

        for index in secondLabels.indices {
            await probe.releaseNext()
            if index + 1 < secondLabels.count {
                await waitForEvents([firstLabel] + Array(secondLabels.prefix(index + 2)), in: probe, file: file, line: line)
            }
        }
        try await secondTask.value

        let expectedEvents = [firstLabel] + secondLabels
        let events = await probe.events()
        let maximumConcurrentOperations = await probe.maximumConcurrentOperations()
        XCTAssertEqual(events, expectedEvents, file: file, line: line)
        XCTAssertEqual(maximumConcurrentOperations, 1, file: file, line: line)
    }

    private func waitForEvents(
        _ expected: [String],
        in probe: BridgeOrderingProbe,
        file: StaticString,
        line: UInt
    ) async {
        for _ in 0..<200 {
            if await probe.events() == expected { return }
            await Task.yield()
            try? await Task.sleep(nanoseconds: 1_000_000)
        }

        let events = await probe.events()
        XCTFail("Timed out waiting for events \(expected); got \(events)", file: file, line: line)
    }

    private func assertEventsRemain(
        _ expected: [String],
        in probe: BridgeOrderingProbe,
        file: StaticString,
        line: UInt
    ) async {
        for _ in 0..<20 { await Task.yield() }
        let events = await probe.events()
        XCTAssertEqual(events, expected, file: file, line: line)
    }
}

private actor BridgeOrderingProbe {
    private var activeOperations = 0
    private var maximumConcurrentOperationCount = 0
    private var recordedEvents: [String] = []
    private var releaseContinuations: [CheckedContinuation<Void, Never>] = []

    func enter(_ event: String) async {
        activeOperations += 1
        maximumConcurrentOperationCount = max(maximumConcurrentOperationCount, activeOperations)
        recordedEvents.append(event)
        await withCheckedContinuation { continuation in
            releaseContinuations.append(continuation)
        }
        activeOperations -= 1
    }

    func releaseNext() {
        guard !releaseContinuations.isEmpty else { return }
        releaseContinuations.removeFirst().resume()
    }

    func events() -> [String] {
        recordedEvents
    }

    func maximumConcurrentOperations() -> Int {
        maximumConcurrentOperationCount
    }
}

private final class BlockingBridgeAdapter: BridgeProtocol, @unchecked Sendable {
    private let probe: BridgeOrderingProbe
    private var downloadCount = 0
    private let base = FakeBridgeAdapter()

    init(probe: BridgeOrderingProbe) {
        self.probe = probe
    }

    func connect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await base.connect(config: config) }
    func disconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await base.disconnect(config: config) }
    func capabilities(config: AMuleConnectionConfig) async throws -> (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String) { try await base.capabilities(config: config) }
    func status(config: AMuleConnectionConfig) async throws -> (BridgeStatusPayload, String) { try await base.status(config: config) }

    func downloads(config: AMuleConnectionConfig) async throws -> ([BridgeDownloadPayload], String) {
        downloadCount += 1
        let suffix = downloadCount == 1 ? "first" : "second"
        await probe.enter("downloads:\(suffix)")
        return ([], #"{"ok":true,"downloads":[]}"#)
    }

    func search(scope: String, query: String, polls: Int, pollIntervalMs: Int, config: AMuleConnectionConfig) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String) {
        try await base.search(scope: scope, query: query, polls: polls, pollIntervalMs: pollIntervalMs, config: config)
    }

    func searchStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await base.searchStop(config: config) }
    func download(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await base.download(hash: hash, config: config) }
    func addLink(link: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await base.addLink(link: link, config: config) }

    func rename(hash: String, name: String, config: AMuleConnectionConfig) async throws -> RenameAcknowledgement {
        await probe.enter("rename:\(hash):\(name)")
        return .success(message: "ok", raw: base.messageRaw)
    }

    func pause(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        await probe.enter("pause:\(hash)")
        return ("ok", base.messageRaw)
    }

    func resume(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        await probe.enter("resume:\(hash)")
        return ("ok", base.messageRaw)
    }

    func cancel(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        await probe.enter("cancel:\(hash)")
        return ("ok", base.messageRaw)
    }

    func servers(config: AMuleConnectionConfig) async throws -> ([BridgeServerPayload], String) { try await base.servers(config: config) }
    func serverConnect(ip: String?, port: Int?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await base.serverConnect(ip: ip, port: port, config: config) }
    func serverDisconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await base.serverDisconnect(config: config) }
    func serverAdd(address: String, name: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await base.serverAdd(address: address, name: name, config: config) }
    func serverRemove(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await base.serverRemove(ip: ip, port: port, config: config) }
    func serverUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await base.serverUpdateFromURL(url: url, config: config) }

    func sources(hash: String, config: AMuleConnectionConfig) async throws -> ([DownloadSourceItem], String) {
        await probe.enter("sources:\(hash)")
        return ([], #"{"ok":true,"sources":[]}"#)
    }

    func prefsConnectionGet(config: AMuleConnectionConfig) async throws -> (BridgeConnectionPrefsPayload, String) { try await base.prefsConnectionGet(config: config) }
    func prefsConnectionSet(maxDownload: Int, maxUpload: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await base.prefsConnectionSet(maxDownload: maxDownload, maxUpload: maxUpload, config: config)
    }

    func kadStart(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await base.kadStart(config: config) }
    func kadStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await base.kadStop(config: config) }
    func kadBootstrap(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await base.kadBootstrap(ip: ip, port: port, config: config) }
    func kadUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await base.kadUpdateFromURL(url: url, config: config) }
    func uploads(config: AMuleConnectionConfig) async throws -> ([BridgeUploadPayload], String) { try await base.uploads(config: config) }
    func sharedFiles(config: AMuleConnectionConfig) async throws -> ([BridgeSharedFilePayload], String) { try await base.sharedFiles(config: config) }
    func sharedFilesReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await base.sharedFilesReload(config: config) }
    func coreLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) { try await base.coreLog(config: config) }
    func debugLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) { try await base.debugLog(config: config) }
    func categories(config: AMuleConnectionConfig) async throws -> ([BridgeCategoryPayload], String) { try await base.categories(config: config) }
    func categoryCreate(name: String, path: String, comment: String, color: Int, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await base.categoryCreate(name: name, path: path, comment: comment, color: color, priority: priority, config: config)
    }
    func categoryDelete(categoryID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await base.categoryDelete(categoryID: categoryID, config: config) }
    func ipfilterReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await base.ipfilterReload(config: config) }
    func ipfilterUpdate(url: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await base.ipfilterUpdate(url: url, config: config) }
    func friends(config: AMuleConnectionConfig) async throws -> ([BridgeFriendPayload], String) { try await base.friends(config: config) }
    func friendRemove(friendID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await base.friendRemove(friendID: friendID, config: config) }
    func friendSlot(friendID: Int, enabled: Bool, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await base.friendSlot(friendID: friendID, enabled: enabled, config: config) }
    func clearCompleted(ecids: [Int], config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await base.clearCompleted(ecids: ecids, config: config) }
    func priority(hash: String, value: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { try await base.priority(hash: hash, value: value, config: config) }
    func statsTree(capping: Int?, config: AMuleConnectionConfig) async throws -> (BridgeStatsTreeNodePayload, String) { try await base.statsTree(capping: capping, config: config) }
    func statsGraphs(width: Int, scale: Int, last: Double?, config: AMuleConnectionConfig) async throws -> (BridgeStatsGraphsPayload, String) {
        try await base.statsGraphs(width: width, scale: scale, last: last, config: config)
    }
}
