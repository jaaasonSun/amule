import XCTest

final class MacNativeNavigationTests: XCTestCase {
    func testMainWindowNavigationOwnsRemoteClientSections() throws {
        let content = try source("Sources/AMuleNativeRemote/ContentView.swift")

        for section in [
            ".downloads",
            ".search",
            ".servers",
            ".sharedFiles",
            ".uploads",
            ".categories",
            ".statistics",
            ".friends",
        ] {
            XCTAssertTrue(content.contains(section), "ContentView should expose \(section) as a main-window navigation destination.")
        }

        XCTAssertTrue(content.contains("NavigationSplitView"))
        XCTAssertTrue(content.contains(".listStyle(.sidebar)"))
    }

    func testTopLevelRemoteClientSectionsAreNotSeparateToolWindows() throws {
        let app = try source("Sources/AMuleNativeRemote/AMuleNativeRemoteApp.swift")

        for forbiddenScene in [
            #"WindowGroup("Uploads""#,
            #"WindowGroup("Shared Files""#,
            #"WindowGroup("Categories""#,
            #"WindowGroup("Friends""#,
            #"WindowGroup("Messages""#,
            #"WindowGroup("Statistics""#,
            #"WindowGroup("Preferences""#,
            #"WindowGroup("eD2k""#,
            #"WindowGroup("Search""#,
        ] {
            XCTAssertFalse(app.contains(forbiddenScene), "\(forbiddenScene) should not be modeled as a separate top-level tool window.")
        }
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
}
