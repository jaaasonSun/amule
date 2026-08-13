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

@MainActor
final class IOSRemoteSessionCoordinatorTests: XCTestCase {
    func testManualRefreshesUpdateSnapshotsThroughCoordinator() async {
        let bridge = IOSRecordingRenameBridge(downloadsResults: [[]])
        let model = IOSAppModel(
            bridge: bridge,
            credentialStorage: InMemoryCredentialStorage(),
            appLifecycle: IOSLifecycleService(lifecycleBackground: PlatformServiceStubs.Lifecycle())
        )
        model.bridgeOps = ["servers"]
        model.downloads = [DownloadItemFixtures.download(id: "stale", name: "Stale.mkv")]

        model.refreshStatus()
        model.refreshDownloads()
        model.refreshServers()
        await waitFor {
            bridge.statusCallCount == 1
                && bridge.downloadsCallCount == 1
                && bridge.serversCallCount == 1
                && model.isSessionConnected
                && model.downloads.isEmpty
        }

        XCTAssertTrue(model.isSessionConnected)
        XCTAssertTrue(model.downloads.isEmpty)
    }

    func testSnapshotFailureStopsRefreshUntilLifecycleReconnect() async {
        let bridge = IOSRecordingRenameBridge(downloadsResults: [[]])
        bridge.failingStatusCallNumbers = [2]
        let lifecycle = IOSLifecycleService(lifecycleBackground: PlatformServiceStubs.Lifecycle())
        let model = IOSAppModel(
            bridge: bridge,
            credentialStorage: InMemoryCredentialStorage(),
            appLifecycle: lifecycle
        )
        model.bridgeOps = ["servers"]
        model.isSessionConnected = true

        model.startAutoRefresh(intervalNanoseconds: 0)
        await waitFor({ !model.isSessionConnected })

        XCTAssertEqual(bridge.statusCallCount, 2)
        XCTAssertEqual(bridge.downloadsCallCount, 1)
        XCTAssertEqual(bridge.serversCallCount, 1)

        model.handleScenePhaseChange(.background)
        model.handleScenePhaseChange(.active)
        await waitFor({ bridge.statusCallCount >= 4 && model.isSessionConnected })
        model.stopAutoRefresh()

        XCTAssertTrue(model.isSessionConnected)
        XCTAssertGreaterThanOrEqual(bridge.downloadsCallCount, 2)
        XCTAssertGreaterThanOrEqual(bridge.serversCallCount, 2)
    }

    func testOldAutoRefreshFailureCannotOverwriteOrCancelReplacementSession() async {
        let statusProbe = IOSRefreshCallProbe(blockedCallNumbers: [1, 2])
        let bridge = IOSRecordingRenameBridge(downloadsResults: [[]])
        bridge.failingStatusCallNumbers = [1]
        bridge.onStatusCall = { await statusProbe.recordCall() }
        let model = IOSAppModel(
            bridge: bridge,
            credentialStorage: InMemoryCredentialStorage(),
            appLifecycle: IOSLifecycleService(lifecycleBackground: PlatformServiceStubs.Lifecycle())
        )
        model.isSessionConnected = true
        model.startAutoRefresh(intervalNanoseconds: 0)
        guard await statusProbe.waitForCalls(1) else {
            return XCTFail("The old-session auto-refresh did not reach the bridge")
        }

        model.host = "replacement.example"
        model.isSessionConnected = true
        model.lastError = "replacement error"
        model.startAutoRefresh(intervalNanoseconds: 0)
        guard await statusProbe.waitForCalls(2) else {
            return XCTFail("The replacement auto-refresh did not reach the bridge")
        }

        await statusProbe.releaseNextBlockedCall()
        for _ in 0..<100 {
            await Task.yield()
        }
        await statusProbe.releaseNextBlockedCall()
        await waitFor { bridge.statusCallCount >= 3 }

        XCTAssertTrue(model.isSessionConnected)
        XCTAssertEqual(model.lastError, "replacement error")
        model.stopAutoRefresh()
    }

    func testOldConnectSuccessCannotOverwriteReplacementSessionState() async {
        let connectProbe = IOSRefreshCallProbe(blockedCallNumbers: [1])
        let bridge = IOSRecordingRenameBridge(downloadsResults: [[]])
        bridge.onConnectCall = { await connectProbe.recordCall() }
        let model = IOSAppModel(bridge: bridge, credentialStorage: InMemoryCredentialStorage())

        model.connect()
        guard await connectProbe.waitForCalls(1) else {
            return XCTFail("The old-session connect did not reach the bridge")
        }

        model.host = "replacement.example"
        model.isSessionConnected = true
        model.bridgeOps = ["replacement-op"]
        model.lastError = "replacement error"
        model.isBusy = true
        await connectProbe.releaseBlockedCalls()
        for _ in 0..<100 {
            await Task.yield()
        }

        XCTAssertTrue(model.isSessionConnected)
        XCTAssertEqual(model.bridgeOps, ["replacement-op"])
        XCTAssertEqual(model.lastError, "replacement error")
        XCTAssertTrue(model.isBusy)
    }

    func testOldConnectFailureCannotOverwriteReplacementSessionState() async {
        let connectProbe = IOSRefreshCallProbe(blockedCallNumbers: [1])
        let bridge = IOSRecordingRenameBridge(downloadsResults: [[]])
        bridge.connectError = IOSSnapshotFailure()
        bridge.onConnectCall = { await connectProbe.recordCall() }
        let model = IOSAppModel(bridge: bridge, credentialStorage: InMemoryCredentialStorage())

        model.connect()
        guard await connectProbe.waitForCalls(1) else {
            return XCTFail("The old-session connect did not reach the bridge")
        }

        model.host = "replacement.example"
        model.isSessionConnected = true
        model.lastError = "replacement error"
        model.isBusy = true
        await connectProbe.releaseBlockedCalls()
        for _ in 0..<100 {
            await Task.yield()
        }

        XCTAssertTrue(model.isSessionConnected)
        XCTAssertEqual(model.lastError, "replacement error")
        XCTAssertTrue(model.isBusy)
    }

    func testOldDisconnectSuccessCannotOverwriteReplacementSessionState() async {
        let disconnectProbe = IOSRefreshCallProbe(blockedCallNumbers: [1])
        let bridge = IOSRecordingRenameBridge(downloadsResults: [[]])
        bridge.onDisconnectCall = { await disconnectProbe.recordCall() }
        let model = IOSAppModel(bridge: bridge, credentialStorage: InMemoryCredentialStorage())
        model.isSessionConnected = true
        model.bridgeOps = ["replacement-op"]

        model.disconnect()
        guard await disconnectProbe.waitForCalls(1) else {
            return XCTFail("The old-session disconnect did not reach the bridge")
        }

        model.host = "replacement.example"
        model.isSessionConnected = true
        model.bridgeOps = ["replacement-op"]
        model.lastError = "replacement error"
        model.isBusy = true
        await disconnectProbe.releaseBlockedCalls()
        for _ in 0..<100 {
            await Task.yield()
        }

        XCTAssertTrue(model.isSessionConnected)
        XCTAssertEqual(model.bridgeOps, ["replacement-op"])
        XCTAssertEqual(model.lastError, "replacement error")
        XCTAssertTrue(model.isBusy)
    }

    func testOldDisconnectFailureCannotOverwriteReplacementSessionState() async {
        let disconnectProbe = IOSRefreshCallProbe(blockedCallNumbers: [1])
        let bridge = IOSRecordingRenameBridge(downloadsResults: [[]])
        bridge.disconnectError = IOSSnapshotFailure()
        bridge.onDisconnectCall = { await disconnectProbe.recordCall() }
        let model = IOSAppModel(bridge: bridge, credentialStorage: InMemoryCredentialStorage())
        model.isSessionConnected = true

        model.disconnect()
        guard await disconnectProbe.waitForCalls(1) else {
            return XCTFail("The old-session disconnect did not reach the bridge")
        }

        model.host = "replacement.example"
        model.isSessionConnected = true
        model.lastError = "replacement error"
        model.isBusy = true
        await disconnectProbe.releaseBlockedCalls()
        for _ in 0..<100 {
            await Task.yield()
        }

        XCTAssertTrue(model.isSessionConnected)
        XCTAssertEqual(model.lastError, "replacement error")
        XCTAssertTrue(model.isBusy)
    }

    func testOldSessionRefreshCannotOverwriteReplacementSessionState() async {
        let downloadsProbe = IOSRefreshCallProbe(blockedCallNumbers: [1])
        let bridge = IOSRecordingRenameBridge(downloadsResults: [
            [.download(name: "replacement.iso")],
            [.download(name: "stale.iso")],
        ])
        bridge.onDownloadsCall = { await downloadsProbe.recordCall() }
        let model = IOSAppModel(
            bridge: bridge,
            credentialStorage: InMemoryCredentialStorage(),
            appLifecycle: IOSLifecycleService(lifecycleBackground: PlatformServiceStubs.Lifecycle())
        )

        model.refreshDownloads()
        guard await downloadsProbe.waitForCalls(1) else {
            return XCTFail("The old-session refresh did not reach the bridge")
        }

        model.host = "replacement.example"
        model.refreshDownloads()
        await waitFor { model.downloads.map(\.name) == ["replacement.iso"] }

        await downloadsProbe.releaseBlockedCalls()
        await waitFor { bridge.downloadsCallCount == 2 }
        for _ in 0..<100 {
            await Task.yield()
        }
        XCTAssertEqual(model.downloads.map(\.name), ["replacement.iso"])
    }

    func testOldSessionSearchCannotOverwriteReplacementSessionState() async {
        let searchProbe = IOSRefreshCallProbe(blockedCallNumbers: [1])
        let bridge = IOSRecordingRenameBridge(
            downloadsResults: [[]],
            searchResults: [
                (progress: 84, results: [.search(name: "replacement.iso")]),
                (progress: 17, results: [.search(name: "stale.iso")]),
            ]
        )
        bridge.onSearchCall = { await searchProbe.recordCall() }
        let model = IOSAppModel(
            bridge: bridge,
            credentialStorage: InMemoryCredentialStorage(),
            appLifecycle: IOSLifecycleService(lifecycleBackground: PlatformServiceStubs.Lifecycle())
        )

        model.performSearch(query: "stale")
        guard await searchProbe.waitForCalls(1) else {
            return XCTFail("The old-session search did not reach the bridge")
        }

        model.host = "replacement.example"
        XCTAssertFalse(model.isSearchInProgress)
        model.performSearch(query: "replacement")
        XCTAssertTrue(model.isSearchInProgress)
        guard await searchProbe.waitForCalls(2) else {
            return XCTFail("The replacement search did not reach the bridge")
        }
        await waitFor {
            !model.isSearchInProgress && model.searchResults.map(\.name) == ["replacement.iso"]
        }

        model.lastError = "replacement error"
        await searchProbe.releaseBlockedCalls()
        guard await searchProbe.waitForCompletedCalls(2) else {
            return XCTFail("The stale search did not finish after release")
        }
        for _ in 0..<100 {
            await Task.yield()
        }

        XCTAssertEqual(model.searchProgress, 84)
        XCTAssertEqual(model.searchResults.map(\.name), ["replacement.iso"])
        XCTAssertEqual(model.lastError, "replacement error")
        XCTAssertFalse(model.isSearchInProgress)
    }

    func testCurrentSessionSearchPublishesResults() async {
        let bridge = IOSRecordingRenameBridge(
            downloadsResults: [[]],
            searchResults: [(progress: 100, results: [.search(name: "current.iso")])]
        )
        let model = IOSAppModel(
            bridge: bridge,
            credentialStorage: InMemoryCredentialStorage(),
            appLifecycle: IOSLifecycleService(lifecycleBackground: PlatformServiceStubs.Lifecycle())
        )

        model.performSearch(query: "current")
        await waitFor {
            !model.isSearchInProgress && model.searchResults.map(\.name) == ["current.iso"]
        }

        XCTAssertEqual(model.searchProgress, 100)
        XCTAssertEqual(model.lastError, "")
    }

    func testOldSessionSourcesCannotOverwriteReplacementSessionState() async {
        let sourcesProbe = IOSRefreshCallProbe(blockedCallNumbers: [1])
        let bridge = IOSRecordingRenameBridge(
            downloadsResults: [[]],
            sourceResults: [
                .success([.source(name: "replacement source")]),
                .success([.source(name: "stale source")]),
            ]
        )
        bridge.onSourcesCall = { await sourcesProbe.recordCall() }
        let model = IOSAppModel(
            bridge: bridge,
            credentialStorage: InMemoryCredentialStorage(),
            appLifecycle: IOSLifecycleService(lifecycleBackground: PlatformServiceStubs.Lifecycle())
        )
        let item = DownloadItemFixtures.download(id: IOSRecordingRenameBridge.hash, name: "current.iso")

        model.refreshDownloadSources(for: item)
        guard await sourcesProbe.waitForCalls(1) else {
            return XCTFail("The old-session source refresh did not reach the bridge")
        }

        model.host = "replacement.example"
        XCTAssertFalse(model.isRefreshingSources)
        model.refreshDownloadSources(for: item)
        await waitFor {
            bridge.sourcesCallCount == 2
                && model.sources(for: item).map(\.clientName) == ["replacement source"]
                && !model.isRefreshingSources
        }

        model.lastError = "replacement error"
        await sourcesProbe.releaseBlockedCalls()
        for _ in 0..<100 {
            await Task.yield()
        }

        XCTAssertEqual(model.sources(for: item).map(\.clientName), ["replacement source"])
        XCTAssertFalse(model.isRefreshingSources)
        XCTAssertEqual(model.lastError, "replacement error")
    }

    func testOldSessionSourceFailureCannotOverwriteReplacementSessionState() async {
        let sourcesProbe = IOSRefreshCallProbe(blockedCallNumbers: [1])
        let bridge = IOSRecordingRenameBridge(
            downloadsResults: [[]],
            sourceResults: [
                .success([.source(name: "replacement source")]),
                .failure(IOSSnapshotFailure()),
            ]
        )
        bridge.onSourcesCall = { await sourcesProbe.recordCall() }
        let model = IOSAppModel(
            bridge: bridge,
            credentialStorage: InMemoryCredentialStorage(),
            appLifecycle: IOSLifecycleService(lifecycleBackground: PlatformServiceStubs.Lifecycle())
        )
        let item = DownloadItemFixtures.download(id: IOSRecordingRenameBridge.hash, name: "current.iso")

        model.refreshDownloadSources(for: item)
        guard await sourcesProbe.waitForCalls(1) else {
            return XCTFail("The old-session source refresh did not reach the bridge")
        }

        model.host = "replacement.example"
        model.refreshDownloadSources(for: item)
        await waitFor {
            bridge.sourcesCallCount == 2
                && model.sources(for: item).map(\.clientName) == ["replacement source"]
                && !model.isRefreshingSources
        }

        model.lastError = "replacement error"
        await sourcesProbe.releaseBlockedCalls()
        for _ in 0..<100 {
            await Task.yield()
        }

        XCTAssertEqual(model.sources(for: item).map(\.clientName), ["replacement source"])
        XCTAssertFalse(model.isRefreshingSources)
        XCTAssertEqual(model.lastError, "replacement error")
    }

    func testOldSessionTransferLimitsCannotOverwriteReplacementSessionState() async {
        let limitsProbe = IOSRefreshCallProbe(blockedCallNumbers: [1])
        let bridge = IOSRecordingRenameBridge(
            downloadsResults: [[]],
            transferLimitsResults: [
                .success(BridgeConnectionPrefsPayload(maxDownload: 240, maxUpload: 36)),
                .success(BridgeConnectionPrefsPayload(maxDownload: 999, maxUpload: 888)),
            ]
        )
        bridge.onPrefsConnectionGetCall = { await limitsProbe.recordCall() }
        let model = IOSAppModel(
            bridge: bridge,
            credentialStorage: InMemoryCredentialStorage(),
            appLifecycle: IOSLifecycleService(lifecycleBackground: PlatformServiceStubs.Lifecycle())
        )
        model.bridgeOps = ["prefs-connection-get"]

        model.fetchTransferLimits()
        guard await limitsProbe.waitForCalls(1) else {
            return XCTFail("The old-session transfer-limit refresh did not reach the bridge")
        }

        model.host = "replacement.example"
        model.fetchTransferLimits()
        await waitFor {
            bridge.prefsConnectionGetCallCount == 2
                && model.downloadLimitKBps == 240
                && model.uploadLimitKBps == 36
        }

        model.lastError = "replacement error"
        await limitsProbe.releaseBlockedCalls()
        for _ in 0..<100 {
            await Task.yield()
        }

        XCTAssertEqual(model.downloadLimitKBps, 240)
        XCTAssertEqual(model.uploadLimitKBps, 36)
        XCTAssertEqual(model.lastError, "replacement error")
    }

    func testOldSessionTransferLimitFailureCannotOverwriteReplacementSessionState() async {
        let limitsProbe = IOSRefreshCallProbe(blockedCallNumbers: [1])
        let bridge = IOSRecordingRenameBridge(
            downloadsResults: [[]],
            transferLimitsResults: [
                .success(BridgeConnectionPrefsPayload(maxDownload: 240, maxUpload: 36)),
                .failure(IOSSnapshotFailure()),
            ]
        )
        bridge.onPrefsConnectionGetCall = { await limitsProbe.recordCall() }
        let model = IOSAppModel(
            bridge: bridge,
            credentialStorage: InMemoryCredentialStorage(),
            appLifecycle: IOSLifecycleService(lifecycleBackground: PlatformServiceStubs.Lifecycle())
        )
        model.bridgeOps = ["prefs-connection-get"]

        model.fetchTransferLimits()
        guard await limitsProbe.waitForCalls(1) else {
            return XCTFail("The old-session transfer-limit refresh did not reach the bridge")
        }

        model.host = "replacement.example"
        model.fetchTransferLimits()
        await waitFor {
            bridge.prefsConnectionGetCallCount == 2
                && model.downloadLimitKBps == 240
                && model.uploadLimitKBps == 36
        }

        model.lastError = "replacement error"
        await limitsProbe.releaseBlockedCalls()
        for _ in 0..<100 {
            await Task.yield()
        }

        XCTAssertEqual(model.downloadLimitKBps, 240)
        XCTAssertEqual(model.uploadLimitKBps, 36)
        XCTAssertEqual(model.lastError, "replacement error")
    }

    func testOldSessionRenameVerificationCannotOverwriteReplacementSessionState() async {
        let downloadsProbe = IOSRefreshCallProbe(blockedCallNumbers: [1])
        let bridge = IOSRecordingRenameBridge(downloadsResults: [
            [.download(name: "stale-renamed.iso")],
        ])
        bridge.onDownloadsCall = { await downloadsProbe.recordCall() }
        let model = IOSAppModel(
            bridge: bridge,
            credentialStorage: InMemoryCredentialStorage(),
            appLifecycle: IOSLifecycleService(lifecycleBackground: PlatformServiceStubs.Lifecycle())
        )
        model.renameVerificationRetryDelayNanoseconds = 0
        model.downloads = [DownloadItemFixtures.download(id: IOSRecordingRenameBridge.hash, name: "Original.iso")]
        let item = try! XCTUnwrap(model.downloads.first)

        model.renameDownload(item, to: "Renamed.iso")
        guard await downloadsProbe.waitForCalls(1) else {
            return XCTFail("The old-session rename verification did not reach the bridge")
        }

        model.host = "replacement.example"
        model.downloads = [DownloadItemFixtures.download(id: IOSRecordingRenameBridge.hash, name: "replacement.iso")]
        model.lastError = "replacement error"
        model.isBusy = true
        await downloadsProbe.releaseBlockedCalls()
        for _ in 0..<100 {
            await Task.yield()
        }

        XCTAssertEqual(model.downloads.map(\.name), ["replacement.iso"])
        XCTAssertEqual(model.lastError, "replacement error")
        XCTAssertTrue(model.isBusy)
    }

    func testOldSessionTransferLimitSetCannotOverwriteReplacementSessionState() async {
        let setProbe = IOSRefreshCallProbe(blockedCallNumbers: [1])
        let bridge = IOSRecordingRenameBridge(downloadsResults: [[]])
        bridge.onPrefsConnectionSetCall = { await setProbe.recordCall() }
        let model = IOSAppModel(bridge: bridge, credentialStorage: InMemoryCredentialStorage())
        model.bridgeOps = ["prefs-connection-set", "prefs-connection-get"]
        model.uploadLimitKBps = 36
        model.downloadLimitKBps = 240

        model.setTransferLimits(uploadKBps: 888, downloadKBps: 999)
        guard await setProbe.waitForCalls(1) else {
            return XCTFail("The old-session transfer-limit set did not reach the bridge")
        }

        model.host = "replacement.example"
        model.uploadLimitKBps = 36
        model.downloadLimitKBps = 240
        model.lastError = "replacement error"
        model.isBusy = true
        await setProbe.releaseBlockedCalls()
        for _ in 0..<100 {
            await Task.yield()
        }

        XCTAssertEqual(model.uploadLimitKBps, 36)
        XCTAssertEqual(model.downloadLimitKBps, 240)
        XCTAssertEqual(model.lastError, "replacement error")
        XCTAssertTrue(model.isBusy)
        XCTAssertEqual(bridge.prefsConnectionGetCallCount, 0)
    }

    func testOldSessionTransferLimitFetchFollowUpCannotOverwriteReplacementSessionState() async {
        let limitsProbe = IOSRefreshCallProbe(blockedCallNumbers: [1])
        let bridge = IOSRecordingRenameBridge(
            downloadsResults: [[]],
            transferLimitsResults: [
                .success(BridgeConnectionPrefsPayload(maxDownload: 999, maxUpload: 888)),
            ]
        )
        bridge.onPrefsConnectionGetCall = { await limitsProbe.recordCall() }
        let model = IOSAppModel(bridge: bridge, credentialStorage: InMemoryCredentialStorage())
        model.bridgeOps = ["prefs-connection-set", "prefs-connection-get"]

        model.setTransferLimits(uploadKBps: 36, downloadKBps: 240)
        guard await limitsProbe.waitForCalls(1) else {
            return XCTFail("The transfer-limit fetch follow-up did not reach the bridge")
        }

        model.host = "replacement.example"
        model.uploadLimitKBps = 12
        model.downloadLimitKBps = 34
        model.lastError = "replacement error"
        model.isBusy = true
        await limitsProbe.releaseBlockedCalls()
        for _ in 0..<100 {
            await Task.yield()
        }

        XCTAssertEqual(model.uploadLimitKBps, 12)
        XCTAssertEqual(model.downloadLimitKBps, 34)
        XCTAssertEqual(model.lastError, "replacement error")
        XCTAssertTrue(model.isBusy)
    }

    func testDownloadMutationsQueueOneCoordinatorFollowUp() async {
        await assertDownloadMutationQueuesSingleFollowUp(
            name: "pause",
            operation: { model, item in model.pauseDownload(item) },
            counter: { $0.pauseCallCount }
        )
        await assertDownloadMutationQueuesSingleFollowUp(
            name: "resume",
            operation: { model, item in model.resumeDownload(item) },
            counter: { $0.resumeCallCount }
        )
        await assertDownloadMutationQueuesSingleFollowUp(
            name: "remove/cancel",
            operation: { model, item in model.removeDownload(item) },
            counter: { $0.cancelCallCount }
        )
        await assertDownloadMutationQueuesSingleFollowUp(
            name: "clear completed",
            configure: { model in
                model.isSessionConnected = true
                model.bridgeOps = ["clear-completed"]
            },
            operation: { model, item in model.clearCompletedDownloads([item]) },
            counter: { $0.clearCompletedCallCount }
        )
    }

    func testSearchMutationsQueueOneCoordinatorFollowUp() async {
        await assertDownloadMutationQueuesSingleFollowUp(
            name: "add link",
            operation: { model, _ in
                model.addLinks("ed2k://|file|queued.iso|100|00112233445566778899aabbccddeeff|/")
            },
            counter: { $0.addLinkCallCount }
        )
        await assertDownloadMutationQueuesSingleFollowUp(
            name: "search-result download",
            operation: { model, _ in
                model.downloadSearchResult(
                    SearchResult(
                        index: 1,
                        hash: IOSRecordingRenameBridge.hash,
                        name: "result.iso",
                        sizeBytes: 100,
                        sources: 1,
                        completeSources: 1,
                        statusCode: 0,
                        status: "Available",
                        parentID: 0,
                        alreadyHave: false
                    )
                )
            },
            counter: { $0.downloadCallCount }
        )
    }

    func testServerConnectionMutationsQueueOneCoordinatorFollowUp() async {
        await assertServerStatusMutationQueuesSingleFollowUp(
            name: "server connect",
            initialConnected: false,
            finalConnected: true,
            operation: { model in
                model.connectServer(
                    ServerItem(
                        id: 1,
                        name: "Test Server",
                        description: "",
                        version: "",
                        address: "",
                        ip: "192.0.2.2",
                        port: 4661,
                        users: 1,
                        maxUsers: 10,
                        files: 1,
                        ping: 1,
                        failed: 0,
                        priority: 0,
                        isStatic: false
                    )
                )
            },
            counter: { $0.serverConnectCallCount }
        )
        await assertServerStatusMutationQueuesSingleFollowUp(
            name: "server disconnect",
            initialConnected: true,
            finalConnected: false,
            operation: { model in model.disconnectServer() },
            counter: { $0.serverDisconnectCallCount }
        )
        await assertServerStatusMutationQueuesSingleFollowUp(
            name: "local bookmark server connect",
            initialConnected: false,
            finalConnected: true,
            operation: { model in
                model.connectUserServer(UserServer(name: "Bookmark", ip: "192.0.2.5", port: 4661))
            },
            counter: { $0.serverConnectCallCount }
        )
    }

    func testServerListMutationsQueueOneCoordinatorFollowUp() async {
        await assertServerListMutationQueuesSingleFollowUp(
            name: "server add",
            capability: "server-add",
            operation: { model in model.addRemoteServer(address: "192.0.2.3:4661", name: "Added") },
            counter: { $0.serverAddCallCount }
        )
        await assertServerListMutationQueuesSingleFollowUp(
            name: "server remove",
            capability: "server-remove",
            operation: { model in
                model.removeRemoteServer(
                    ServerItem(
                        id: 1,
                        name: "Existing",
                        description: "",
                        version: "",
                        address: "",
                        ip: "192.0.2.2",
                        port: 4661,
                        users: 1,
                        maxUsers: 10,
                        files: 1,
                        ping: 1,
                        failed: 0,
                        priority: 0,
                        isStatic: false
                    )
                )
            },
            counter: { $0.serverRemoveCallCount }
        )
        await assertServerListMutationQueuesSingleFollowUp(
            name: "server update",
            capability: "server-update-from-url",
            operation: { model in model.updateRemoteServers(from: "https://example.test/server.met") },
            counter: { $0.serverUpdateCallCount }
        )
    }

    func testLocalServerBookmarkMutationsDoNotRefreshRemoteServers() {
        let bridge = IOSRecordingRenameBridge(downloadsResults: [[]])
        let model = IOSAppModel(bridge: bridge, credentialStorage: InMemoryCredentialStorage())
        model.userServers = []
        let original = UserServer(name: "Local", ip: "192.0.2.4", port: 4661)

        model.addServer(name: original.name, ip: original.ip, port: original.port)
        XCTAssertEqual(model.userServers.map(\.endpointText), ["192.0.2.4:4661"])
        let added = try! XCTUnwrap(model.userServers.first)
        model.editUserServer(added, newName: "Updated", newIP: "192.0.2.5", newPort: 4662)
        XCTAssertEqual(model.userServers.first?.endpointText, "192.0.2.5:4662")
        if let edited = model.userServers.first {
            model.removeUserServer(edited)
        }

        XCTAssertTrue(model.userServers.isEmpty)
        XCTAssertEqual(bridge.serversCallCount, 0)
        model.persistUserServers()
    }

    func testOldSessionBusyMutationClearsBusyOnReplacementAndCannotOverwriteState() async {
        let downloadsProbe = IOSRefreshCallProbe(blockedCallNumbers: [1])
        let mutationProbe = IOSRefreshCallProbe(blockedCallNumbers: [])
        let bridge = IOSRecordingRenameBridge(
            downloadsResults: [
                [.download(name: "replacement.iso")],
                [.download(name: "old-session.iso")],
                [.download(name: "stale-mutation.iso")],
            ]
        )
        bridge.onDownloadsCall = { await downloadsProbe.recordCall() }
        bridge.onMutationCall = { await mutationProbe.recordCall() }
        let model = IOSAppModel(
            bridge: bridge,
            credentialStorage: InMemoryCredentialStorage(),
            appLifecycle: IOSLifecycleService(lifecycleBackground: PlatformServiceStubs.Lifecycle())
        )
        let item = DownloadItemFixtures.download(id: IOSRecordingRenameBridge.hash, name: "current.iso")

        model.refreshDownloads()
        guard await downloadsProbe.waitForCalls(1) else {
            return XCTFail("The old-session refresh did not reach the bridge")
        }
        model.removeDownload(item)
        guard await mutationProbe.waitForCalls(1) else {
            return XCTFail("The old-session mutation did not reach the bridge")
        }
        try? await Task.sleep(nanoseconds: 1_000_000)

        model.host = "replacement.example"
        XCTAssertFalse(model.isBusy)
        model.lastError = "replacement error"
        model.downloadFeedback = "replacement feedback"
        model.refreshDownloads()
        await waitFor {
            bridge.downloadsCallCount == 2 && model.downloads.map(\.name) == ["replacement.iso"]
        }

        await downloadsProbe.releaseBlockedCalls()
        await waitFor { bridge.downloadsCallCount == 3 }
        for _ in 0..<100 {
            await Task.yield()
        }

        XCTAssertEqual(bridge.downloadsCallCount, 3)
        XCTAssertEqual(model.downloads.map(\.name), ["replacement.iso"])
        XCTAssertFalse(model.isBusy)
        XCTAssertEqual(model.lastError, "replacement error")
        XCTAssertEqual(model.downloadFeedback, "replacement feedback")
    }

    private func assertDownloadMutationQueuesSingleFollowUp(
        name: String,
        configure: (IOSAppModel) -> Void = { _ in },
        operation: @escaping (IOSAppModel, DownloadItem) -> Void,
        counter: @escaping (IOSRecordingRenameBridge) -> Int
    ) async {
        let downloadsProbe = IOSRefreshCallProbe(blockedCallNumbers: [1])
        let mutationProbe = IOSRefreshCallProbe(blockedCallNumbers: [])
        let bridge = IOSRecordingRenameBridge(
            downloadsResults: [
                [.download(name: "before-\(name).iso")],
                [.download(name: "after-\(name).iso")],
            ]
        )
        bridge.onDownloadsCall = { await downloadsProbe.recordCall() }
        bridge.onMutationCall = { await mutationProbe.recordCall() }
        let model = IOSAppModel(
            bridge: bridge,
            credentialStorage: InMemoryCredentialStorage(),
            appLifecycle: IOSLifecycleService(lifecycleBackground: PlatformServiceStubs.Lifecycle())
        )
        configure(model)
        let item = DownloadItemFixtures.download(id: IOSRecordingRenameBridge.hash, name: "current.iso")

        model.refreshDownloads()
        guard await downloadsProbe.waitForCalls(1) else {
            return XCTFail("The active refresh for \(name) did not reach the bridge")
        }
        operation(model, item)
        guard await mutationProbe.waitForCalls(1) else {
            return XCTFail("The \(name) mutation did not reach the bridge")
        }
        try? await Task.sleep(nanoseconds: 1_000_000)

        await downloadsProbe.releaseBlockedCalls()
        await waitFor({ bridge.downloadsCallCount == 2 }, message: "\(name) did not perform the queued follow-up refresh")
        await waitFor({ model.downloads.map(\.name) == ["after-\(name).iso"] }, message: "\(name) did not publish the follow-up downloads")
        await waitFor({ !model.isBusy }, message: "\(name) did not clear busy state")

        XCTAssertEqual(bridge.downloadsCallCount, 2, "\(name) should queue exactly one follow-up")
        XCTAssertEqual(counter(bridge), 1, "\(name) bridge mutation should run once")
    }

    private func assertServerStatusMutationQueuesSingleFollowUp(
        name: String,
        initialConnected: Bool,
        finalConnected: Bool,
        operation: @escaping (IOSAppModel) -> Void,
        counter: @escaping (IOSRecordingRenameBridge) -> Int
    ) async {
        let statusProbe = IOSRefreshCallProbe(blockedCallNumbers: [1])
        let mutationProbe = IOSRefreshCallProbe(blockedCallNumbers: [])
        let bridge = IOSRecordingRenameBridge(
            downloadsResults: [[]],
            statusResults: [
                .status(connected: initialConnected),
                .status(connected: finalConnected),
            ]
        )
        bridge.onStatusCall = { await statusProbe.recordCall() }
        bridge.onMutationCall = { await mutationProbe.recordCall() }
        let model = IOSAppModel(
            bridge: bridge,
            credentialStorage: InMemoryCredentialStorage(),
            appLifecycle: IOSLifecycleService(lifecycleBackground: PlatformServiceStubs.Lifecycle())
        )
        model.bridgeOps = ["server-connect", "server-disconnect"]
        model.isSessionConnected = initialConnected

        model.refreshStatus()
        guard await statusProbe.waitForCalls(1) else {
            return XCTFail("The active status refresh for \(name) did not reach the bridge")
        }
        operation(model)
        guard await mutationProbe.waitForCalls(1) else {
            return XCTFail("The \(name) mutation did not reach the bridge")
        }

        await statusProbe.releaseBlockedCalls()
        await waitFor {
            bridge.statusCallCount == 2 && model.isSessionConnected == finalConnected
        }

        XCTAssertEqual(bridge.statusCallCount, 2, "\(name) should queue exactly one follow-up")
        XCTAssertEqual(counter(bridge), 1, "\(name) bridge mutation should run once")
    }

    private func assertServerListMutationQueuesSingleFollowUp(
        name: String,
        capability: String,
        operation: @escaping (IOSAppModel) -> Void,
        counter: @escaping (IOSRecordingRenameBridge) -> Int
    ) async {
        let serversProbe = IOSRefreshCallProbe(blockedCallNumbers: [1])
        let mutationProbe = IOSRefreshCallProbe(blockedCallNumbers: [])
        let bridge = IOSRecordingRenameBridge(
            downloadsResults: [[]],
            serversResults: [
                [.server(name: "before")],
                [.server(name: "after")],
            ]
        )
        bridge.onServersCall = { await serversProbe.recordCall() }
        bridge.onMutationCall = { await mutationProbe.recordCall() }
        let model = IOSAppModel(
            bridge: bridge,
            credentialStorage: InMemoryCredentialStorage(),
            appLifecycle: IOSLifecycleService(lifecycleBackground: PlatformServiceStubs.Lifecycle())
        )
        model.bridgeOps = ["servers", capability]
        model.isSessionConnected = true

        model.refreshServers()
        guard await serversProbe.waitForCalls(1) else {
            return XCTFail("The active server refresh for \(name) did not reach the bridge")
        }
        operation(model)
        guard await mutationProbe.waitForCalls(1) else {
            return XCTFail("The \(name) mutation did not reach the bridge")
        }

        await serversProbe.releaseBlockedCalls()
        await waitFor {
            bridge.serversCallCount == 2 && model.servers.map(\.name) == ["after"]
        }

        XCTAssertEqual(bridge.serversCallCount, 2, "\(name) should queue exactly one follow-up")
        XCTAssertEqual(counter(bridge), 1, "\(name) bridge mutation should run once")
    }

    private func waitFor(
        _ condition: @escaping @MainActor () -> Bool,
        message: String = "Timed out waiting for refresh state",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while ContinuousClock.now < deadline {
            if condition() {
                return
            }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }

        XCTFail(message, file: file, line: line)
    }

}

final class IOSRecordingRenameBridge: BridgeProtocol, @unchecked Sendable {
    static let hash = "00112233445566778899aabbccddeeff"

    var renameCalls: [(hash: String, name: String)] = []
    var connectError: Error?
    var disconnectError: Error?
    var prefsConnectionSetError: Error?
    var failingStatusCallNumbers: Set<Int> = []
    private(set) var connectCallCount = 0
    private(set) var disconnectCallCount = 0
    private(set) var statusCallCount = 0
    private(set) var downloadsCallCount = 0
    private(set) var serversCallCount = 0
    private(set) var searchCallCount = 0
    private(set) var sourcesCallCount = 0
    private(set) var prefsConnectionGetCallCount = 0
    private(set) var pauseCallCount = 0
    private(set) var resumeCallCount = 0
    private(set) var cancelCallCount = 0
    private(set) var clearCompletedCallCount = 0
    private(set) var downloadCallCount = 0
    private(set) var addLinkCallCount = 0
    private(set) var prefsConnectionSetCallCount = 0
    private(set) var serverConnectCallCount = 0
    private(set) var serverDisconnectCallCount = 0
    private(set) var serverAddCallCount = 0
    private(set) var serverRemoveCallCount = 0
    private(set) var serverUpdateCallCount = 0
    var addLinkErrors: [Error] = []
    var onStatusCall: (@Sendable () async -> Void)?
    var onConnectCall: (@Sendable () async -> Void)?
    var onDisconnectCall: (@Sendable () async -> Void)?
    var onDownloadsCall: (@Sendable () async -> Void)?
    var onSearchCall: (@Sendable () async -> Void)?
    var onSourcesCall: (@Sendable () async -> Void)?
    var onServersCall: (@Sendable () async -> Void)?
    var onPrefsConnectionGetCall: (@Sendable () async -> Void)?
    var onPrefsConnectionSetCall: (@Sendable () async -> Void)?
    var onRenameCall: (@Sendable () async -> Void)?
    var onMutationCall: (@Sendable () async -> Void)?
    private let messageRaw = #"{"ok":true}"#
    private var queuedDownloadsResults: [[BridgeDownloadPayload]]
    private var queuedStatusResults: [BridgeStatusPayload]
    private var queuedServersResults: [[BridgeServerPayload]]
    private var queuedSearchResults: [(progress: Int, results: [BridgeSearchPayload])]
    private var queuedSourceResults: [Result<[BridgeDownloadSourcePayload], IOSSnapshotFailure>]
    private var queuedTransferLimitsResults: [Result<BridgeConnectionPrefsPayload, IOSSnapshotFailure>]

    init(
        downloadsResults: [[BridgeDownloadPayload]],
        statusResults: [BridgeStatusPayload] = [],
        serversResults: [[BridgeServerPayload]] = [],
        searchResults: [(progress: Int, results: [BridgeSearchPayload])] = [],
        sourceResults: [Result<[BridgeDownloadSourcePayload], IOSSnapshotFailure>] = [],
        transferLimitsResults: [Result<BridgeConnectionPrefsPayload, IOSSnapshotFailure>] = []
    ) {
        self.queuedDownloadsResults = downloadsResults
        self.queuedStatusResults = statusResults
        self.queuedServersResults = serversResults
        self.queuedSearchResults = searchResults
        self.queuedSourceResults = sourceResults
        self.queuedTransferLimitsResults = transferLimitsResults
    }

    func connect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        connectCallCount += 1
        if let onConnectCall {
            await onConnectCall()
        }
        if let connectError {
            throw connectError
        }
        return ("ok", "{}")
    }
    func disconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        disconnectCallCount += 1
        if let onDisconnectCall {
            await onDisconnectCall()
        }
        if let disconnectError {
            throw disconnectError
        }
        return ("ok", "{}")
    }
    func capabilities(config: AMuleConnectionConfig) async throws -> (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String) { (1, ECCapabilities(ops: ["servers"]), "{}") }
    func status(config: AMuleConnectionConfig) async throws -> (BridgeStatusPayload, String) {
        statusCallCount += 1
        if let onStatusCall {
            await onStatusCall()
        }
        if failingStatusCallNumbers.contains(statusCallCount) {
            throw IOSSnapshotFailure()
        }
        if !queuedStatusResults.isEmpty {
            return (queuedStatusResults.removeFirst(), "{}")
        }
        return (ECStatus(connected: true, ed2k: "Connected", kad: "Connected", downloadSpeed: 0, uploadSpeed: 0, queue: 0, sources: 0), "{}")
    }
    func connectionState(config: AMuleConnectionConfig) async throws -> (BridgeConnectionStatePayload, String) {
        (ECConnectionState(ed2kConnected: false, ed2kConnecting: false, kadConnected: false, kadFirewalled: false, kadRunning: false), "{}")
    }
    func downloads(config: AMuleConnectionConfig) async throws -> ([BridgeDownloadPayload], String) {
        downloadsCallCount += 1
        if let onDownloadsCall {
            await onDownloadsCall()
        }
        guard !queuedDownloadsResults.isEmpty else { return ([], "{}") }
        return (queuedDownloadsResults.removeFirst(), "{}")
    }
    func search(request: ECSearchRequest, polls: Int, pollIntervalMs: Int, config: AMuleConnectionConfig) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String) {
        searchCallCount += 1
        if let onSearchCall {
            await onSearchCall()
        }
        guard !queuedSearchResults.isEmpty else { return (0, [], "{}") }
        let result = queuedSearchResults.removeFirst()
        return (result.progress, result.results, "{}")
    }
    func search(scope: String, query: String, polls: Int, pollIntervalMs: Int, config: AMuleConnectionConfig) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String) {
        try await search(request: ECSearchRequest(scope: scope, query: query), polls: polls, pollIntervalMs: pollIntervalMs, config: config)
    }
    func searchStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func download(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        downloadCallCount += 1
        if let onMutationCall {
            await onMutationCall()
        }
        return ("ok", "{}")
    }
    func addLink(link: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        addLinkCallCount += 1
        if let onMutationCall {
            await onMutationCall()
        }
        if !addLinkErrors.isEmpty {
            throw addLinkErrors.removeFirst()
        }
        return ("ok", "{}")
    }
    func rename(hash: String, name: String, config: AMuleConnectionConfig) async throws -> RenameAcknowledgement {
        renameCalls.append((hash, name))
        if let onRenameCall {
            await onRenameCall()
        }
        return .success(message: "Rename requested", raw: "{}")
    }
    func pause(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        pauseCallCount += 1
        if let onMutationCall {
            await onMutationCall()
        }
        return ("ok", "{}")
    }
    func resume(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        resumeCallCount += 1
        if let onMutationCall {
            await onMutationCall()
        }
        return ("ok", "{}")
    }
    func stop(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func swapA4AF(hash: String, mode: ECOperations.A4AFSwapMode, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func downloadSetCategory(hash: String, categoryID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func serverConnect(ip: String?, port: Int?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        serverConnectCallCount += 1
        if let onMutationCall {
            await onMutationCall()
        }
        return ("ok", "{}")
    }
    func serverDisconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        serverDisconnectCallCount += 1
        if let onMutationCall {
            await onMutationCall()
        }
        return ("ok", "{}")
    }
    func serverAdd(address: String, name: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        serverAddCallCount += 1
        if let onMutationCall {
            await onMutationCall()
        }
        return ("ok", "{}")
    }
    func serverRemove(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        serverRemoveCallCount += 1
        if let onMutationCall {
            await onMutationCall()
        }
        return ("ok", "{}")
    }
    func serverSetStatic(ecid: Int, isStatic: Bool, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func serverSetPriority(ecid: Int, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func prefsConnectionGet(config: AMuleConnectionConfig) async throws -> (BridgeConnectionPrefsPayload, String) {
        prefsConnectionGetCallCount += 1
        if let onPrefsConnectionGetCall {
            await onPrefsConnectionGetCall()
        }
        guard !queuedTransferLimitsResults.isEmpty else {
            return (ECConnectionPrefs(maxDownload: 0, maxUpload: 0), "{}")
        }
        switch queuedTransferLimitsResults.removeFirst() {
        case .success(let payload):
            return (payload, "{}")
        case .failure(let error):
            throw error
        }
    }
    func prefsConnectionSet(maxDownload: Int, maxUpload: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        prefsConnectionSetCallCount += 1
        if let onPrefsConnectionSetCall {
            await onPrefsConnectionSetCall()
        }
        if let prefsConnectionSetError {
            throw prefsConnectionSetError
        }
        return ("ok", "{}")
    }
    func prefsConnectionSet(prefs: BridgeConnectionPrefsPayload, group: ECOperations.PreferencesGroup, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func cancel(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        cancelCallCount += 1
        if let onMutationCall {
            await onMutationCall()
        }
        return ("ok", "{}")
    }
    func servers(config: AMuleConnectionConfig) async throws -> ([BridgeServerPayload], String) {
        serversCallCount += 1
        if let onServersCall {
            await onServersCall()
        }
        guard !queuedServersResults.isEmpty else { return ([], "{}") }
        return (queuedServersResults.removeFirst(), "{}")
    }
    func sources(hash: String, config: AMuleConnectionConfig) async throws -> ([BridgeDownloadSourcePayload], String) {
        sourcesCallCount += 1
        if let onSourcesCall {
            await onSourcesCall()
        }
        guard !queuedSourceResults.isEmpty else { return ([], "{}") }
        switch queuedSourceResults.removeFirst() {
        case .success(let payload):
            return (payload, "{}")
        case .failure(let error):
            throw error
        }
    }
    func serverUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        serverUpdateCallCount += 1
        if let onMutationCall {
            await onMutationCall()
        }
        return ("ok", "{}")
    }
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
    func lastLogEntry(config: AMuleConnectionConfig) async throws -> String { "" }
    func resetDebugLog(config: AMuleConnectionConfig) async throws {}
    func shutdown(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
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
    func clearCompleted(ecids: [Int], config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        clearCompletedCallCount += 1
        if let onMutationCall {
            await onMutationCall()
        }
        return ("ok", "{}")
    }
    func priority(hash: String, value: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", "{}") }
    func sharedFilePriority(hash: String, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func sharedFileCommentRating(hash: String, comment: String, rating: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) { ("ok", messageRaw) }
    func statsTree(capping: Int?, config: AMuleConnectionConfig) async throws -> (BridgeStatsTreeNodePayload, String) { (ECStatsTreeNode(id: 0, label: "", value: 0, children: []), "{}") }
    func statsGraphs(width: Int, scale: Int, last: Double?, config: AMuleConnectionConfig) async throws -> (BridgeStatsGraphsPayload, String) { (ECStatsGraphs(last: 0, samples: []), "{}") }
}

struct IOSSnapshotFailure: LocalizedError {
    var errorDescription: String? { "Snapshot failed" }
}

private actor IOSRefreshCallProbe {
    private let blockedCallNumbers: Set<Int>
    private var calls = 0
    private var completedCalls = 0
    private var blockedCallContinuations: [CheckedContinuation<Void, Never>] = []

    init(blockedCallNumbers: Set<Int>) {
        self.blockedCallNumbers = blockedCallNumbers
    }

    func recordCall() async {
        calls += 1
        guard blockedCallNumbers.contains(calls) else {
            completedCalls += 1
            return
        }

        await withCheckedContinuation { continuation in
            blockedCallContinuations.append(continuation)
        }
        completedCalls += 1
    }

    func waitForCalls(_ expectedCalls: Int) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while ContinuousClock.now < deadline {
            if calls >= expectedCalls && blockedCallContinuations.count >= expectedBlockedContinuations(upTo: expectedCalls) {
                return true
            }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        return calls >= expectedCalls && blockedCallContinuations.count >= expectedBlockedContinuations(upTo: expectedCalls)
    }

    func waitForCompletedCalls(_ expectedCalls: Int) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while ContinuousClock.now < deadline {
            if completedCalls >= expectedCalls {
                return true
            }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        return completedCalls >= expectedCalls
    }

    private func expectedBlockedContinuations(upTo expectedCalls: Int) -> Int {
        blockedCallNumbers.filter { $0 <= expectedCalls }.count
    }

    func releaseBlockedCalls() {
        let continuations = blockedCallContinuations
        blockedCallContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }

    func releaseNextBlockedCall() {
        guard !blockedCallContinuations.isEmpty else { return }
        blockedCallContinuations.removeFirst().resume()
    }
}

extension BridgeDownloadPayload {
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

private extension BridgeSearchPayload {
    static func search(name: String) -> BridgeSearchPayload {
        ECSearchResult(
            id: 1,
            hash: IOSRecordingRenameBridge.hash,
            name: name,
            size: 100,
            sources: 1,
            completeSources: 1,
            statusCode: 0,
            status: "Available",
            parentID: 0,
            alreadyHave: false
        )
    }
}

private extension BridgeDownloadSourcePayload {
    static func source(name: String) -> BridgeDownloadSourcePayload {
        ECSource(
            clientID: 1,
            requestFileID: 1,
            clientName: name,
            userIP: "192.0.2.1",
            userPort: 4662,
            serverName: "Test Server",
            serverIP: "192.0.2.2",
            serverPort: 4661,
            software: "Test Client",
            softwareVersion: "1.0",
            downloadState: 0,
            downloadStateText: "Queued",
            sourceFrom: 0,
            sourceFromText: "Server",
            downSpeedKBps: 1,
            availableParts: 1,
            remoteQueueRank: 1,
            obfuscationStatus: 0,
            extendedProtocol: true,
            remoteFilename: "current.iso"
        )
    }
}

private extension BridgeStatusPayload {
    static func status(connected: Bool) -> BridgeStatusPayload {
        ECStatus(
            connected: connected,
            ed2k: connected ? "Connected" : "Disconnected",
            kad: connected ? "Connected" : "Disconnected",
            downloadSpeed: 0,
            uploadSpeed: 0,
            queue: 0,
            sources: 0
        )
    }
}

private extension BridgeServerPayload {
    static func server(name: String) -> BridgeServerPayload {
        ECServer(
            id: 1,
            name: name,
            description: "",
            version: "",
            address: "",
            ip: "192.0.2.2",
            port: 4661,
            users: 1,
            maxUsers: 10,
            files: 1,
            ping: 1,
            failed: 0,
            priority: 0,
            isStatic: false
        )
    }
}

final class InMemoryCredentialStorage: CredentialStorage, @unchecked Sendable {
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
