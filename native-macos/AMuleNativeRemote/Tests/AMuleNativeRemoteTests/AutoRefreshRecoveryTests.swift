import XCTest
import AMuleECBridgeAdapter

@testable import AMuleNativeRemote

final class AutoRefreshRecoveryTests: XCTestCase {
    @MainActor
    func testAutoRefreshContinuesAfterTransientStatusFailure() async throws {
        let json = try BridgeEnvelopeFixtures.downloadEnvelope(downloads: [
            BridgeEnvelopeFixtures.activePart(),
        ])
        let payload = try decodeDownloads(from: json)
        let connectedStatus = BridgeStatusPayload(
            connected: true,
            ed2k: "Connected",
            kad: "Connected",
            downloadSpeed: 1_024,
            uploadSpeed: 512,
            queue: 1,
            sources: 2
        )
        let bridge = RecordingFakeBridgeAdapter(
            downloadsResults: [(payload, json)],
            statusResult: (connectedStatus, #"{"ok":true,"status":{}}"#),
            statusResults: [
                .failure(TransientStatusError()),
                .success((connectedStatus, #"{"ok":true,"status":{}}"#)),
            ]
        )
        let downloadsProbe = AutoRefreshDownloadsProbe(blockedCallNumbers: [1])
        bridge.onDownloadsCall = { await downloadsProbe.recordCall() }
        let model = AppModel(bridge: bridge)
        model.isSessionConnected = true
        model.setDownloadAutoRefreshEnabled(true)

        model.startAutoRefresh(intervalNanoseconds: 1_000_000)
        guard await downloadsProbe.waitForCalls(1) else {
            XCTFail("The recovered download refresh did not reach the bridge")
            return
        }
        model.stopAutoRefresh()
        await downloadsProbe.releaseBlockedCalls()

        for _ in 0..<200 {
            if model.downloads.map(\.name) == ["Active Part.iso"] {
                break
            }
            try await Task.sleep(nanoseconds: 1_000_000)
        }

        XCTAssertEqual(bridge.downloadsCallCount, 1)
        XCTAssertEqual(model.downloads.map(\.name), ["Active Part.iso"])
        XCTAssertTrue(model.isSessionConnected)
    }

    private func decodeDownloads(from json: String) throws -> [BridgeDownloadPayload] {
        let data = try XCTUnwrap(json.data(using: .utf8))
        return try XCTUnwrap(JSONDecoder().decode(BridgeEnvelope.self, from: data).downloads)
    }

    private struct TransientStatusError: Error {}
}

private actor AutoRefreshDownloadsProbe {
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

    func waitForCalls(_ expectedCalls: Int) async -> Bool {
        for _ in 0..<1_000 {
            if calls >= expectedCalls {
                return true
            }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        return calls >= expectedCalls
    }

    func releaseBlockedCalls() {
        let continuations = blockedCallContinuations
        blockedCallContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }
}
