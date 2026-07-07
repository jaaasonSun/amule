import XCTest
@testable import AMuleNativeRemote
import AMuleECBridgeAdapter
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
        await waitForAction(in: model, description: "stop download refreshes") {
            bridge.invokedOperations.contains("download-stop") &&
                bridge.invokedOperations.contains("downloads") &&
                bridge.invokedOperations.contains("status")
        }

        let operations = bridge.invokedOperations
        let stopIndex = try XCTUnwrap(operations.firstIndex(of: "download-stop"))
        let downloadsIndex = try XCTUnwrap(operations.firstIndex(of: "downloads"))
        let statusIndex = try XCTUnwrap(operations.firstIndex(of: "status"))
        XCTAssertLessThan(stopIndex, downloadsIndex)
        XCTAssertLessThan(downloadsIndex, statusIndex)
    }

    func testAssignDownloadCategoryUsesSelectedCategoryID() async throws {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["download-set-category", "downloads", "status"])
        let model = AppModel(bridge: bridge)
        let item = DownloadItem.fixture(hash: "00112233445566778899aabbccddeeff")

        model.setDownloadCategory(item, categoryID: 7)
        await waitForAction(in: model, description: "download category assignment") {
            bridge.lastDownloadCategoryID == 7
        }

        XCTAssertEqual(bridge.lastDownloadCategoryID, 7)
    }

    func testSwapA4AFInvokesSelectedMode() async throws {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["download-a4af-auto", "downloads"])
        let model = AppModel(bridge: bridge)
        let item = DownloadItem.fixture(hash: "00112233445566778899aabbccddeeff")

        model.swapA4AF(item, mode: .toThisAuto)
        await waitForAction(in: model, description: "A4AF swap") {
            bridge.invokedOperations.contains("download-a4af") &&
                bridge.lastA4AFMode == .toThisAuto
        }

        XCTAssertTrue(bridge.invokedOperations.contains("download-a4af"))
        guard case .toThisAuto? = bridge.lastA4AFMode else {
            return XCTFail("Expected A4AF auto swap mode")
        }
    }

    func testConnectNowPreloadsCategoriesAfterCapabilities() async throws {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["categories", "downloads", "servers", "status"])
        bridge.categoriesResult = ([.fixture(id: 3, title: "Video")], #"{"ok":true,"categories":[{"id":3,"title":"Video"}]}"#)
        let model = AppModel(bridge: bridge)

        try await model.connectNow()

        let operations = bridge.invokedOperations
        XCTAssertEqual(operations.filter { $0 == "capabilities" }, ["capabilities"])
        let capabilitiesIndex = try XCTUnwrap(operations.firstIndex(of: "capabilities"))
        let categoriesIndex = try XCTUnwrap(operations.firstIndex(of: "categories"))
        XCTAssertLessThan(capabilitiesIndex, categoriesIndex)
        XCTAssertEqual(model.categories.map(\.title), ["Video"])
        XCTAssertEqual(model.lastError, "")
    }

    func testCategoryPreloadReadsWithoutAdvertisedCapability() async throws {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["downloads", "servers", "status"])
        bridge.categoriesResult = ([.fixture(id: 3, title: "Video")], #"{"ok":true,"categories":[{"id":3,"title":"Video"}]}"#)
        let model = AppModel(bridge: bridge)

        await model.refreshBridgeCapabilitiesAndPreloadCategories(logOutput: false, suppressErrors: true)

        XCTAssertTrue(bridge.invokedOperations.contains("capabilities"))
        XCTAssertTrue(bridge.invokedOperations.contains("categories"))
        XCTAssertEqual(model.categories.map(\.title), ["Video"])
        XCTAssertEqual(model.lastError, "")
    }

    private func waitForAction(
        in model: AppModel,
        description: String,
        until predicate: () -> Bool
    ) async {
        for _ in 0..<200 {
            if !model.isBusy, predicate() {
                return
            }
            await Task.yield()
        }

        XCTFail("Timed out waiting for \(description)")
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

private extension BridgeCategoryPayload {
    static func fixture(id: Int, title: String) -> BridgeCategoryPayload {
        BridgeCategoryPayload(
            id: id,
            title: title,
            path: "",
            comment: "",
            color: 0,
            priority: 0
        )
    }
}
