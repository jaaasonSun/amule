import XCTest

final class MacNativeNavigationTests: XCTestCase {
    func testMainWindowIsDownloadsOnlyAndRejectsSidebarNavigationContract() throws {
        let content = try source("Sources/AMuleNativeRemote/ContentView.swift")

        for required in [
            "DownloadsPanel(",
            "MainWindowStatusFooter(",
            ".alert(\"aMule Remote Error\", isPresented: errorAlertBinding)",
        ] {
            XCTAssertTrue(content.contains(required), "ContentView should keep \(required) in the downloads-first main window shell.")
        }

        XCTAssertFalse(content.contains("GlobalErrorBanner("), "ContentView should present global errors with a native alert, not the old footer-adjacent banner.")

        for forbidden in [
            "NavigationSplitView",
            ".listStyle(.sidebar)",
            "SidebarSelection",
            "sidebarSelectionBinding",
            "normalizeSidebarSelectionForVisibleSections",
        ] {
            XCTAssertFalse(content.contains(forbidden), "ContentView should not use the old sidebar navigation contract: \(forbidden)")
        }
    }

    func testRemoteClientSectionsOpenStandaloneWindowsAndMenuGatedOptionalCommands() throws {
        let app = try source("Sources/AMuleNativeRemote/AMuleNativeRemoteApp.swift")

        for requiredScene in [
            #"Window("Search", id: "search-window")"#,
            #"Window("Servers""#,
            #"Window("Shared Files""#,
            #"Window("Statistics""#,
        ] {
            XCTAssertTrue(app.contains(requiredScene), "\(requiredScene) should be declared as a standalone window scene.")
        }

        for optionalWindow in [
            (gate: "showUploadsPage", title: "Uploads", id: "uploads-window", view: "UploadsWindowView"),
            (gate: "showCategoriesPage", title: "Categories", id: "categories-window", view: "CategoriesWindowView"),
            (gate: "showFriendsPage", title: "Friends", id: "friends-window", view: "FriendsWindowView"),
        ] {
            let sceneSource = try XCTUnwrap(windowSceneBlock(title: optionalWindow.title, in: app))
            XCTAssertTrue(sceneSource.contains(#"Window("\#(optionalWindow.title)", id: "\#(optionalWindow.id)")"#), "Optional \(optionalWindow.title) should preserve the stable \(optionalWindow.id) ID when enabled.")
            XCTAssertTrue(sceneSource.contains("\(optionalWindow.view)(embeddedInMainWindow: false)"), "Optional \(optionalWindow.title) should keep the standalone content when enabled.")
            XCTAssertTrue(sceneSource.contains(".commandsRemoved()"), "Optional \(optionalWindow.title) should be removed from SwiftUI's automatic Window scene list; the gated custom command is the visible access point when enabled.")

            let commandSnippet = """
                        if \(optionalWindow.gate) {
                            Button(L("\(optionalWindow.title)")) {
                                openWindow(id: "\(optionalWindow.id)")
            """
            XCTAssertTrue(
                app.contains(commandSnippet),
                "Optional \(optionalWindow.title) custom command should stay gated and open the stable \(optionalWindow.id) ID when enabled."
            )
        }

        XCTAssertTrue(app.contains(#"Button(L("Search Network"))"#), "Search Network should remain a visible localized command.")
        XCTAssertTrue(app.contains(#"openWindow(id: "search-window")"#), "Search Network commands should open the stable Search window ID.")
        XCTAssertTrue(app.contains("NSApp.activate(ignoringOtherApps: true)"), "Window-opening commands should activate the app.")
        XCTAssertFalse(app.contains("SidebarCommands()"), "The macOS command set should not keep the old sidebar command block.")
    }

    func testPreferencesUseNativeSettingsScene() throws {
        let app = try source("Sources/AMuleNativeRemote/AMuleNativeRemoteApp.swift")

        XCTAssertTrue(app.contains("Settings {"))
        XCTAssertTrue(app.contains("PreferencesWindowView()"))
        XCTAssertFalse(app.contains(#"Button("Preferences")"#))
        XCTAssertFalse(app.contains(#"openWindow(id: "preferences-window")"#))
    }

    private func source(_ relativePath: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let packageRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = packageRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func windowSceneBlock(title: String, in source: String) -> String? {
        guard let start = source.range(of: "Window(\"\(title)\"") else {
            return nil
        }
        let rest = source[start.upperBound...]
        let end = rest.range(of: "\n\n        Window")?.lowerBound
            ?? rest.range(of: "\n\n        Settings")?.lowerBound
            ?? source.endIndex
        return String(source[start.lowerBound..<end])
    }
}
