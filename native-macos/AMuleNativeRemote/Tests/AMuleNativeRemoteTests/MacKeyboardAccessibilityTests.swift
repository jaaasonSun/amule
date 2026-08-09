import XCTest

final class MacKeyboardAccessibilityTests: XCTestCase {
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

    func testPrimaryActionsHaveKeyboardOrMenuAccess() throws {
        let app = try source("Sources/AMuleNativeRemote/AMuleNativeRemoteApp.swift")
        let downloads = try source("Sources/AMuleNativeRemote/DownloadsPanel.swift")
        let search = try source("Sources/AMuleNativeRemote/SearchWindowView.swift")
        let servers = try source("Sources/AMuleNativeRemote/ServersWindowView.swift")
        let sharedFiles = try source("Sources/AMuleNativeRemote/SharedFilesWindowView.swift")

        for action in [
            "Add Links…",
            "Refresh Status",
            "Connection Settings…",
            "Show Details",
            "Pause Selected Downloads",
            "Resume Selected Downloads",
            "Remove Selected Downloads"
        ] {
            XCTAssertTrue(app.contains(action), "App commands should expose \(action).")
        }

        XCTAssertTrue(app.contains(".keyboardShortcut(.defaultAction)"), "Return should open selected download details.")
        XCTAssertTrue(app.contains(".keyboardShortcut(.delete)"), "Delete should reach selected download removal.")
        XCTAssertTrue(downloads.contains("downloadContextMenu"), "Download context menu actions must remain available.")

        XCTAssertTrue(search.contains("Label(L(\"Download\"), systemImage: \"arrow.down.circle\")"), "Search Download should remain visible.")
        XCTAssertTrue(search.contains("Label(L(\"Stop\"), systemImage: \"stop.fill\")"), "Search Stop should remain visible.")
        XCTAssertTrue(search.contains(".keyboardShortcut(.defaultAction)"), "Return should download selected search results.")
        XCTAssertTrue(search.contains(".keyboardShortcut(.cancelAction)"), "Escape should stop or dismiss Search context.")

        for action in ["Add", "Refresh", "Connect", "Disconnect"] {
            XCTAssertTrue(servers.contains("L2(\"\(action)\")"), "Servers should expose \(action).")
        }
        XCTAssertTrue(servers.contains(".keyboardShortcut(.defaultAction)"), "Return should connect the selected server.")
        XCTAssertTrue(servers.contains(".keyboardShortcut(.cancelAction)"), "Escape should dismiss the server sheet.")

        for action in [
            "Refresh Shared Files",
            "Reload Shared Files",
            "Edit Comment and Rating",
            "Copy eD2k Link",
            "Priority"
        ] {
            XCTAssertTrue(sharedFiles.contains("L(\"\(action)\")"), "Shared Files should expose \(action).")
        }
        XCTAssertTrue(sharedFiles.contains(".keyboardShortcut(.defaultAction)"), "Return should apply the Shared Files edit action.")
        XCTAssertTrue(sharedFiles.contains(".keyboardShortcut(.cancelAction)"), "Escape should dismiss the Shared Files sheet.")
    }

    func testStatusAndProgressViewsExposeAccessibilityText() throws {
        let toolbar = try source("Sources/AMuleNativeRemote/MainToolbar.swift")
        let downloads = try source("Sources/AMuleNativeRemote/DownloadsPanel.swift")
        let search = try source("Sources/AMuleNativeRemote/SearchWindowView.swift")
        let servers = try source("Sources/AMuleNativeRemote/ServersWindowView.swift")
        let sharedFiles = try source("Sources/AMuleNativeRemote/SharedFilesWindowView.swift")
        let content = try source("Sources/AMuleNativeRemote/ContentView.swift")
        let connection = try source("Packages/Shared/Sources/SharedViews/SharedConnectionIndicator.swift")

        XCTAssertTrue(toolbar.contains(".accessibilityLabel(L(\"Show Download Details\"))"), "Icon-only toolbar controls need explicit labels.")
        XCTAssertTrue(toolbar.contains(".accessibilityHint(L(\"Show Download Details\"))"), "Details needs a VoiceOver hint.")

        XCTAssertTrue(downloads.contains(".accessibilityLabel(L(\"Download status\"))"), "Download status icons need a localized label.")
        XCTAssertTrue(downloads.contains(".accessibilityLabel(L(\"Download progress\"))"), "Download progress needs a localized label.")
        XCTAssertTrue(downloads.contains(".accessibilityValue(LF(\"Progress: %@\", item.progressText))"), "Download progress needs a localized value.")
        XCTAssertTrue(downloads.contains(".accessibilityHint(L(\"Use the context menu for download actions.\"))"), "Download rows need an action hint.")

        XCTAssertTrue(search.contains(".accessibilityLabel(L(\"Search state\"))"), "Search state surfaces need explicit labels.")
        XCTAssertTrue(search.contains(".accessibilityValue("), "Search state surfaces need explicit values.")
        XCTAssertTrue(search.contains(".accessibilityHint("), "Search state surfaces need explicit hints.")
        XCTAssertTrue(search.contains(".accessibilityLabel(L(\"Search error\"))"), "Search errors need an explicit label.")
        XCTAssertTrue(search.contains(".onExitCommand"), "Escape should dismiss the Search error context.")
        XCTAssertTrue(content.contains(".accessibilityValue(message)"), "Global errors need their current message as a value.")
        XCTAssertTrue(content.contains(".accessibilityHint(L(\"Dismiss\"))"), "Global errors need a dismissal hint.")
        XCTAssertTrue(content.contains(".onExitCommand(perform: dismiss)"), "Escape should dismiss the global error context.")

        let footer = mainWindowStatusFooterSource(in: content)
        XCTAssertFalse(footer.contains(".accessibilityElement(children: .combine)"), "The main footer must not hide individual controls behind one combined accessibility element.")
        XCTAssertEqual(occurrenceCount(of: "FooterControlButton(", in: footer), 5, "The main footer should expose Connection, eD2K, Kad, Download speed, and Upload speed as separate controls.")
        XCTAssertTrue(content.contains("openConnectionSettings: {\n                    model.requestConnectionSheet()"), "The Connection footer control should open the existing connection sheet.")
        XCTAssertTrue(content.contains("openED2KServersWindow: {\n                    openWindow(id: \"servers-window\")"), "The eD2K footer control should open the Servers window.")
        XCTAssertTrue(content.contains("openKadServersWindow: {\n                    openWindow(id: \"servers-window\")"), "The Kad footer control should open the Servers window.")
        XCTAssertTrue(content.contains("openDownloadStatisticsWindow: {\n                    openWindow(id: \"statistics-window\")"), "The Download speed footer control should open the Statistics window.")
        XCTAssertTrue(content.contains("openUploadStatisticsWindow: {\n                    openWindow(id: \"statistics-window\")"), "The Upload speed footer control should open the Statistics window.")
        XCTAssertGreaterThanOrEqual(occurrenceCount(of: "NSApp.activate(ignoringOtherApps: true)", in: content), 5, "Footer window-opening controls should activate the app after opening windows.")
        XCTAssertTrue(footer.contains(".accessibilityLabel(accessibilityLabel)"), "Footer controls need explicit accessibility labels.")
        XCTAssertTrue(footer.contains(".accessibilityValue(normalizedAccessibilityValue)"), "Footer controls need explicit accessibility values.")
        XCTAssertTrue(footer.contains(".accessibilityHint(accessibilityHint)"), "Footer controls need explicit accessibility hints.")
        XCTAssertTrue(footer.contains("accessibilityLabel: L(\"Open Connection Settings\")"), "Connection footer control needs an action label.")
        XCTAssertEqual(occurrenceCount(of: "accessibilityLabel: L(\"Open Servers\")", in: footer), 2, "eD2K and Kad footer controls should each expose Servers-window labels.")
        XCTAssertEqual(occurrenceCount(of: "accessibilityLabel: L(\"Open Statistics\")", in: footer), 2, "Download and Upload footer controls should each expose Statistics-window labels.")
        XCTAssertTrue(footer.contains("accessibilityValue: sessionStatusText"), "Connection footer value should expose the current connection state.")
        XCTAssertTrue(footer.contains("accessibilityValue: ed2kStatusText"), "eD2K footer value should expose the current eD2K state.")
        XCTAssertTrue(footer.contains("accessibilityValue: kadStatusText"), "Kad footer value should expose the current Kad state.")
        XCTAssertTrue(footer.contains("accessibilityValue: status.downloadSpeed"), "Download footer value should expose the current download speed.")
        XCTAssertTrue(footer.contains("accessibilityValue: status.uploadSpeed"), "Upload footer value should expose the current upload speed.")

        XCTAssertTrue(servers.contains(".accessibilityLabel(L(\"eD2k connection status\"))"), "Server connection status needs an explicit label.")
        XCTAssertTrue(servers.contains(".accessibilityValue(ed2kStatusText)"), "Server connection status needs its current value.")
        XCTAssertTrue(servers.contains(".accessibilityHint(L(\"Shows the current eD2k server connection.\"))"), "Server connection status needs a hint.")

        XCTAssertTrue(sharedFiles.contains(".accessibilityLabel(L(\"Shared Files\"))"), "Shared Files tables need an explicit label.")
        XCTAssertTrue(sharedFiles.contains(".accessibilityHint(L(\"Use the context menu for shared file actions.\"))"), "Shared file rows need an action hint.")
        XCTAssertTrue(sharedFiles.contains(".accessibilityLabel(L(\"Shared Files empty state\"))"), "Shared Files empty and filtered-empty states need labels.")

        XCTAssertTrue(connection.contains(".accessibilityElement(children: .ignore)"), "Connection indicators must combine icon-only content for VoiceOver.")
        XCTAssertTrue(connection.contains(".accessibilityLabel(ConnectionStateLocalizer.localizedText(for: state))"), "Connection indicators need localized state labels.")
        XCTAssertTrue(connection.contains(".accessibilityValue(ConnectionStateLocalizer.localizedText(for: state))"), "Connection indicators need explicit state values.")
    }

    func testReturnDeleteEscapeAndContextMenusRemainExplicit() throws {
        let app = try source("Sources/AMuleNativeRemote/AMuleNativeRemoteApp.swift")
        let content = try source("Sources/AMuleNativeRemote/ContentView.swift")
        let downloads = try source("Sources/AMuleNativeRemote/DownloadsPanel.swift")
        let search = try source("Sources/AMuleNativeRemote/SearchWindowView.swift")
        let servers = try source("Sources/AMuleNativeRemote/ServersWindowView.swift")
        let sharedFiles = try source("Sources/AMuleNativeRemote/SharedFilesWindowView.swift")

        XCTAssertTrue(app.contains(".keyboardShortcut(.defaultAction)"), "The Details command should use Return.")
        XCTAssertTrue(app.contains(".keyboardShortcut(.delete)"), "Selected download removal should use Delete.")
        XCTAssertTrue(content.contains("showRemoveConfirmation"), "Selected download removal must keep confirmation.")
        XCTAssertTrue(search.contains(".keyboardShortcut(.cancelAction)"), "Search should keep Escape as a cancel path.")
        XCTAssertTrue(servers.contains(".keyboardShortcut(.cancelAction)"), "Server sheets should keep Escape as a cancel path.")
        XCTAssertTrue(sharedFiles.contains(".keyboardShortcut(.cancelAction)"), "Shared Files editing should keep Escape as a cancel path.")

        XCTAssertTrue(downloads.contains(".contextMenu { downloadContextMenu(item) }"), "Download context menus must remain.")
        XCTAssertTrue(servers.contains("serverContextMenu"), "Server context menus must remain.")
        XCTAssertTrue(sharedFiles.contains(".contextMenu { sharedFileContextMenu(row.file) }"), "Shared Files context menus must remain.")
    }

    func testNewAccessibilityStringsAreLocalizedInBothChineseTables() throws {
        let zhHans = try source("Resources/zh-Hans.lproj/Localizable.strings")
        let zhCN = try source("Resources/zh_CN.lproj/Localizable.strings")
        let keys = [
            "Search Network",
            "Open Search Network",
            "Download Status Filter",
            "All",
            "Downloading",
            "Pending",
            "Paused",
            "Completed",
            "Download status",
            "Download progress",
            "Use the context menu for download actions.",
            "Search state",
            "Search progress",
            "Search ready",
            "Searching remote index",
            "No search results",
            "Search error",
            "Use Retry to search again or Dismiss to close this error.",
            "eD2k connection status",
            "Shows the current eD2k server connection.",
            "Shared Files empty state",
            "Use the context menu for shared file actions.",
            "Open Connection Settings",
            "Opens the connection settings sheet.",
            "Open Servers",
            "Opens the Servers window.",
            "Open Statistics",
            "Opens the Statistics window."
        ]

        for key in keys {
            XCTAssertTrue(zhHans.contains("\"\(key)\" ="), "zh-Hans missing localization key: \(key)")
            XCTAssertTrue(zhCN.contains("\"\(key)\" ="), "zh_CN missing localization key: \(key)")
        }
    }

    private func source(_ relativePath: String) throws -> String {
        try String(
            contentsOf: packageRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    private func mainWindowStatusFooterSource(in source: String) -> String {
        guard let start = source.range(of: "private struct MainWindowStatusFooter"),
              let end = source.range(of: "#if DEBUG", range: start.upperBound..<source.endIndex) else {
            XCTFail("Could not locate MainWindowStatusFooter source.")
            return ""
        }
        return String(source[start.lowerBound..<end.lowerBound])
    }

    private func occurrenceCount(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }
}
