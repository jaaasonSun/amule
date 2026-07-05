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

    func testDownloadsLifecyclePreloadsCategoriesAfterCapabilities() throws {
        let source = try readPackageFile("Sources/AMuleNativeRemote/ContentView.swift")
        let capabilitiesRange = try XCTUnwrap(source.range(of: "await model.refreshBridgeCapabilities(logOutput: false, suppressErrors: true)"))
        let categoriesSupportRange = try XCTUnwrap(source.range(of: "if model.isBridgeOpSupported(\"categories\")"))
        let categoriesRefreshRange = try XCTUnwrap(source.range(of: "try? await model.refreshCategoriesNow(logOutput: false, suppressErrors: true)"))

        XCTAssertLessThan(capabilitiesRange.lowerBound, categoriesSupportRange.lowerBound)
        XCTAssertLessThan(categoriesSupportRange.lowerBound, categoriesRefreshRange.lowerBound)
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

    private func readPackageFile(_ relativePath: String) throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        while url.lastPathComponent != "AMuleNativeRemote" {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path {
                XCTFail("Could not locate AMuleNativeRemote package root from \(#filePath)")
                return ""
            }
            url = parent
        }

        return try String(contentsOf: url.appendingPathComponent(relativePath), encoding: .utf8)
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
