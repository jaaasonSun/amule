import XCTest
import SwiftUI
import AppKit
import AMuleECBridgeAdapter
import AMuleECClient
import SharedModels
@testable import AMuleNativeRemote

@MainActor
final class MacUIPolishTests: XCTestCase {
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

    private var evidenceRoot: URL {
        repositoryRoot(from: packageRoot)
            .appendingPathComponent(".sisyphus/evidence/task-5-p3-polish")
    }

    func testMainWindowExposesPersistentTextualStatusFooter() throws {
        let source = try source("Sources/AMuleNativeRemote/ContentView.swift")
        let footer = try mainFooterSource(in: source)

        XCTAssertTrue(source.contains("MainWindowStatusFooter"), "ContentView should install a named persistent status/footer surface.")
        XCTAssertTrue(source.contains("NetworkStatusSummary(status: model.status)"), "The footer should use the existing NetworkStatusSummary wrapper.")
        XCTAssertTrue(source.contains("Connection:"), "The footer should expose textual session connection status.")
        XCTAssertTrue(source.contains("eD2K:"), "The footer should expose textual eD2K status.")
        XCTAssertTrue(source.contains("Kad:"), "The footer should expose textual Kad status.")
        XCTAssertTrue(footer.contains("localizedED2KConnectionStatusText(for: summary.ed2k)"), "The footer should localize raw eD2K state text before rendering it.")
        XCTAssertTrue(footer.contains("localizedConnectionStatusText(for: summary.kad)"), "The footer should localize Kad with generic state wording.")
        XCTAssertFalse(footer.contains("ConnectionState" + "Indicator"), "The footer should be text-only, with no status indicator chip.")
        XCTAssertFalse(footer.contains("ConnectionState" + "Dot"), "The footer should not use a status dot.")
        XCTAssertFalse(footer.contains("Image("), "The footer should not use redundant status symbols.")
        XCTAssertFalse(footer.contains("systemImage"), "The footer should not use symbol-backed labels for status.")
        XCTAssertFalse(footer.contains("checkmark"), "The footer should not show a checkmark status glyph.")

        try writeRenderedSurface(
            ContentView().environmentObject(polishPreviewModel()),
            size: CGSize(width: 1120, height: 720),
            to: evidenceRoot.appendingPathComponent("main-status-footer.png")
        )
    }

    func testMainWindowFooterLivesInsideDownloadsShell() throws {
        let source = try source("Sources/AMuleNativeRemote/ContentView.swift")
        let baseBodyStart = try XCTUnwrap(source.range(of: "private var baseBody: some View {")?.lowerBound)
        let footerIndex = try XCTUnwrap(source.range(of: "MainWindowStatusFooter(")?.lowerBound)
        let navigationTitleIndex = try XCTUnwrap(source.range(of: ".navigationTitle(windowTitleText)")?.lowerBound)
        let downloadsPanelDeclarationIndex = try XCTUnwrap(source.range(of: "private var downloadsPanel: some View")?.lowerBound)

        XCTAssertGreaterThan(footerIndex, baseBodyStart, "The persistent footer should be declared inside the downloads shell body.")
        XCTAssertLessThan(footerIndex, navigationTitleIndex, "The persistent footer should be part of the downloads shell before title modifiers are applied.")
        XCTAssertLessThan(navigationTitleIndex, downloadsPanelDeclarationIndex, "The downloads shell body should close before the DownloadsPanel helper declaration begins.")
        XCTAssertTrue(source.contains("Divider()\n            MainWindowStatusFooter"), "A divider should separate pane/error content from the footer.")
    }

    func testFooterConnectionStatusTextIsFullyLocalized() {
        XCTAssertEqual(
            localizedED2KConnectionStatusText(for: "Connected to Razorback [1.2.3.4:4661] HighID"),
            LF("Connected to %@", "Razorback [1.2.3.4:4661] HighID")
        )
        XCTAssertEqual(
            localizedED2KConnectionStatusText(for: "Connecting to DonkeyServer [5.6.7.8:4661] LowID"),
            LF("Connecting to %@", "DonkeyServer [5.6.7.8:4661] LowID")
        )
        XCTAssertEqual(localizedED2KConnectionStatusText(for: "Connected"), L("Connected"))
        XCTAssertEqual(localizedED2KConnectionStatusText(for: "Disconnected"), L("Disconnected"))
        XCTAssertEqual(localizedED2KConnectionStatusText(for: "Connecting"), L("Connecting"))
        XCTAssertEqual(localizedED2KConnectionStatusText(for: ""), L("Unknown"))
        XCTAssertEqual(localizedConnectionStatusText(for: "Firewalled"), L("Connected"), "Kad/footer generic states should use localized connected wording.")
    }

    func testServerToolbarKeepsCommonActionsVisibleAndMovesRareAdministrationIntoMenu() throws {
        let source = try source("Sources/AMuleNativeRemote/ServersWindowView.swift")

        XCTAssertTrue(source.contains("Label(L2(\"Add\")"), "Adding a server is a common visible toolbar action.")
        XCTAssertTrue(source.contains("Label(L2(\"Refresh\")"), "Refreshing servers is a common visible toolbar action.")
        XCTAssertTrue(source.contains("Label(L2(\"Connect\")"), "Connecting a selected server should stay visible.")
        XCTAssertTrue(source.contains("Label(L2(\"Disconnect\")"), "Disconnecting should stay visible.")
        XCTAssertTrue(source.contains("Label(L2(\"Manage\")"), "Rare server administration should live behind a management menu.")
        XCTAssertTrue(source.contains("Menu(L2(\"Kad\"))"), "Kad start/stop/bootstrap/node updates should be grouped under the management menu.")
        XCTAssertTrue(
            source.contains("ToolbarItem(placement: .primaryAction) {\n            Menu {\n                Button {\n                    showingImportServerMetSheet = true"),
            "Importing server.met should be inside the management menu, not a peer primary toolbar button."
        )
        XCTAssertTrue(
            source.contains("Button(role: .destructive) {\n                    showShutdownConfirmation = true"),
            "Daemon shutdown should remain behind the management menu as a destructive action."
        )
    }

    func testStatsXAxisUsesElapsedHistoryLanguageInsteadOfRawSampleNumbers() throws {
        let source = try source("Sources/AMuleNativeRemote/StatsWindowView.swift")

        XCTAssertFalse(source.contains("point.index + 1"), "Stats charts should not expose one-based raw sample indexes.")
        XCTAssertFalse(source.contains("Text(\"#\\(intValue)\")"), "Stats charts should not label the x-axis as raw #sample numbers.")
        XCTAssertTrue(source.contains("statsGraphXAxisLabel"), "Stats charts should centralize elapsed/history label wording for tests and localization.")
        XCTAssertTrue(source.contains("History (oldest to newest)"), "The x-axis should describe elapsed order without daemon timestamps.")
        XCTAssertEqual(statsGraphXAxisLabel(index: 0, sampleCount: 4), L("Oldest"))
        XCTAssertEqual(statsGraphXAxisLabel(index: 3, sampleCount: 4), L("Newest"))
        XCTAssertEqual(statsGraphXAxisLabel(index: 2, sampleCount: 4), L("1 sample ago"))
        XCTAssertEqual(statsGraphXAxisLabel(index: 1, sampleCount: 4), LF("%lld samples ago", 2))

        try writeRenderedSurface(
            StatsWindowView(embeddedInMainWindow: true).environmentObject(polishPreviewModel()),
            size: CGSize(width: 900, height: 680),
            to: evidenceRoot.appendingPathComponent("stats-chart-axis.png")
        )
    }

    func testSettingsRenderRepresentativeTabsAtCurrentNarrowAndWideSizes() throws {
        let source = try source("Sources/AMuleNativeRemote/PreferencesWindowView.swift")
        XCTAssertFalse(source.contains(".frame(width: 700, height: 560)"), "Settings should not rely on fixed-only content sizing.")
        XCTAssertTrue(source.contains("minWidth:"), "Settings should define flexible minimum sizing for narrower localization cases.")
        XCTAssertTrue(source.contains("idealWidth:"), "Settings should keep a classic current-size preference window target.")
        XCTAssertTrue(source.contains("maxWidth:"), "Settings fields should have flexible upper bounds for wider settings windows.")
        XCTAssertFalse(source.contains("NavigationSplitView"), "Settings must preserve classic preference toolbar tabs, not a sidebar redesign.")

        let model = polishPreviewModel()
        let sizes: [(name: String, size: CGSize)] = [
            ("narrow", CGSize(width: 640, height: 540)),
            ("current", CGSize(width: 700, height: 560)),
            ("wide", CGSize(width: 900, height: 620))
        ]
        for tab in PreferenceTab.representativeRenderTabs {
            for size in sizes {
                try writeRenderedWindowSurface(
                    PreferencesWindowView(initialTab: tab).environmentObject(model),
                    size: size.size,
                    to: evidenceRoot.appendingPathComponent("settings-\(tab.evidenceName)-\(size.name).png")
                )
            }
        }
    }

    func testNewPolishStringsAreLocalizedAndEvidenceLogIsWritten() throws {
        let newKeys = [
            "Connection:",
            "eD2K:",
            "Kad:",
            "Connection status",
            "Connected",
            "Disconnected",
            "Connecting",
            "Unknown",
            "Connected to %@",
            "Connecting to %@",
            "Download",
            "Upload",
            "History (oldest to newest)",
            "Elapsed sample",
            "Oldest",
            "Newest",
            "1 sample ago",
            "%lld samples ago",
            "Manage",
            "Manage Servers",
            "Server Administration"
        ]
        let zhHans = try source("Resources/zh-Hans.lproj/Localizable.strings")
        let zhCN = try source("Resources/zh_CN.lproj/Localizable.strings")

        for key in newKeys {
            XCTAssertTrue(containsLocalizationKey(key, in: zhHans), "Missing zh-Hans localization for \(key)")
            XCTAssertTrue(containsLocalizationKey(key, in: zhCN), "Missing zh_CN localization for \(key)")
        }

        let log = """
        Task 5 P3 polish evidence
        main-status-footer.png: persistent footer renders Connection/eD2K/Kad text.
        stats-chart-axis.png: x-axis uses \(L("History (oldest to newest)")); labels include \(statsGraphXAxisLabel(index: 0, sampleCount: 4)), \(statsGraphXAxisLabel(index: 2, sampleCount: 4)), \(statsGraphXAxisLabel(index: 3, sampleCount: 4)).
        settings evidence: rendered representative tabs at narrow/current/wide sizes with classic preference toolbar tabs.
        """
        try FileManager.default.createDirectory(at: evidenceRoot, withIntermediateDirectories: true)
        try log.write(to: evidenceRoot.appendingPathComponent("stats-settings.log"), atomically: true, encoding: .utf8)
    }

    private func polishPreviewModel() -> AppModel {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set([
            "search",
            "download",
            "server-connect",
            "server-disconnect",
            "stats-tree",
            "stats-graphs",
            "prefs-connection-get",
            "prefs-connection-set",
            "ipfilter-update",
            "ipfilter-reload"
        ])
        let model = AppModel(bridge: bridge, credentialStorage: PlatformServiceStubs.Credentials())
        model.bridgeOps = bridge.capabilityOps
        model.status = StatusSnapshot(
            connected: true,
            ed2k: "Connected to Razorback [1.2.3.4:4661] HighID",
            kad: "Connected",
            downloadBytesPerSecond: 42_000,
            uploadBytesPerSecond: 12_000,
            queueCount: 3,
            sourcesCount: 8
        )
        model.downloads = AppModel.previewWithDownloads().downloads
        model.statsTree = BridgeStatsTreeNodePayload(
            id: 1,
            label: "Statistics",
            value: 0,
            children: [
                BridgeStatsTreeNodePayload(id: 2, label: "Download speed", value: 42, children: []),
                BridgeStatsTreeNodePayload(id: 3, label: "Upload speed", value: 12, children: [])
            ]
        )
        model.statsGraphs = BridgeStatsGraphsPayload(
            last: 3,
            samples: [
                ECStatsGraphSample(dl: 10, ul: 2, connections: 30, kad: 4),
                ECStatsGraphSample(dl: 20, ul: 3, connections: 32, kad: 5),
                ECStatsGraphSample(dl: 28, ul: 6, connections: 36, kad: 6),
                ECStatsGraphSample(dl: 42, ul: 12, connections: 40, kad: 8)
            ]
        )
        model.connectionMaxDownloadInput = "2048"
        model.connectionMaxUploadInput = "1024"
        model.connectionTCPPortInput = "4662"
        model.connectionUDPPortInput = "4672"
        model.incomingDirectoryInput = "/Users/jason/Downloads/aMule Incoming"
        model.tempDirectoryInput = "/Users/jason/Library/Application Support/aMule/Temporary Part Files"
        model.sharedDirectoriesInput = "/Users/jason/Public\n/Volumes/Media/Shared"
        model.serverUpdateURLInput = "https://upd.emule-security.org/server.met"
        model.deadServerRetriesInput = "3"
        model.ipFilterLevelInput = "127"
        model.ipFilterUpdateURLInput = "https://upd.emule-security.org/ipfilter.zip"
        model.ipFilterURLInput = model.ipFilterUpdateURLInput
        model.webServerPortInput = "4711"
        model.webServerRefreshInput = "120"
        model.webServerTemplateInput = "default"
        model.webServerEnabled = true
        model.webServerUseGzip = true
        return model
    }

    private func source(_ relativePath: String) throws -> String {
        try String(contentsOf: packageRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func mainFooterSource(in source: String) throws -> String {
        let start = try XCTUnwrap(source.range(of: "private struct MainWindowStatusFooter")?.lowerBound)
        let end = try XCTUnwrap(source.range(of: "#if DEBUG", range: start..<source.endIndex)?.lowerBound)
        return String(source[start..<end])
    }

    private func containsLocalizationKey(_ key: String, in table: String) -> Bool {
        table.contains("\"\(key)\" =")
    }
}
