import XCTest
import enum AMuleECBridgeAdapter.RenameAcknowledgement

@testable import AMuleNativeRemote

final class RenameRefreshBehaviorTests: XCTestCase {
    @MainActor
    func testRenameDownloadRefreshesDownloadsUsingCurrentBaseline() async throws {
        let originalJSON = try BridgeEnvelopeFixtures.downloadEnvelope(downloads: [
            BridgeEnvelopeFixtures.completedMovie(name: "Original.mkv"),
        ])
        let originalPayload = try decodeDownloads(from: originalJSON)

        let renamedJSON = try BridgeEnvelopeFixtures.downloadEnvelope(downloads: [
            BridgeEnvelopeFixtures.completedMovie(name: "Corrected.mkv"),
        ])
        let renamedPayload = try decodeDownloads(from: renamedJSON)

        let bridge = RecordingFakeBridgeAdapter(
            downloadsResults: [(originalPayload, originalJSON), (renamedPayload, renamedJSON)],
            messageRaw: #"{"ok":true,"message":"Rename requested"}"#
        )
        let model = AppModel(bridge: bridge)

        model.refreshDownloads()
        await waitForDownloads(in: model, expectedNames: ["Original.mkv"])

        let item = try XCTUnwrap(model.downloads.first)
        model.renameDownload(item, to: "Corrected.mkv")
        await waitForDownloads(in: model, expectedNames: ["Corrected.mkv"])

        XCTAssertEqual(bridge.renameCalls.map(\.hash), [BridgeEnvelopeFixtures.completedMovieHash])
        XCTAssertEqual(bridge.renameCalls.map(\.name), ["Corrected.mkv"])
        XCTAssertEqual(model.lastDownloadsRawOutput, renamedJSON)
    }

    @MainActor
    func testRenameDownloadFailureSurfacesErrorWithoutRefresh() async throws {
        let originalJSON = try BridgeEnvelopeFixtures.downloadEnvelope(downloads: [
            BridgeEnvelopeFixtures.completedMovie(name: "Original.mkv"),
        ])
        let originalPayload = try decodeDownloads(from: originalJSON)

        let bridge = RecordingFakeBridgeAdapter(downloadsResults: [(originalPayload, originalJSON)])
        bridge.renameResult = .failure(message: "Unable to rename file.", raw: #"{"error":"Unable to rename file.","ok":false}"#)
        let model = AppModel(bridge: bridge)

        model.refreshDownloads()
        await waitForDownloads(in: model, expectedNames: ["Original.mkv"])

        let item = try XCTUnwrap(model.downloads.first)
        model.renameDownload(item, to: "Corrected.mkv")
        await waitForBusyToClear(in: model)

        XCTAssertEqual(bridge.renameCalls.map(\.hash), [BridgeEnvelopeFixtures.completedMovieHash])
        XCTAssertEqual(bridge.renameCalls.map(\.name), ["Corrected.mkv"])
        XCTAssertEqual(model.downloads.map(\.name), ["Original.mkv"])
        XCTAssertEqual(model.lastDownloadsRawOutput, originalJSON)
        XCTAssertEqual(model.lastError, "Unable to rename file.")
    }

    @MainActor
    func testRenameDownloadTimeoutSurfacesErrorAfterRefreshAndVerificationFails() async throws {
        let originalJSON = try BridgeEnvelopeFixtures.downloadEnvelope(downloads: [
            BridgeEnvelopeFixtures.completedMovie(name: "Original.mkv"),
        ])
        let originalPayload = try decodeDownloads(from: originalJSON)

        let refreshedJSON = try BridgeEnvelopeFixtures.downloadEnvelope(downloads: [
            BridgeEnvelopeFixtures.download(
                ecid: 202,
                hash: BridgeEnvelopeFixtures.completedMovieHash,
                name: "Original.mkv",
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
            ),
        ])
        let refreshedPayload = try decodeDownloads(from: refreshedJSON)

        let bridge = RecordingFakeBridgeAdapter(downloadsResults: [(originalPayload, originalJSON), (refreshedPayload, refreshedJSON)])
        bridge.renameResult = .timeout(message: "Rename requested", raw: #"{"ok":true,"message":"Rename requested"}"#)
        let model = AppModel(bridge: bridge)

        model.refreshDownloads()
        await waitForDownloads(in: model, expectedNames: ["Original.mkv"])

        let item = try XCTUnwrap(model.downloads.first)
        model.renameDownload(item, to: "Corrected.mkv")
        await waitForBusyToClear(in: model)

        XCTAssertEqual(bridge.renameCalls.map(\.hash), [BridgeEnvelopeFixtures.completedMovieHash])
        XCTAssertEqual(bridge.renameCalls.map(\.name), ["Corrected.mkv"])
        XCTAssertEqual(model.downloads.map(\.name), ["Original.mkv"])
        XCTAssertEqual(model.lastDownloadsRawOutput, refreshedJSON)
        XCTAssertEqual(model.lastError, "EC request timed out. The filename was not changed.")
    }

    @MainActor
    func testRenameDownloadTimeoutVerifiesSuccessAfterRefresh() async throws {
        let originalJSON = try BridgeEnvelopeFixtures.downloadEnvelope(downloads: [
            BridgeEnvelopeFixtures.completedMovie(name: "Original.mkv"),
        ])
        let originalPayload = try decodeDownloads(from: originalJSON)

        let refreshedJSON = try BridgeEnvelopeFixtures.downloadEnvelope(downloads: [
            BridgeEnvelopeFixtures.completedMovie(name: "Corrected.mkv"),
        ])
        let refreshedPayload = try decodeDownloads(from: refreshedJSON)

        let bridge = RecordingFakeBridgeAdapter(downloadsResults: [(originalPayload, originalJSON), (refreshedPayload, refreshedJSON)])
        bridge.renameResult = .timeout(message: "Rename requested", raw: #"{"ok":true,"message":"Rename requested"}"#)
        let model = AppModel(bridge: bridge)

        model.refreshDownloads()
        await waitForDownloads(in: model, expectedNames: ["Original.mkv"])

        let item = try XCTUnwrap(model.downloads.first)
        model.renameDownload(item, to: "Corrected.mkv")
        await waitForDownloads(in: model, expectedNames: ["Corrected.mkv"])

        XCTAssertEqual(bridge.renameCalls.map(\.hash), [BridgeEnvelopeFixtures.completedMovieHash])
        XCTAssertEqual(bridge.renameCalls.map(\.name), ["Corrected.mkv"])
        XCTAssertEqual(model.lastDownloadsRawOutput, refreshedJSON)
        XCTAssertEqual(model.lastError, "")
    }

    @MainActor
    func testRenameDownloadDisconnectedAfterSendVerifiesSuccessAfterRefresh() async throws {
        let originalJSON = try BridgeEnvelopeFixtures.downloadEnvelope(downloads: [
            BridgeEnvelopeFixtures.completedMovie(name: "Original.mkv"),
        ])
        let originalPayload = try decodeDownloads(from: originalJSON)

        let refreshedJSON = try BridgeEnvelopeFixtures.downloadEnvelope(downloads: [
            BridgeEnvelopeFixtures.completedMovie(name: "Corrected.mkv"),
        ])
        let refreshedPayload = try decodeDownloads(from: refreshedJSON)

        let bridge = RecordingFakeBridgeAdapter(downloadsResults: [(originalPayload, originalJSON), (refreshedPayload, refreshedJSON)])
        bridge.renameResult = .disconnectedAfterSend(message: "Rename requested", raw: #"{"ok":true,"message":"Rename requested"}"#)
        let model = AppModel(bridge: bridge)

        model.refreshDownloads()
        await waitForDownloads(in: model, expectedNames: ["Original.mkv"])

        let item = try XCTUnwrap(model.downloads.first)
        model.renameDownload(item, to: "Corrected.mkv")
        await waitForDownloads(in: model, expectedNames: ["Corrected.mkv"])

        XCTAssertEqual(bridge.renameCalls.map(\.hash), [BridgeEnvelopeFixtures.completedMovieHash])
        XCTAssertEqual(bridge.renameCalls.map(\.name), ["Corrected.mkv"])
        XCTAssertEqual(model.lastDownloadsRawOutput, refreshedJSON)
        XCTAssertEqual(model.lastError, "")
    }

    @MainActor
    private func waitForDownloads(in model: AppModel, expectedNames: [String]) async {
        for _ in 0..<200 {
            if !model.isBusy, model.downloads.map(\.name) == expectedNames {
                return
            }
            await Task.yield()
        }

        XCTFail("Timed out waiting for downloads: \(model.downloads.map(\.name))")
    }

    private func decodeDownloads(from json: String) throws -> [BridgeDownloadPayload] {
        let data = try XCTUnwrap(json.data(using: .utf8))
        return try XCTUnwrap(JSONDecoder().decode(BridgeEnvelope.self, from: data).downloads)
    }

    @MainActor
    private func waitForBusyToClear(in model: AppModel) async {
        for _ in 0..<200 {
            if !model.isBusy {
                return
            }
            await Task.yield()
        }

        XCTFail("Timed out waiting for busy state to clear")
    }
}
