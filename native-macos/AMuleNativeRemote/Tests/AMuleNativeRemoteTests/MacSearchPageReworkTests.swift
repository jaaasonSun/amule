import XCTest
import SwiftUI
import AppKit
import AMuleECBridgeAdapter
import AMuleECClient
import SharedModels
@testable import AMuleNativeRemote

@MainActor
final class MacSearchPageReworkTests: XCTestCase {
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

    func testSearchInspectorSeparatesCriteriaFromResultFilters() throws {
        let source = try source("Sources/AMuleNativeRemote/SearchWindowView.swift")

        XCTAssertTrue(source.contains("SearchInspectorPanel"), "Search should have a named inspector panel, not a generic Advanced panel.")
        XCTAssertTrue(source.contains("SearchCriteriaSection"), "Pre-search controls should live in a dedicated Criteria section.")
        XCTAssertTrue(source.contains("SearchResultsFilterSection"), "Post-search filters should live in a dedicated Results section.")
        XCTAssertTrue(source.contains("Text(L(\"Criteria\"))"), "The user-visible inspector should label pre-search criteria.")
        XCTAssertTrue(source.contains("Text(L(\"Results\"))"), "The user-visible inspector should label post-search result controls.")
        XCTAssertTrue(source.contains("Picker(L(\"Search Scope\")"), "Search scope affects the next search and belongs with Criteria.")
        XCTAssertFalse(source.contains("SearchScopePicker("), "Search scope should not be a separate toolbar menu after the lifecycle split.")
        XCTAssertFalse(source.contains("SearchAdvancedPanel"), "The mixed Advanced panel should be replaced by lifecycle-specific inspector content.")
    }

    func testSearchInspectorUsesNativeGroupedControls() throws {
        let source = try source("Sources/AMuleNativeRemote/SearchWindowView.swift")

        XCTAssertTrue(source.contains("Form {"), "The inspector should use native SwiftUI grouped form controls.")
        XCTAssertTrue(source.contains(".formStyle(.grouped)"), "The inspector should render like a native grouped macOS control surface.")
        XCTAssertTrue(source.contains("LabeledContent(L(\"Type\")"), "Criteria rows should use native label/value alignment.")
        XCTAssertTrue(source.contains("TextField(L(\"Visible Results\")"), "Result filtering should keep a native text field.")
        XCTAssertTrue(source.contains("SearchInspectorSummary"), "The inspector should expose result counts and selected state as post-search information.")
    }

    func testSearchInspectorToggleKeepsStandaloneWindowSizeStable() throws {
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

    func testSearchReworkVisibleStringsAreLocalized() throws {
        let searchSource = try source("Sources/AMuleNativeRemote/SearchWindowView.swift")
        let requiredKeys = Set(localizedKeys(in: searchSource)).subtracting([
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

    func testSearchReworkSurfacesRender() throws {
        let evidenceRoot = repositoryRoot(from: packageRoot)
            .appendingPathComponent(".omo/evidence/search-page-rework-20260709")

        try writeRenderedSurface(
            SearchWindowView(embeddedInMainWindow: true, showsAdvancedSearchOptions: false)
                .environmentObject(searchPreviewModel()),
            size: CGSize(width: 940, height: 580),
            to: evidenceRoot.appendingPathComponent("search-inspector-collapsed.png")
        )

        try writeRenderedSurface(
            SearchWindowView(embeddedInMainWindow: true, showsAdvancedSearchOptions: true)
                .environmentObject(searchPreviewModel()),
            size: CGSize(width: 940, height: 580),
            to: evidenceRoot.appendingPathComponent("search-inspector-expanded.png")
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
}
