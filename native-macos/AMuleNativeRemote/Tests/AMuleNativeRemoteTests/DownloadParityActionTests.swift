import XCTest
@testable import AMuleNativeRemote
import AMuleECClient
import SharedModels

@MainActor
final class DownloadParityActionTests: XCTestCase {
    func testStopDownloadRefreshesDownloadsAndStatus() async throws {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["download-stop", "downloads", "status"])
        let model = AppModel(bridge: bridge)
        let item = DownloadItem.fixture(hash: "00112233445566778899aabbccddeeff")

        model.stopDownload(item)
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(bridge.invokedOperations.contains("download-stop"))
    }

    func testAssignDownloadCategoryUsesSelectedCategoryID() async throws {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["download-set-category", "downloads", "status"])
        let model = AppModel(bridge: bridge)
        let item = DownloadItem.fixture(hash: "00112233445566778899aabbccddeeff")

        model.setDownloadCategory(item, categoryID: 7)
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(bridge.lastDownloadCategoryID, 7)
    }

    func testSwapA4AFInvokesSelectedMode() async throws {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["download-a4af-auto", "downloads"])
        let model = AppModel(bridge: bridge)
        let item = DownloadItem.fixture(hash: "00112233445566778899aabbccddeeff")

        model.swapA4AF(item, mode: .toThisAuto)
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(bridge.invokedOperations.contains("download-a4af"))
        guard case .toThisAuto? = bridge.lastA4AFMode else {
            return XCTFail("Expected A4AF auto swap mode")
        }
    }
}

private extension DownloadItem {
    static func fixture(hash: String) -> DownloadItem {
        DownloadItem(
            ecid: 1,
            id: hash,
            name: "Example.iso",
            nameEncodingSuspect: false,
            nameEncodingSuggestion: nil,
            sizeBytes: 1_048_576,
            doneBytes: 262_144,
            transferredBytes: 262_144,
            progressValue: 25,
            sourceCurrent: 1,
            sourceTotal: 2,
            sourceTransferring: 1,
            sourceA4AF: 0,
            statusCode: 0,
            isCompleted: false,
            status: "Downloading",
            speedBytes: 1024,
            priority: 0,
            category: 0,
            partMetName: "001.part.met",
            lastSeenComplete: 0,
            lastReceived: 0,
            activeSeconds: 0,
            availableParts: 0,
            shared: false,
            alternativeNames: [],
            progressColors: []
        )
    }
}
