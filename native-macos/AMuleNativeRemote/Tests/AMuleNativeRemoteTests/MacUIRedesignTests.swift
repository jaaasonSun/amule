import XCTest
import AMuleECBridgeAdapter
import AMuleECClient
import SharedModels
@testable import AMuleNativeRemote

@MainActor
final class MacUIRedesignTests: XCTestCase {
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

    func testSearchUsesNamedQueryRowAndAdvancedInspector() throws {
        let source = try source("Sources/AMuleNativeRemote/SearchWindowView.swift")

        XCTAssertTrue(
            source.contains(".searchable(text: $model.searchQuery, placement: .toolbar"),
            "Search should expose the remote-search query as a native toolbar search field."
        )
        XCTAssertTrue(source.contains("SearchInspectorPanel"), "Search inspector should stay inside the search window content.")
        XCTAssertFalse(source.contains(".inspector(isPresented: $showsAdvancedSearchOptions)"), "Advanced search should not resize the window through a native inspector.")
        XCTAssertFalse(source.contains("SearchQueryBar"), "Search should no longer reserve a content row for the query field.")
        XCTAssertFalse(source.contains("DisclosureGroup(isExpanded: $showsAdvancedSearchOptions)"), "Advanced search should not be a content disclosure grid.")
    }

    func testPreferencesUseTabbedSettingsAndOptionalWindowCommands() throws {
        let preferences = try source("Sources/AMuleNativeRemote/PreferencesWindowView.swift")
        let content = try source("Sources/AMuleNativeRemote/ContentView.swift")
        let app = try source("Sources/AMuleNativeRemote/AMuleNativeRemoteApp.swift")

        XCTAssertTrue(preferences.contains("PreferenceTab"), "Settings should use a conventional macOS tabbed settings layout.")
        XCTAssertTrue(preferences.contains("PreferenceWindowConfigurator(selectedTab: $selectedTab)"), "Settings should configure the preferences window toolbar style.")
        XCTAssertTrue(preferences.contains("NSToolbar(identifier: Coordinator.toolbarIdentifier)"), "Settings tabs should use native macOS toolbar items.")
        XCTAssertFalse(preferences.contains("pickerStyle(.segmented)"), "Settings should not use a segmented strip for preference tabs.")
        XCTAssertTrue(preferences.contains("Interface"), "Settings should expose Interface preferences for optional pages.")
        XCTAssertFalse(preferences.contains("NavigationSplitView"), "Settings should not use a sidebar split-view layout.")

        XCTAssertTrue(content.contains("@AppStorage(\"amule.ui.showCategoriesPage\")"))
        XCTAssertTrue(content.contains("@AppStorage(\"amule.ui.showFriendsPage\")"))
        XCTAssertTrue(content.contains("@AppStorage(\"amule.ui.showUploadsPage\")"))
        for forbidden in ["NavigationSplitView", ".listStyle(.sidebar)", "SidebarSelection", "normalizeSidebarSelectionForVisibleSections"] {
            XCTAssertFalse(content.contains(forbidden), "The main downloads shell should not depend on sidebar navigation state: \(forbidden)")
        }

        for gate in ["showUploadsPage", "showCategoriesPage", "showFriendsPage"] {
            XCTAssertTrue(app.contains(gate), "Optional section access should be gated in menu/command definitions using \(gate).")
        }

        for command in [
            #"openWindow(id: "uploads-window")"#,
            #"openWindow(id: "categories-window")"#,
            #"openWindow(id: "friends-window")"#,
        ] {
            XCTAssertTrue(app.contains(command), "Optional page commands should open dedicated windows: \(command)")
        }

        XCTAssertFalse(app.contains("SidebarCommands()"), "The command list should not expose the old sidebar commands block.")
    }

    func testPageActionsMoveToToolbarsAndStatsUsesNativeLayout() throws {
        let sharedFiles = try source("Sources/AMuleNativeRemote/SharedFilesWindowView.swift")
        let uploads = try source("Sources/AMuleNativeRemote/UploadsWindowView.swift")
        let stats = try source("Sources/AMuleNativeRemote/StatsWindowView.swift")

        XCTAssertTrue(sharedFiles.contains(".toolbar"), "Shared Files refresh/reload actions should live in the toolbar.")
        XCTAssertTrue(sharedFiles.contains("ToolbarItemGroup"))
        XCTAssertFalse(sharedFiles.contains("Button(\"Reload\")"), "Shared Files should not keep its reload button in a content strip.")

        XCTAssertTrue(uploads.contains(".toolbar"), "Uploads refresh should live in the toolbar.")
        XCTAssertTrue(uploads.contains("ToolbarItem"))

        XCTAssertTrue(stats.contains("StatsOverviewGrid"), "Statistics should present a native summary grid.")
        XCTAssertFalse(stats.contains("StatsGraphControls"), "Statistics should not expose raw graph width/scale controls.")
        XCTAssertTrue(stats.contains(".toolbar"), "Statistics refresh actions should live in the toolbar.")
    }

    func testRedesignedMacSurfacesRender() throws {
        let model = redesignedPreviewModel()
        let evidenceRoot = repositoryRoot(from: packageRoot)
            .appendingPathComponent(".sisyphus/evidence/task-6-mac-ui-redesign")

        try writeRenderedWindowSurface(
            SearchWindowView(embeddedInMainWindow: false, showsAdvancedSearchOptions: true).environmentObject(model),
            size: CGSize(width: 920, height: 560),
            to: evidenceRoot.appendingPathComponent("search-window-redesign.png"),
            title: "Search"
        )

        try writeRenderedSurface(
            PreferencesWindowView().environmentObject(model),
            size: CGSize(width: 700, height: 560),
            to: evidenceRoot.appendingPathComponent("preferences-tabs.png")
        )

        try withHiddenOptionalPages {
            try writeRenderedSurface(
                ContentView().environmentObject(model),
                size: CGSize(width: 1040, height: 620),
                to: evidenceRoot.appendingPathComponent("downloads-window-sidebar-free.png")
            )
        }

        try writeRenderedWindowSurface(
            ServersWindowView(embeddedInMainWindow: false).environmentObject(model),
            size: CGSize(width: 1040, height: 620),
            to: evidenceRoot.appendingPathComponent("servers-window-toolbar.png"),
            title: "Servers"
        )

        try writeRenderedSurface(
            SharedFilesWindowView(embeddedInMainWindow: true).environmentObject(model),
            size: CGSize(width: 780, height: 520),
            to: evidenceRoot.appendingPathComponent("shared-files-toolbar.png")
        )

        try writeRenderedSurface(
            UploadsWindowView(embeddedInMainWindow: true).environmentObject(model),
            size: CGSize(width: 780, height: 520),
            to: evidenceRoot.appendingPathComponent("uploads-toolbar.png")
        )

        try writeRenderedWindowSurface(
            StatsWindowView(embeddedInMainWindow: false).environmentObject(model),
            size: CGSize(width: 860, height: 760),
            to: evidenceRoot.appendingPathComponent("statistics-window-native.png"),
            title: "Statistics"
        )
    }

    private func withHiddenOptionalPages(_ body: () throws -> Void) throws {
        let defaults = UserDefaults.standard
        let oldCategories = defaults.object(forKey: "amule.ui.showCategoriesPage")
        let oldFriends = defaults.object(forKey: "amule.ui.showFriendsPage")
        let oldUploads = defaults.object(forKey: "amule.ui.showUploadsPage")
        defaults.set(false, forKey: "amule.ui.showCategoriesPage")
        defaults.set(false, forKey: "amule.ui.showFriendsPage")
        defaults.set(false, forKey: "amule.ui.showUploadsPage")
        defer {
            restore(oldCategories, forKey: "amule.ui.showCategoriesPage")
            restore(oldFriends, forKey: "amule.ui.showFriendsPage")
            restore(oldUploads, forKey: "amule.ui.showUploadsPage")
        }
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

    private func redesignedPreviewModel() -> AppModel {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set([
            "search",
            "download",
            "servers",
            "server-connect",
            "server-disconnect",
            "shared-files",
            "shared-files-reload",
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
        model.servers = [
            ServerItem(id: 1, name: "Razorback", description: "HighID test server", version: "17", address: "1.2.3.4:4661", ip: "1.2.3.4", port: 4661, users: 10_240, maxUsers: 20_000, files: 1_200_000, ping: 40, failed: 0, priority: 2, isStatic: true),
            ServerItem(id: 2, name: "ExampleServer", description: "", version: "", address: "5.45.85.226:6584", ip: "5.45.85.226", port: 6584, users: 120, maxUsers: 0, files: 8_240, ping: 22, failed: 0, priority: 0, isStatic: false)
        ]
        model.sharedFiles = [
            BridgeSharedFilePayload(hash: "00112233445566778899AABBCCDDEEFF", name: "Ubuntu.iso", path: "/Incoming/Ubuntu.iso", size: 1_048_576, ed2kLink: "ed2k://|file|Ubuntu.iso|1048576|00112233445566778899AABBCCDDEEFF|/", priority: 5, requests: 2, requestsAll: 10, accepts: 1, acceptsAll: 8, xferred: 512, xferredAll: 2048, onQueue: 3, completeSources: 4, completeSourcesLow: 2, completeSourcesHigh: 6, comment: "Verified", rating: 4)
        ]
        model.uploads = [
            BridgeUploadPayload(clientID: 7, clientName: "peer-a", userIP: "10.0.0.7", userPort: 4662, serverIP: "1.2.3.4", serverPort: 4661, serverName: "ExampleServer", speedUp: 12_800, xferUp: 131_072, xferDown: 65_536, uploadFile: 42)
        ]
        model.categories = [
            BridgeCategoryPayload(id: 1, title: "Linux", path: "/Incoming", comment: "", color: 0, priority: 5)
        ]
        model.friends = [
            BridgeFriendPayload(id: 1, name: "peer-a", hash: "00112233445566778899AABBCCDDEEFF", ip: "10.0.0.7", port: 4662, client: "aMule 2.3.3", friendSlot: false)
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
