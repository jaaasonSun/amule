import XCTest
import AMuleECBridgeAdapter
@testable import AMuleNativeRemote

@MainActor
final class MacSettingsToolbarStyleTests: XCTestCase {
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

    func testPreferencesUseClassicToolbarTabStyle() throws {
        let source = try source("Sources/AMuleNativeRemote/PreferencesWindowView.swift")
        let design = try String(contentsOf: packageRoot.appendingPathComponent("DESIGN.md"), encoding: .utf8)

        XCTAssertTrue(source.contains("PreferenceWindowConfigurator(selectedTab: $selectedTab)"), "Settings should install the AppKit preference toolbar bridge.")
        XCTAssertTrue(source.contains("NSToolbar(identifier: Coordinator.toolbarIdentifier)"), "Settings should build a real macOS toolbar for icon-and-label preference tabs.")
        XCTAssertTrue(source.contains("toolbarSelectableItemIdentifiers"), "Preference toolbar items should be selectable native toolbar items.")
        XCTAssertTrue(source.contains("selectedSection"), "Toolbar tab selection should drive the visible settings page.")
        XCTAssertTrue(source.contains("toolbarStyle = .preference"), "Settings window should use the classic macOS preference toolbar style.")
        XCTAssertTrue(source.contains("toolbar?.displayMode = .iconAndLabel"), "Settings toolbar should show large tappable icon-and-text tab items.")
        XCTAssertFalse(source.contains("pickerStyle(.segmented)"), "The segmented strip is not the requested classic macOS settings toolbar.")
        XCTAssertFalse(source.contains("NavigationSplitView"), "The settings window should not use the Tahoe-style sidebar settings layout.")
        XCTAssertTrue(design.contains("Preference Toolbar Tab"), "DESIGN.md should record the settings toolbar tab component contract.")
    }

    func testRenderedPreferenceTabsAreReadable() throws {
        let model = previewModel()
        let evidenceRoot = repositoryRoot(from: packageRoot)
            .appendingPathComponent(".omo/evidence/native-macos-settings-toolbar-20260709")

        for tab in PreferenceTab.representativeRenderTabs {
            try writeRenderedWindowSurface(
                PreferencesWindowView(initialTab: tab).environmentObject(model),
                size: CGSize(width: 760, height: 560),
                to: evidenceRoot.appendingPathComponent("preferences-\(tab.evidenceName).png")
            )
        }
    }

    private func previewModel() -> AppModel {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set([
            "prefs-connection-get",
            "prefs-connection-set",
            "ipfilter-update",
            "ipfilter-reload"
        ])
        let model = AppModel(bridge: bridge, credentialStorage: PlatformServiceStubs.Credentials())
        model.bridgeOps = bridge.capabilityOps
        model.connectionMaxDownloadKBps = 2_048
        model.connectionMaxUploadKBps = 1_024
        model.connectionMaxDownloadInput = "2048"
        model.connectionMaxUploadInput = "1024"
        model.connectionTCPPortInput = "4662"
        model.connectionUDPPortInput = "4672"
        model.incomingDirectoryInput = "/Users/jason/Downloads/aMule"
        model.tempDirectoryInput = "/Users/jason/Library/Application Support/aMule/Temp"
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
        let url = packageRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
