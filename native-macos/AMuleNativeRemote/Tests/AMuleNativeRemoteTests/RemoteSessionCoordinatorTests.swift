import XCTest
import AMuleECBridgeAdapter
import SharedServices

@testable import AMuleNativeRemote

final class RemoteSessionCoordinatorTests: XCTestCase {
    @MainActor
    func testCoordinatorRefreshesStatusThenDownloads() async throws {
        let bridge = RecordingFakeBridgeAdapter(statusResult: connectedStatusResult)
        let coordinator = makeCoordinator(bridge: bridge)

        let status = try await coordinator.pollStatus()
        let downloads = try await coordinator.pollDownloads()

        XCTAssertTrue(try XCTUnwrap(status).0.connected)
        XCTAssertEqual(try XCTUnwrap(downloads).0.count, 0)
        XCTAssertEqual(bridge.statusCallCount, 1)
        XCTAssertEqual(bridge.downloadsCallCount, 1)
    }

    @MainActor
    func testPollRefreshSkipsWhileResourceRunning() async throws {
        let downloadsProbe = RefreshCallProbe(blockedCallNumbers: [1])
        let bridge = RecordingFakeBridgeAdapter()
        bridge.onDownloadsCall = { await downloadsProbe.recordCall() }
        let coordinator = makeCoordinator(bridge: bridge)

        let firstRefresh = Task { try await coordinator.pollDownloads() }
        guard await downloadsProbe.waitForCalls(1) else {
            XCTFail("The initial poll refresh did not reach the bridge")
            return
        }

        let secondPoll = try await coordinator.pollDownloads()
        let thirdPoll = try await coordinator.pollDownloads()
        let fourthPoll = try await coordinator.pollDownloads()
        let callsWhileRunning = await downloadsProbe.callCount()
        XCTAssertNil(secondPoll)
        XCTAssertNil(thirdPoll)
        XCTAssertNil(fourthPoll)
        XCTAssertEqual(callsWhileRunning, 1)

        await downloadsProbe.releaseBlockedCalls()
        _ = try await firstRefresh.value
        let stayedAtOneCall = await downloadsProbe.waitForCalls(1)
        let callsAfterCompletion = await downloadsProbe.callCount()
        XCTAssertTrue(stayedAtOneCall)
        XCTAssertEqual(callsAfterCompletion, 1)
    }

    @MainActor
    func testMacOSPollDoesNotOverlapDownloadsRefresh() async throws {
        let downloadsProbe = RefreshCallProbe(blockedCallNumbers: [1])
        let bridge = RecordingFakeBridgeAdapter(statusResult: connectedStatusResult)
        bridge.onDownloadsCall = { await downloadsProbe.recordCall() }
        let model = AppModel(bridge: bridge)
        model.setDownloadAutoRefreshEnabled(true)

        model.startAutoRefresh(intervalNanoseconds: 1_000_000)
        guard await downloadsProbe.waitForCalls(1) else {
            XCTFail("The initial macOS download poll did not reach the bridge")
            return
        }

        model.startAutoRefresh(intervalNanoseconds: 1_000_000)
        for _ in 0..<1_000 {
            if bridge.statusCallCount >= 2 {
                break
            }
            await Task.yield()
        }

        XCTAssertGreaterThanOrEqual(bridge.statusCallCount, 2)
        let downloadsCallCount = await downloadsProbe.callCount()
        XCTAssertEqual(downloadsCallCount, 1)

        model.stopAutoRefresh()
        await downloadsProbe.releaseBlockedCalls()
    }

    @MainActor
    func testRefreshesDifferentResourcesIndependently() async throws {
        let statusProbe = RefreshCallProbe(blockedCallNumbers: [1])
        let downloadsProbe = RefreshCallProbe(blockedCallNumbers: [1])
        let bridge = RecordingFakeBridgeAdapter(statusResult: connectedStatusResult)
        bridge.onStatusCall = { await statusProbe.recordCall() }
        bridge.onDownloadsCall = { await downloadsProbe.recordCall() }
        let coordinator = makeCoordinator(bridge: bridge)

        let statusRefresh = Task { try await coordinator.pollStatus() }
        let downloadsRefresh = Task { try await coordinator.pollDownloads() }

        let statusStarted = await statusProbe.waitForCalls(1)
        let downloadsStarted = await downloadsProbe.waitForCalls(1)
        let statusCalls = await statusProbe.callCount()
        let downloadsCalls = await downloadsProbe.callCount()
        XCTAssertTrue(statusStarted)
        XCTAssertTrue(downloadsStarted)
        XCTAssertEqual(statusCalls, 1)
        XCTAssertEqual(downloadsCalls, 1)

        await statusProbe.releaseBlockedCalls()
        await downloadsProbe.releaseBlockedCalls()
        _ = try await statusRefresh.value
        _ = try await downloadsRefresh.value
    }

    @MainActor
    func testManualRefreshQueuesOnePendingFollowUp() async throws {
        let downloadsProbe = RefreshCallProbe(blockedCallNumbers: [1])
        let bridge = RecordingFakeBridgeAdapter(downloadsResults: [
            ([makeDownloadPayload(name: "poll.iso")], "poll"),
            ([makeDownloadPayload(name: "manual-follow-up.iso")], "manual-follow-up"),
        ])
        bridge.onDownloadsCall = { await downloadsProbe.recordCall() }
        let coordinator = makeCoordinator(bridge: bridge)

        let pollRefresh = Task { try await coordinator.pollDownloads() }
        guard await downloadsProbe.waitForCalls(1) else {
            XCTFail("The running poll refresh did not reach the bridge")
            return
        }

        let firstManualRefresh = Task { try await coordinator.manualRefreshDownloads() }
        let secondManualRefresh = Task { try await coordinator.manualRefreshDownloads() }
        let thirdManualRefresh = Task { try await coordinator.manualRefreshDownloads() }
        for _ in 0..<100 {
            await Task.yield()
        }
        let callsWhileRunning = await downloadsProbe.callCount()
        XCTAssertEqual(callsWhileRunning, 1)

        await downloadsProbe.releaseBlockedCalls()
        _ = try await pollRefresh.value
        let pendingRefreshStarted = await downloadsProbe.waitForCalls(2)
        let callsAfterPendingRefresh = await downloadsProbe.callCount()
        XCTAssertTrue(pendingRefreshStarted)
        XCTAssertEqual(callsAfterPendingRefresh, 2)
        let firstFollowUpSnapshot = try await firstManualRefresh.value
        let secondFollowUpSnapshot = try await secondManualRefresh.value
        let thirdFollowUpSnapshot = try await thirdManualRefresh.value
        let followUpSnapshots = [
            firstFollowUpSnapshot,
            secondFollowUpSnapshot,
            thirdFollowUpSnapshot,
        ]
        XCTAssertEqual(followUpSnapshots.compactMap { $0?.0.first?.name }, [
            "manual-follow-up.iso",
            "manual-follow-up.iso",
            "manual-follow-up.iso",
        ])
    }

    @MainActor
    func testDownloadMutationQueuesSinglePostRefresh() async throws {
        let downloadsProbe = RefreshCallProbe(blockedCallNumbers: [1])
        let bridge = RecordingFakeBridgeAdapter()
        bridge.onDownloadsCall = { await downloadsProbe.recordCall() }
        let coordinator = makeCoordinator(bridge: bridge)

        let pollRefresh = Task { try await coordinator.pollDownloads() }
        guard await downloadsProbe.waitForCalls(1) else {
            XCTFail("The running poll refresh did not reach the bridge")
            return
        }

        let firstMutationRefresh = Task { try await coordinator.mutationRefreshDownloads() }
        let secondMutationRefresh = Task { try await coordinator.mutationRefreshDownloads() }
        for _ in 0..<100 {
            await Task.yield()
        }
        let callsWhileRunning = await downloadsProbe.callCount()
        XCTAssertEqual(callsWhileRunning, 1)

        await downloadsProbe.releaseBlockedCalls()
        _ = try await pollRefresh.value
        let pendingRefreshStarted = await downloadsProbe.waitForCalls(2)
        let callsAfterPendingRefresh = await downloadsProbe.callCount()
        XCTAssertTrue(pendingRefreshStarted)
        XCTAssertEqual(callsAfterPendingRefresh, 2)
        _ = try await firstMutationRefresh.value
        _ = try await secondMutationRefresh.value
    }

    @MainActor
    func testQueuedMutationRefreshAppliesFollowUpSnapshotToModel() async throws {
        let downloadsProbe = RefreshCallProbe(blockedCallNumbers: [1])
        let bridge = RecordingFakeBridgeAdapter(downloadsResults: [
            ([makeDownloadPayload(name: "poll.iso")], "poll"),
            ([makeDownloadPayload(name: "mutation-follow-up.iso")], "mutation-follow-up"),
        ])
        bridge.onDownloadsCall = { await downloadsProbe.recordCall() }
        let model = AppModel(bridge: bridge)

        let pollRefresh = Task {
            try await model.pollDownloadsNow(logOutput: false, suppressErrors: true)
        }
        guard await downloadsProbe.waitForCalls(1) else {
            return XCTFail("The running downloads poll did not reach the bridge")
        }

        let mutationRefresh = Task {
            try await model.mutationRefreshDownloadsNow(logOutput: false)
        }
        for _ in 0..<100 {
            await Task.yield()
        }
        await downloadsProbe.releaseBlockedCalls()
        try await pollRefresh.value
        try await mutationRefresh.value

        XCTAssertEqual(model.downloads.map(\.name), ["mutation-follow-up.iso"])
        let downloadsCalls = await downloadsProbe.callCount()
        XCTAssertEqual(downloadsCalls, 2)
    }

    @MainActor
    func testOldSessionRefreshCannotOverwriteReplacementSessionState() async throws {
        let downloadsProbe = RefreshCallProbe(blockedCallNumbers: [1])
        let bridge = RecordingFakeBridgeAdapter(downloadsResults: [
            ([makeDownloadPayload(name: "replacement.iso")], "replacement"),
            ([makeDownloadPayload(name: "stale.iso")], "stale"),
        ])
        bridge.onDownloadsCall = { await downloadsProbe.recordCall() }
        let model = AppModel(bridge: bridge)

        let oldSessionRefresh = Task {
            try await model.refreshDownloadsNow(logOutput: false)
        }
        guard await downloadsProbe.waitForCalls(1) else {
            return XCTFail("The old-session refresh did not reach the bridge")
        }

        model.host = "replacement.example"
        try await model.refreshDownloadsNow(logOutput: false)
        XCTAssertEqual(model.downloads.map(\.name), ["replacement.iso"])

        await downloadsProbe.releaseBlockedCalls()
        try await oldSessionRefresh.value
        XCTAssertEqual(model.downloads.map(\.name), ["replacement.iso"])
    }

    @MainActor
    func testFailedRefreshReturnsGateToIdle() async throws {
        let bridge = RecordingFakeBridgeAdapter(
            statusResult: connectedStatusResult,
            statusResults: [
                .failure(TransientStatusError()),
                .success(connectedStatusResult),
            ]
        )
        let coordinator = makeCoordinator(bridge: bridge)

        do {
            _ = try await coordinator.pollStatus()
            XCTFail("The first status request should surface its transient failure")
        } catch is TransientStatusError {
        }

        let recoveredStatus = try await coordinator.pollStatus()
        XCTAssertTrue(try XCTUnwrap(recoveredStatus).0.connected)
        XCTAssertEqual(bridge.statusCallCount, 2)
    }

    func testIOSFailurePolicyStopsUntilLifecycleRecovery() {
        XCTAssertEqual(RemoteSessionCoordinator.macOSFailurePolicy, .continuePolling)
        XCTAssertEqual(RemoteSessionCoordinator.iOSFailurePolicy, .stopAndRecoverViaLifecycle)
    }

    @MainActor
    private func makeCoordinator(bridge: RecordingFakeBridgeAdapter) -> RemoteSessionCoordinator {
        RemoteSessionCoordinator(
            bridge: bridge,
            config: AMuleConnectionConfig(password: "test-password")
        )
    }

    private var connectedStatusResult: (BridgeStatusPayload, String) {
        (
            BridgeStatusPayload(
                connected: true,
                ed2k: "Connected",
                kad: "Connected",
                downloadSpeed: 1_024,
                uploadSpeed: 512,
                queue: 1,
                sources: 2
            ),
            #"{"ok":true,"status":{}}"#
        )
    }

    private func makeDownloadPayload(name: String) -> BridgeDownloadPayload {
        BridgeDownloadPayload(
            ecid: 1,
            hash: "00112233445566778899aabbccddeeff",
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

    private struct TransientStatusError: Error {}
}

private actor RefreshCallProbe {
    private let blockedCallNumbers: Set<Int>
    private var calls = 0
    private var blockedCallContinuations: [CheckedContinuation<Void, Never>] = []

    init(blockedCallNumbers: Set<Int>) {
        self.blockedCallNumbers = blockedCallNumbers
    }

    func recordCall() async {
        calls += 1
        guard blockedCallNumbers.contains(calls) else { return }

        await withCheckedContinuation { continuation in
            blockedCallContinuations.append(continuation)
        }
    }

    func callCount() -> Int {
        calls
    }

    func waitForCalls(_ expectedCalls: Int) async -> Bool {
        for _ in 0..<1_000 {
            if calls >= expectedCalls {
                return true
            }
            await Task.yield()
        }
        return calls >= expectedCalls
    }

    func releaseBlockedCalls() {
        let continuations = blockedCallContinuations
        blockedCallContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }
}
