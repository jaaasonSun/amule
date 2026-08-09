import XCTest
import SwiftUI
import AppKit
import AMuleECBridgeAdapter
import AMuleECClient
import SharedModels
@testable import AMuleNativeRemote

@MainActor
final class MacSearchToolbarTests: XCTestCase {
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

    func testSearchUsesNativeToolbarSearchField() throws {
        let source = try source("Sources/AMuleNativeRemote/SearchWindowView.swift")

        XCTAssertTrue(
            source.contains(".searchable(text: $model.searchQuery, placement: .toolbar, prompt: L(\"File name or keywords\"))"),
            "Search should bind AppModel.searchQuery through a native toolbar search field."
        )
        XCTAssertTrue(
            source.contains(".onSubmit(of: .search)"),
            "Submitting the native toolbar search field should start the remote search."
        )
        XCTAssertTrue(
            source.contains("model.performSearch()"),
            "Search submit should keep calling AppModel.performSearch()."
        )
        XCTAssertFalse(source.contains("SearchQueryBar("), "The content query row should be removed.")
        XCTAssertFalse(source.contains("private struct SearchQueryBar"), "SearchQueryBar should no longer be a content subview.")
        XCTAssertFalse(source.contains("Label(L(\"Search for\")"), "The old in-content search label should be gone.")
    }

    func testDownloadsToolbarSearchNetworkButtonOpensStandaloneSearchWindow() throws {
        let toolbar = try source("Sources/AMuleNativeRemote/MainToolbar.swift")
        let content = try source("Sources/AMuleNativeRemote/ContentView.swift")

        XCTAssertTrue(toolbar.contains("let showSearchNetwork: () -> Void"), "MainToolbar should receive an explicit Search Network action from the downloads shell.")
        XCTAssertTrue(toolbar.contains("showSearchNetwork()"), "The downloads toolbar Search Network button should call the provided window-opening action.")
        XCTAssertTrue(
            toolbar.contains("Label(L(\"Search Network\"), systemImage: \"magnifyingglass\")"),
            "Search Network should be a visible localized toolbar label."
        )
        XCTAssertTrue(
            content.contains("showSearchNetwork: {\n                        openWindow(id: \"search-window\")\n                        NSApp.activate(ignoringOtherApps: true)\n                    }"),
            "The downloads toolbar Search Network action should open the stable Search window ID and activate the app."
        )
        XCTAssertFalse(
            toolbarItemGroupSlices(in: toolbar).contains { group in
                (group.contains("Search Network") || group.contains("showSearchNetwork()")) &&
                (group.contains("Details") || group.contains("Show Download Details") || group.contains("showDetails()") || group.contains("info"))
            },
            "Search Network and Details/Info should not be intentionally bundled into the same ToolbarItemGroup."
        )
    }

    func testDownloadsFilterRemainsLocalAndSearchWindowKeepsRemoteSearchField() throws {
        let content = try source("Sources/AMuleNativeRemote/ContentView.swift")
        let toolbar = try source("Sources/AMuleNativeRemote/MainToolbar.swift")
        let downloads = try source("Sources/AMuleNativeRemote/DownloadsPanel.swift")
        let search = try source("Sources/AMuleNativeRemote/SearchWindowView.swift")

        XCTAssertTrue(
            downloads.contains(".searchable(text: $nameFilterQuery, placement: .toolbar, prompt: L(\"Filter Downloads\"))"),
            "Downloads should keep a local name filter rather than the remote search query."
        )
        for (name, source) in [
            ("ContentView", content),
            ("MainToolbar", toolbar),
            ("DownloadsPanel", downloads)
        ] {
            XCTAssertFalse(source.contains("model.searchQuery"), "\(name) must not bind downloads toolbar UI to the remote search query.")
        }
        XCTAssertTrue(
            search.contains(".searchable(text: $model.searchQuery, placement: .toolbar, prompt: L(\"File name or keywords\"))"),
            "The standalone Search window should retain the remote search field."
        )
    }

    func testAdvancedButtonTogglesInspector() throws {
        let source = try source("Sources/AMuleNativeRemote/SearchWindowView.swift")

        XCTAssertTrue(source.contains("showsAdvancedSearchOptions.toggle()"))
        XCTAssertTrue(source.contains("SearchInspectorPanel"), "Advanced options should still use the in-window Search inspector panel.")
        XCTAssertTrue(
            source.contains("Label(L(\"Advanced\"), systemImage: \"slider.horizontal.3\")"),
            "The toolbar toggle should be presented as Advanced search options."
        )
        XCTAssertTrue(source.contains(".help(L(\"Advanced Search\"))"))
        XCTAssertFalse(source.contains("Label(L(\"Inspector\")"), "The user-facing toolbar entry should not be named Inspector.")
        XCTAssertFalse(source.contains("L(\"Search Inspector\")"), "The Advanced control should not use Inspector wording in help text.")
    }

    func testSearchToolbarToggleKeepsStandaloneWindowSizeStable() throws {
        let collapsedSize = try laidOutContentSize(
            SearchWindowView(embeddedInMainWindow: false, showsAdvancedSearchOptions: false)
                .environmentObject(searchPreviewModel()),
            contentSize: CGSize(width: 940, height: 580)
        )
        let expandedSize = try laidOutContentSize(
            SearchWindowView(embeddedInMainWindow: false, showsAdvancedSearchOptions: true)
                .environmentObject(searchPreviewModel()),
            contentSize: CGSize(width: 940, height: 580)
        )

        XCTAssertEqual(collapsedSize.width, expandedSize.width, accuracy: 0.5)
        XCTAssertEqual(collapsedSize.height, expandedSize.height, accuracy: 0.5)
    }

    func testSearchToolbarVisibleStringsAreLocalized() throws {
        let sources = try [
            "Sources/AMuleNativeRemote/SearchWindowView.swift",
            "Sources/AMuleNativeRemote/MainToolbar.swift"
        ].map { try source($0) }
        let requiredKeys = Set(sources.flatMap(localizedKeys)).subtracting([
            "0",
            "1"
        ])

        let zhHans = try source("Resources/zh-Hans.lproj/Localizable.strings")
        let zhCN = try source("Resources/zh_CN.lproj/Localizable.strings")

        let missingZHans = requiredKeys.sorted().filter { !containsLocalizationKey($0, in: zhHans) }
        let missingZHCN = requiredKeys.sorted().filter { !containsLocalizationKey($0, in: zhCN) }

        XCTAssertTrue(missingZHans.isEmpty, "Missing zh-Hans localization keys: \(missingZHans.joined(separator: ", "))")
        XCTAssertTrue(missingZHCN.isEmpty, "Missing zh_CN localization keys: \(missingZHCN.joined(separator: ", "))")
    }

    func testDownloadsSearchNetworkToolbarStringIsLocalized() throws {
        let zhHans = try source("Resources/zh-Hans.lproj/Localizable.strings")
        let zhCN = try source("Resources/zh_CN.lproj/Localizable.strings")

        for key in ["Search Network", "Open Search Network"] {
            XCTAssertTrue(zhHans.contains("\"\(key)\" ="), "zh-Hans missing localization key: \(key)")
            XCTAssertTrue(zhCN.contains("\"\(key)\" ="), "zh_CN missing localization key: \(key)")
        }
    }

    func testSearchToolbarSurfacesRender() throws {
        let evidenceRoot = repositoryRoot(from: packageRoot)
            .appendingPathComponent(".sisyphus/evidence/task-6-search-toolbar")

        try writeRenderedSurface(
            SearchWindowView(embeddedInMainWindow: true, showsAdvancedSearchOptions: false)
                .environmentObject(searchPreviewModel()),
            size: CGSize(width: 940, height: 580),
            to: evidenceRoot.appendingPathComponent("search-toolbar-collapsed.png")
        )

        try writeRenderedSurface(
            SearchWindowView(embeddedInMainWindow: true, showsAdvancedSearchOptions: true)
                .environmentObject(searchPreviewModel()),
            size: CGSize(width: 940, height: 580),
            to: evidenceRoot.appendingPathComponent("search-toolbar-advanced-expanded.png")
        )

        try writeRenderedWindowSurface(
            SearchWindowView(embeddedInMainWindow: false, showsAdvancedSearchOptions: true)
                .environmentObject(searchPreviewModel()),
            size: CGSize(width: 940, height: 580),
            to: evidenceRoot.appendingPathComponent("search-window-toolbar.png"),
            title: "Search"
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

    private func searchPreviewModel() -> AppModel {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["search", "download"])
        let model = AppModel(bridge: bridge, credentialStorage: PlatformServiceStubs.Credentials())
        model.bridgeOps = bridge.capabilityOps
        model.searchQuery = "ubuntu"
        model.searchScope = "global"
        model.searchOptions.fileType = "Archive"
        model.searchOptions.fileExtension = "iso"
        model.searchOptions.availabilityText = "2"
        model.searchOptions.minSizeText = "1024"
        model.searchOptions.maxSizeText = ""
        model.searchOptions.filterText = "server"
        model.searchResults = [
            SearchResult(index: 1, hash: "00112233445566778899AABBCCDDEEFF", name: "Ubuntu Server.iso", sizeBytes: 1_048_576, sources: 8, completeSources: 4, statusCode: 1, status: "New", parentID: 0, alreadyHave: false),
            SearchResult(index: 2, hash: "FFEEDDCCBBAA99887766554433221100", name: "Ubuntu Desktop.iso", sizeBytes: 2_097_152, sources: 12, completeSources: 7, statusCode: 1, status: "New", parentID: 0, alreadyHave: true)
        ]
        return model
    }

    private func source(_ relativePath: String) throws -> String {
        let url = packageRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func toolbarItemGroupSlices(in source: String) -> [String] {
        var slices: [String] = []
        var searchStart = source.startIndex

        while let keywordRange = source.range(of: "ToolbarItemGroup", range: searchStart..<source.endIndex) {
            guard let openBrace = source[keywordRange.upperBound...].firstIndex(of: "{") else { break }

            var depth = 0
            var endIndex: String.Index?
            var index = openBrace

            while index < source.endIndex {
                let character = source[index]
                if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                    if depth == 0 {
                        endIndex = source.index(after: index)
                        break
                    }
                }
                index = source.index(after: index)
            }

            guard let sliceEnd = endIndex else { break }
            slices.append(String(source[keywordRange.lowerBound..<sliceEnd]))
            searchStart = sliceEnd
        }

        return slices
    }
}
