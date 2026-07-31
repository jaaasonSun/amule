import XCTest
import SwiftUI
import AppKit
import AMuleECBridgeAdapter
import AMuleECClient
import SharedModels
@testable import AMuleNativeRemote

@MainActor
final class MacUIRefinementTests: XCTestCase {
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

    func testStatisticsPageRemovesConfusingToolbarAndNetworkStatus() throws {
        let source = try source("Sources/AMuleNativeRemote/StatsWindowView.swift")

        XCTAssertFalse(source.contains("Label(L(\"Tree\")"), "Statistics toolbar should not expose a separate Tree refresh button.")
        XCTAssertFalse(source.contains("Label(L2(\"Tree\")"), "Statistics toolbar should not expose a separate Tree refresh button.")
        XCTAssertFalse(source.contains("StatsGraphControls"), "Statistics toolbar should not expose raw graph width/scale controls.")
        XCTAssertFalse(source.contains("StatsOverviewTile(title: L(\"eD2k\")"), "eD2k status belongs on Servers, not Statistics.")
        XCTAssertFalse(source.contains("StatsOverviewTile(title: L2(\"eD2k\")"), "eD2k status belongs on Servers, not Statistics.")
        XCTAssertFalse(source.contains("StatsOverviewTile(title: L(\"Kad\")"), "Kad status belongs on Servers, not Statistics.")
        XCTAssertFalse(source.contains("StatsOverviewTile(title: L2(\"Kad\")"), "Kad status belongs on Servers, not Statistics.")
        XCTAssertTrue(source.contains("StatsOverviewTile(title: L(\"Download\")"), "Statistics should keep transfer summary tiles.")
        XCTAssertTrue(source.contains("model.refreshStatsGraphs()"), "The single Statistics refresh action should still refresh graph samples.")
    }

    func testUploadsPageCanBeHiddenFromInterfaceSettings() throws {
        let content = try source("Sources/AMuleNativeRemote/ContentView.swift")
        let preferences = try source("Sources/AMuleNativeRemote/PreferencesWindowView.swift")

        XCTAssertTrue(content.contains("@AppStorage(\"amule.ui.showUploadsPage\")"))
        XCTAssertTrue(content.contains("if showUploadsPage"))
        XCTAssertTrue(content.contains("normalizedSidebarSelectionForVisibility"), "Hiding Uploads while selected should fall back to Downloads.")
        XCTAssertTrue(content.contains(".onChange(of: showUploadsPage)"))

        XCTAssertTrue(preferences.contains("@AppStorage(\"amule.ui.showUploadsPage\")"))
        XCTAssertTrue(preferences.contains("Show Uploads page"))
        XCTAssertTrue(preferences.contains(".frame(width: 700"), "Settings should use a narrower macOS preferences window.")
    }

    func testHiddenUploadsSelectionFallsBackToDownloads() {
        let normalized = ContentView.normalizedSidebarSelectionForVisibility(
            .uploads,
            showCategoriesPage: true,
            showFriendsPage: true,
            showUploadsPage: false
        )

        XCTAssertEqual(normalized, .downloads(.all))
    }

    func testAdvancedSearchDoesNotUseResizableInspector() throws {
        let source = try source("Sources/AMuleNativeRemote/SearchWindowView.swift")

        XCTAssertFalse(source.contains(".inspector(isPresented: $showsAdvancedSearchOptions)"), "Advanced search should not ask AppKit to resize the window.")
        XCTAssertFalse(source.contains(".inspectorColumnWidth"), "Advanced search should not use a native inspector column that changes window sizing.")
        XCTAssertTrue(source.contains("SearchInspectorPanel"), "Search inspector should render inside the existing content bounds.")
        XCTAssertTrue(source.contains("searchInspectorColumnWidth"), "The search inspector should have a stable in-window width.")
        XCTAssertTrue(source.contains(".frame(minWidth: 920, minHeight: 560)"), "Standalone Search should have enough stable height for both states.")
    }

    func testAdvancedSearchStatesUseSameWindowContentSize() throws {
        let collapsedSize = try laidOutContentSize(
            SearchWindowView(embeddedInMainWindow: false, showsAdvancedSearchOptions: false)
                .environmentObject(refinedPreviewModel()),
            contentSize: CGSize(width: 920, height: 560)
        )
        let expandedSize = try laidOutContentSize(
            SearchWindowView(embeddedInMainWindow: false, showsAdvancedSearchOptions: true)
                .environmentObject(refinedPreviewModel()),
            contentSize: CGSize(width: 920, height: 560)
        )

        XCTAssertEqual(collapsedSize.width, expandedSize.width, accuracy: 0.5)
        XCTAssertEqual(collapsedSize.height, expandedSize.height, accuracy: 0.5)
    }

    func testTouchedMacSurfacesUseLocalizedVisibleStrings() throws {
        let files = [
            "Sources/AMuleNativeRemote/StatsWindowView.swift",
            "Sources/AMuleNativeRemote/SearchWindowView.swift",
            "Sources/AMuleNativeRemote/ContentView.swift",
            "Sources/AMuleNativeRemote/PreferencesWindowView.swift"
        ]
        let sources = try files.map { try source($0) }

        XCTAssertFalse(sources.joined(separator: "\n").contains("private func L2"), "Touched macOS surfaces should use the shared localization helper.")
        XCTAssertFalse(sources.joined(separator: "\n").contains("private func LF2"), "Touched macOS surfaces should use the shared localization helper.")

        let keys = Set(sources.flatMap(localizedKeys))
        let ignoredKeys: Set<String> = [
            "0",
            "https://example.com/ipfilter.dat"
        ]
        let requiredKeys = keys.subtracting(ignoredKeys)
        let zhHans = try source("Resources/zh-Hans.lproj/Localizable.strings")
        let zhCN = try source("Resources/zh_CN.lproj/Localizable.strings")
        let missingZHans = requiredKeys.sorted().filter { !containsLocalizationKey($0, in: zhHans) }
        let missingZHCN = requiredKeys.sorted().filter { !containsLocalizationKey($0, in: zhCN) }

        XCTAssertTrue(missingZHans.isEmpty, "Missing zh-Hans localization keys: \(missingZHans.joined(separator: ", "))")
        XCTAssertTrue(missingZHCN.isEmpty, "Missing zh_CN localization keys: \(missingZHCN.joined(separator: ", "))")
    }

    func testRefinedMacSurfacesRender() throws {
        let model = refinedPreviewModel()
        let evidenceRoot = repositoryRoot(from: packageRoot)
            .appendingPathComponent(".omo/evidence/native-macos-ui-refine-20260709")

        try writeRenderedSurface(
            StatsWindowView(embeddedInMainWindow: true).environmentObject(model),
            size: CGSize(width: 860, height: 680),
            to: evidenceRoot.appendingPathComponent("statistics-refined.png")
        )

        try writeRenderedWindowSurface(
            PreferencesWindowView(initialTab: PreferenceTab.interface).environmentObject(model),
            size: CGSize(width: 700, height: 560),
            to: evidenceRoot.appendingPathComponent("settings-interface-refined.png")
        )

        try withHiddenUploads {
            try writeRenderedSurface(
                ContentView().environmentObject(model),
                size: CGSize(width: 960, height: 620),
                to: evidenceRoot.appendingPathComponent("sidebar-uploads-hidden.png")
            )
        }

        try writeRenderedSurface(
            SearchWindowView(embeddedInMainWindow: true, showsAdvancedSearchOptions: false).environmentObject(model),
            size: CGSize(width: 920, height: 560),
            to: evidenceRoot.appendingPathComponent("search-advanced-collapsed.png")
        )

        try writeRenderedSurface(
            SearchWindowView(embeddedInMainWindow: true, showsAdvancedSearchOptions: true).environmentObject(model),
            size: CGSize(width: 920, height: 560),
            to: evidenceRoot.appendingPathComponent("search-advanced-expanded.png")
        )
    }

    private func localizedKeys(in source: String) -> [String] {
        let pattern = #"\bLF?2?\("((?:[^"\\]|\\.)*)"\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        return regex.matches(in: source, range: range).compactMap { match in
            guard let keyRange = Range(match.range(at: 1), in: source) else { return nil }
            return String(source[keyRange])
        }
    }

    private func containsLocalizationKey(_ key: String, in table: String) -> Bool {
        table.contains("\"\(key)\" =")
    }

    private func withHiddenUploads(_ body: () throws -> Void) throws {
        let defaults = UserDefaults.standard
        let oldUploads = defaults.object(forKey: "amule.ui.showUploadsPage")
        defaults.set(false, forKey: "amule.ui.showUploadsPage")
        defer { restore(oldUploads, forKey: "amule.ui.showUploadsPage") }
        try body()
    }

    private func restore(_ value: Any?, forKey key: String) {
        let defaults = UserDefaults.standard
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private func laidOutContentSize<V: View>(_ view: V, contentSize: CGSize) throws -> CGSize {
        let hostingView = NSHostingView(rootView: view)
        hostingView.appearance = NSAppearance(named: .aqua)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = hostingView
        window.setContentSize(contentSize)
        window.layoutIfNeeded()
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        window.layoutIfNeeded()

        guard let actualSize = window.contentView?.bounds.size else {
            XCTFail("Expected window content view to be installed.")
            return .zero
        }
        return actualSize
    }

    private func refinedPreviewModel() -> AppModel {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set([
            "search",
            "download",
            "shared-files",
            "uploads",
            "stats-tree",
            "stats-graphs",
            "prefs-connection-get",
            "prefs-connection-set"
        ])
        let model = AppModel(bridge: bridge, credentialStorage: PlatformServiceStubs.Credentials())
        model.bridgeOps = bridge.capabilityOps
        model.searchQuery = "ubuntu"
        model.searchResults = [
            SearchResult(index: 1, hash: "00112233445566778899AABBCCDDEEFF", name: "Ubuntu.iso", sizeBytes: 1_048_576, sources: 8, completeSources: 4, statusCode: 1, status: "New", parentID: 0, alreadyHave: false)
        ]
        model.uploads = [
            BridgeUploadPayload(clientID: 7, clientName: "peer-a", userIP: "10.0.0.7", userPort: 4662, serverIP: "1.2.3.4", serverPort: 4661, serverName: "ExampleServer", speedUp: 12_800, xferUp: 131_072, xferDown: 65_536, uploadFile: 42)
        ]
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
        model.status = StatusSnapshot(
            connected: true,
            ed2k: "Connected HighID",
            kad: "Connected",
            downloadBytesPerSecond: 42_000,
            uploadBytesPerSecond: 12_000,
            queueCount: 3,
            sourcesCount: 8
        )
        return model
    }

    private func source(_ relativePath: String) throws -> String {
        let url = packageRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
