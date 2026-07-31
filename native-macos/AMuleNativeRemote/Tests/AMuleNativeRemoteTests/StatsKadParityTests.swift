import XCTest
import AMuleECBridgeAdapter
import AMuleECClient
@testable import AMuleNativeRemote

final class StatsKadParityTests: XCTestCase {
    private var packageRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.lastPathComponent != "AMuleNativeRemote" {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path {
                XCTFail("Could not locate AMuleNativeRemote package root from \(#filePath)")
                return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            }
            url = parent
        }
        return url
    }

    func testKadStatusSummaryKeepsEd2kAndKadSeparate() {
        let summary = NetworkStatusSummary(ed2k: "Connected HighID", kad: "Connected")
        XCTAssertEqual(summary.ed2k, "Connected HighID")
        XCTAssertEqual(summary.kad, "Connected")
    }

    func testStatsTreeLabelFormatterHandlesDaemonPrintfPlaceholdersSafely() {
        XCTAssertEqual(statsLabelByReplacingValuePlaceholders("Users: %s", value: 34), "Users: 34")
        XCTAssertEqual(statsLabelByReplacingValuePlaceholders("Total users: %llu", value: 34), "Total users: 34")
        XCTAssertEqual(statsLabelByReplacingValuePlaceholders("Ratio: %.2f", value: 12.5), "Ratio: 12.5")
        XCTAssertEqual(statsLabelByReplacingValuePlaceholders("Escaped: %% %s", value: 34), "Escaped: % 34")
        XCTAssertEqual(statsLabelByReplacingValuePlaceholders("Trailing: %", value: 34), "Trailing: %")
        XCTAssertEqual(statsLabelByReplacingValuePlaceholders("Progress: 100% done", value: 34), "Progress: 100% done")
        XCTAssertTrue(statsLabelContainsValuePlaceholder("Users: %d"))
        XCTAssertFalse(statsLabelContainsValuePlaceholder("Progress: 100% done"))
        XCTAssertFalse(statsLabelContainsValuePlaceholder("Escaped: %%"))
        XCTAssertFalse(statsLabelContainsValuePlaceholder("Trailing: %"))
    }

    func testStatsGraphRatesAndLegendUseKilobytesPerSecond() {
        XCTAssertEqual(statsGraphRateInKilobytesPerSecond(0), 0)
        XCTAssertEqual(statsGraphRateInKilobytesPerSecond(1_536), 1.5, accuracy: 0.001)
        XCTAssertEqual(statsGraphLegendLabel("Download", unit: "KB/s"), "Download (KB/s)")
        XCTAssertEqual(statsGraphLegendLabel("Upload", unit: "KB/s"), "Upload (KB/s)")
    }

    @MainActor
    func testStatisticsSurfaceRendersDaemonPrintfLabelsWithoutCrashing() throws {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["stats-tree", "stats-graphs"])
        let model = AppModel(bridge: bridge, credentialStorage: PlatformServiceStubs.Credentials())
        model.bridgeOps = bridge.capabilityOps
        model.statsTree = BridgeStatsTreeNodePayload(
            id: 1,
            label: "Statistics",
            value: 0,
            children: [
                BridgeStatsTreeNodePayload(id: 2, label: "Users: %s", value: 34, children: []),
                BridgeStatsTreeNodePayload(id: 3, label: "Total users: %llu", value: 34, children: []),
                BridgeStatsTreeNodePayload(id: 4, label: "Progress: 100% done", value: 0, children: [])
            ]
        )
        model.statsGraphs = BridgeStatsGraphsPayload(
            last: 3,
            samples: [
                ECStatsGraphSample(dl: 1, ul: 2, connections: 3, kad: 4),
                ECStatsGraphSample(dl: 2, ul: 3, connections: 4, kad: 5),
                ECStatsGraphSample(dl: 3, ul: 4, connections: 5, kad: 6)
            ]
        )

        let evidenceURL = repositoryRoot(from: packageRoot)
            .appendingPathComponent(".omo/evidence/shared-stats-crash-20260708/statistics-surface.png")
        try writeRenderedSurface(
            StatsWindowView(embeddedInMainWindow: true).environmentObject(model),
            size: CGSize(width: 820, height: 620),
            to: evidenceURL
        )
    }
}
