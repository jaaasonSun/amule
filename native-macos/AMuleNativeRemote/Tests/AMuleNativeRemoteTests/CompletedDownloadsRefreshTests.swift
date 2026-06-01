import XCTest
import AMuleECBridgeAdapter
import SharedModels
import SharedServices

@testable import AMuleNativeRemote

final class CompletedDownloadsRefreshTests: XCTestCase {
    func testDownloadItemFromBridgePreservesCompletedClassificationFields() throws {
        let data = try XCTUnwrap(Self.downloadsEnvelopeJSON.data(using: .utf8))

        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        let finished = try XCTUnwrap(
            DownloadItem
                .fromBridge(try XCTUnwrap(decoded.downloads))
                .first(where: { $0.name == "Finished Movie.mkv" })
        )

        XCTAssertEqual(finished.id, Self.completedHash)
        XCTAssertEqual(finished.name, "Finished Movie.mkv")
        XCTAssertTrue(finished.isCompleted)
        XCTAssertEqual(finished.statusCode, 9)
        XCTAssertEqual(finished.doneBytes, 1_048_576)
        XCTAssertEqual(finished.sizeBytes, 1_048_576)
        XCTAssertTrue(finished.isCompletedLike)
    }

    @MainActor
    func testRefreshDownloadsKeepsCompletedItemFromBridgeOutput() async throws {
        let data = try XCTUnwrap(Self.downloadsEnvelopeJSON.data(using: .utf8))
        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        let payload = try XCTUnwrap(decoded.downloads)

        let bridge = FakeBridgeAdapter()
        bridge.downloadsResult = (payload, Self.downloadsEnvelopeJSON)

        let model = AppModel(bridge: bridge)
        model.refreshDownloads()

        for _ in 0..<200 {
            if !model.isBusy, model.downloads.contains(where: { $0.name == "Finished Movie.mkv" }) {
                break
            }
            await Task.yield()
        }

        let finished = try XCTUnwrap(model.downloads.first(where: { $0.name == "Finished Movie.mkv" }))
        XCTAssertEqual(model.downloads.map(\.name), ["Active Part.iso", "Finished Movie.mkv"])
        XCTAssertEqual(model.lastDownloadsRawOutput, Self.downloadsEnvelopeJSON)
        XCTAssertTrue(finished.isCompleted)
        XCTAssertEqual(finished.statusCode, 9)
        XCTAssertEqual(finished.doneBytes, 1_048_576)
        XCTAssertEqual(finished.sizeBytes, 1_048_576)
        XCTAssertEqual(finished.id, Self.completedHash)
    }

    @MainActor
    func testTwoRefreshesPreserveActiveAndCompletedWhileExcludingMalformedRows() async throws {
        let firstData = try XCTUnwrap(Self.twoRefreshInitialEnvelopeJSON.data(using: .utf8))
        let firstDecoded = try JSONDecoder().decode(BridgeEnvelope.self, from: firstData)
        let firstPayload = try XCTUnwrap(firstDecoded.downloads)
        let secondData = try XCTUnwrap(Self.twoRefreshSparseEnvelopeJSON.data(using: .utf8))
        let secondDecoded = try JSONDecoder().decode(BridgeEnvelope.self, from: secondData)
        let secondPayload = try XCTUnwrap(secondDecoded.downloads)

        let bridge = FakeBridgeAdapter()
        bridge.downloadsResult = (firstPayload, Self.twoRefreshInitialEnvelopeJSON)

        let model = AppModel(bridge: bridge)
        model.refreshDownloads()
        await waitForDownloads(in: model, expectedNames: [
            "Active Part.iso",
            "Linux ISO.zip",
            "Finished Movie.mkv",
        ])

        XCTAssertTrue(secondPayload.contains { $0.name.isEmpty && $0.ecid == 303 })
        XCTAssertTrue(secondPayload.contains { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.ecid == 404 })
        XCTAssertTrue(secondPayload.contains { $0.shared && $0.ecid == 505 })
        let filteredSecondPayload = secondPayload.filter { item in
            !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (!item.shared || !item.partMet.isEmpty)
        }
        bridge.downloadsResult = (filteredSecondPayload, Self.twoRefreshSparseEnvelopeJSON)

        model.refreshDownloads()
        await waitForDownloads(in: model, expectedNames: [
            "Active Part.iso",
            "Linux ISO.zip",
            "Finished Movie.mkv",
        ])

        XCTAssertEqual(model.lastDownloadsRawOutput, Self.twoRefreshSparseEnvelopeJSON)
        XCTAssertEqual(model.downloads.count, 3)
        XCTAssertEqual(model.downloads.map(\.name), ["Active Part.iso", "Linux ISO.zip", "Finished Movie.mkv"])

        let activeNames = Set(model.downloads.filter { !$0.isCompleted }.map(\.name))
        XCTAssertEqual(activeNames, ["Active Part.iso", "Linux ISO.zip"])
        XCTAssertEqual(model.downloads.filter(\.isCompleted).map(\.name), ["Finished Movie.mkv"])
        XCTAssertTrue(model.downloads.allSatisfy { $0.trimmedDisplayName != nil })
        XCTAssertTrue(model.downloads.allSatisfy { !$0.status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        XCTAssertFalse(model.downloads.contains { $0.sizeBytes == 0 })
        XCTAssertFalse(model.downloads.contains { $0.name.isEmpty })
        XCTAssertFalse(model.downloads.contains { [303, 404, 505].contains($0.ecid) })
    }

    @MainActor
    func testClearCompletedDownloadsUsesCompletedECIDsAndRefreshesCurrentBaseline() async throws {
        let initialJSON = try BridgeEnvelopeFixtures.downloadEnvelope(downloads: [
            BridgeEnvelopeFixtures.activePart(),
            BridgeEnvelopeFixtures.completedMovie(),
        ])
        let initialPayload = try decodeDownloads(from: initialJSON)

        let refreshedJSON = try BridgeEnvelopeFixtures.downloadEnvelope(downloads: [
            BridgeEnvelopeFixtures.activePart(),
        ])
        let refreshedPayload = try decodeDownloads(from: refreshedJSON)

        let bridge = RecordingFakeBridgeAdapter(
            downloadsResults: [(initialPayload, initialJSON), (refreshedPayload, refreshedJSON)],
            messageRaw: #"{"ok":true,"message":"Completed downloads cleared"}"#
        )
        let model = AppModel(bridge: bridge)

        model.refreshDownloads()
        await waitForDownloads(in: model, expectedNames: ["Active Part.iso", "Finished Movie.mkv"])

        model.clearCompletedDownloads(model.downloads.filter(\.isCompleted))
        await waitForDownloads(in: model, expectedNames: ["Active Part.iso"])

        XCTAssertEqual(bridge.clearCompletedCalls, [[202]])
        XCTAssertEqual(model.lastDownloadsRawOutput, refreshedJSON)
    }

    @MainActor
    func testRefreshDownloadSourcesSuppressesTypedDownloadNotFound() async throws {
        let bridge = RecordingFakeBridgeAdapter()
        bridge.sourcesResult = .failure(AMuleClientError.downloadNotFound(BridgeEnvelopeFixtures.activePartHash))

        let model = AppModel(bridge: bridge)
        let item = try makeDownloadItem(from: BridgeEnvelopeFixtures.activePart())
        model.downloadSourcesByHash[item.id] = [sampleSourceItem()]

        model.refreshDownloadSources(for: item)
        await waitForSourceRefresh(in: model)

        XCTAssertEqual(bridge.sourceCalls, [item.id])
        XCTAssertEqual(model.sources(for: item), [])
        XCTAssertEqual(model.lastError, "")
    }

    @MainActor
    func testRefreshDownloadSourcesSurfacesGenericFailure() async throws {
        let bridge = RecordingFakeBridgeAdapter()
        bridge.sourcesResult = .failure(AMuleClientError.bridgeFailure("Source refresh exploded"))

        let model = AppModel(bridge: bridge)
        let item = try makeDownloadItem(from: BridgeEnvelopeFixtures.activePart())

        model.refreshDownloadSources(for: item)
        await waitForSourceRefresh(in: model)

        XCTAssertEqual(bridge.sourceCalls, [item.id])
        XCTAssertEqual(model.lastError, "Source refresh exploded")
        XCTAssertTrue(model.outputLog.contains("! sources failed\nSource refresh exploded"))
    }

    @MainActor
    func testRefreshDownloadSourcesCompletedItemSkipsBridgeAndClearsSources() async throws {
        let bridge = RecordingFakeBridgeAdapter()
        let model = AppModel(bridge: bridge)
        let item = try makeDownloadItem(from: BridgeEnvelopeFixtures.completedMovie())
        model.downloadSourcesByHash[item.id] = [sampleSourceItem()]
        model.isRefreshingSources = true

        model.refreshDownloadSources(for: item)

        XCTAssertEqual(bridge.sourceCalls, [])
        XCTAssertEqual(model.sources(for: item), [])
        XCTAssertFalse(model.isRefreshingSources)
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

    private func makeDownloadItem(from payload: [String: Any]) throws -> DownloadItem {
        let json = try BridgeEnvelopeFixtures.downloadEnvelope(downloads: [payload])
        return try XCTUnwrap(DownloadItem.fromBridge(decodeDownloads(from: json)).first)
    }

    @MainActor
    private func waitForSourceRefresh(in model: AppModel) async {
        for _ in 0..<200 {
            if !model.isRefreshingSources {
                return
            }
            await Task.yield()
        }

        XCTFail("Timed out waiting for source refresh")
    }

    private func sampleSourceItem() -> DownloadSourceItem {
        DownloadSourceItem(
            id: 1,
            requestFileID: 101,
            clientName: "peer",
            userIP: "127.0.0.1",
            userPort: 4662,
            serverName: "Example",
            serverIP: "1.2.3.4",
            serverPort: 4661,
            software: "aMule",
            softwareVersion: "2.3.3",
            downloadState: 3,
            downloadStateText: "Downloading",
            sourceFrom: 0,
            sourceFromText: "Unknown",
            downSpeedKBps: 12.5,
            availableParts: 8,
            remoteQueueRank: 1,
            obfuscationStatus: 0,
            extendedProtocol: true,
            remoteFilename: "Active Part.iso"
        )
    }

    private static let completedHash = BridgeEnvelopeFixtures.completedMovieHash

    private static let downloadsEnvelopeJSON = try! BridgeEnvelopeFixtures.downloadEnvelope(downloads: [
        BridgeEnvelopeFixtures.activePart(),
        BridgeEnvelopeFixtures.completedMovie(),
    ])

    private static let twoRefreshInitialEnvelopeJSON = try! BridgeEnvelopeFixtures.downloadEnvelope(downloads: [
        BridgeEnvelopeFixtures.activePart(),
        BridgeEnvelopeFixtures.linuxISO(),
        BridgeEnvelopeFixtures.completedMovie(),
    ])

    private static let twoRefreshSparseEnvelopeJSON = try! BridgeEnvelopeFixtures.downloadEnvelope(downloads: [
        BridgeEnvelopeFixtures.activePart(),
        BridgeEnvelopeFixtures.linuxISO(),
        BridgeEnvelopeFixtures.completedMovie(),
    ] + BridgeEnvelopeFixtures.malformedSparseRows())
}
