import XCTest
import SwiftUI
import AppKit
import AMuleECBridgeAdapter
import SharedModels
@testable import AMuleNativeRemote

@MainActor
final class MacUIUXStateTests: XCTestCase {
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

    func testSearchInitialStateRendersCompactGuidance() throws {
        let searchSource = try source("Sources/AMuleNativeRemote/SearchWindowView.swift")

        XCTAssertTrue(searchSource.contains("SearchStateOverlay"), "Search should layer a compact state view over the empty outline area.")
        XCTAssertTrue(searchSource.contains("EmptyStateView("), "Search should reuse the shared compact empty-state vocabulary.")
        XCTAssertTrue(searchSource.contains("L(\"Search by file name\")"), "The no-query state should provide localized, compact guidance.")
        XCTAssertTrue(searchSource.contains("L(\"Enter a query in the toolbar search field.\")"), "The no-query state should explain where to start without a large marketing panel.")

        try writeRenderedSurface(
            SearchWindowView(embeddedInMainWindow: true)
                .environmentObject(searchModel(state: .initial)),
            size: CGSize(width: 920, height: 560),
            to: evidenceRoot.appendingPathComponent("search-initial.png")
        )
    }

    func testSearchLoadingAndNoResultsStatesAreExplicitAndCompact() throws {
        let searchSource = try source("Sources/AMuleNativeRemote/SearchWindowView.swift")

        XCTAssertTrue(searchSource.contains("ProgressView()"), "The active search state should show native loading feedback.")
        XCTAssertTrue(searchSource.contains("L(\"Searching remote index…\")"), "Loading copy should identify that Search is actively working.")
        XCTAssertTrue(searchSource.contains("L(\"No search results\")"), "Completed empty searches should not look like the initial no-query state.")
        XCTAssertTrue(searchSource.contains("L(\"Try a broader query or fewer constraints.\")"), "No-results copy should tell the user what to adjust.")

        try writeRenderedSurface(
            SearchWindowView(embeddedInMainWindow: true)
                .environmentObject(searchModel(state: .loading)),
            size: CGSize(width: 920, height: 560),
            to: evidenceRoot.appendingPathComponent("search-loading.png")
        )

        try writeRenderedSurface(
            SearchWindowView(embeddedInMainWindow: true)
                .environmentObject(searchModel(state: .noResults)),
            size: CGSize(width: 920, height: 560),
            to: evidenceRoot.appendingPathComponent("search-no-results.png")
        )
    }

    func testSearchErrorBannerIsDismissibleAndRetryable() throws {
        let searchSource = try source("Sources/AMuleNativeRemote/SearchWindowView.swift")

        XCTAssertTrue(searchSource.contains("SearchErrorBanner"), "Search failures should have a contextual in-pane banner, not only the global footer.")
        XCTAssertTrue(searchSource.contains("L(\"Search failed\")"), "The contextual banner should identify the failed Search operation.")
        XCTAssertTrue(searchSource.contains("Button(L(\"Retry\"))"), "Search failure should expose a retry affordance.")
        XCTAssertTrue(searchSource.contains("Button(L(\"Dismiss\"))"), "Search failure should expose a dismiss affordance.")
        XCTAssertTrue(searchSource.contains("retrySearch"), "Retry behavior should be explicit and source-verifiable.")
        XCTAssertTrue(searchSource.contains("dismissSearchError"), "Dismiss behavior should be explicit and source-verifiable.")
        XCTAssertTrue(searchSource.contains("model.performSearch()"), "Retry should reuse the existing Search operation.")
        XCTAssertTrue(searchSource.contains("model.lastError = \"\""), "Dismiss should clear the current contextual error.")

        try writeRenderedSurface(
            SearchWindowView(embeddedInMainWindow: true)
                .environmentObject(searchModel(state: .failed)),
            size: CGSize(width: 920, height: 560),
            to: evidenceRoot.appendingPathComponent("search-error.png")
        )
    }

    func testContentViewGlobalErrorUsesNativeAlertAndNavigationRemainsNative() throws {
        let contentSource = try source("Sources/AMuleNativeRemote/ContentView.swift")

        XCTAssertTrue(contentSource.contains("DownloadsPanel("), "The main macOS window must stay focused on the downloads shell.")
        XCTAssertFalse(contentSource.contains("GlobalErrorBanner("), "Global errors should use a native alert instead of the old footer-adjacent banner.")
        XCTAssertTrue(contentSource.contains(".alert(\"aMule Remote Error\", isPresented: errorAlertBinding)"), "Global errors should use a native alert title matching the iOS SwiftUI localization style.")
        XCTAssertTrue(contentSource.contains("Text(model.lastError)"), "The native alert should present the current error message.")
        XCTAssertTrue(contentSource.contains("private var errorAlertBinding: Binding<Bool>"), "The native alert should use a binding so system dismissal can clear the error.")
        XCTAssertTrue(contentSource.contains("model.lastError = \"\""), "Alert dismissal should clear the current error.")
        XCTAssertTrue(contentSource.contains("MainWindowStatusFooter("), "The downloads shell should keep its native footer controls.")
        for forbidden in ["NavigationSplitView", ".listStyle(.sidebar)", "SidebarSelection", "normalizeSidebarSelectionForVisibleSections"] {
            XCTAssertFalse(contentSource.contains(forbidden), "The downloads shell should not use the old sidebar navigation contract: \(forbidden)")
        }
    }

    func testTouchedStateFeedbackStringsAreLocalizedAndNoLocalL2Helpers() throws {
        let files = [
            "Sources/AMuleNativeRemote/SearchWindowView.swift",
            "Sources/AMuleNativeRemote/ContentView.swift",
            "Packages/Shared/Sources/SharedViews/SharedEmptyState.swift"
        ]
        let sources = try files.map { try source($0) }
        let joinedSources = sources.joined(separator: "\n")

        XCTAssertFalse(joinedSources.contains("private func L2"), "Touched state-feedback files should use the shared localization helper, not new file-local L2 helpers.")
        XCTAssertFalse(joinedSources.contains("private func LF2"), "Touched state-feedback files should use the shared localization helper, not new file-local LF2 helpers.")

        let requiredKeys = Set(sources.flatMap(localizedKeys))
        let zhHans = try source("Resources/zh-Hans.lproj/Localizable.strings")
        let zhCN = try source("Resources/zh_CN.lproj/Localizable.strings")
        let missingZHans = requiredKeys.sorted().filter { !containsLocalizationKey($0, in: zhHans) }
        let missingZHCN = requiredKeys.sorted().filter { !containsLocalizationKey($0, in: zhCN) }

        XCTAssertTrue(missingZHans.isEmpty, "Missing zh-Hans localization keys: \(missingZHans.joined(separator: ", "))")
        XCTAssertTrue(missingZHCN.isEmpty, "Missing zh_CN localization keys: \(missingZHCN.joined(separator: ", "))")
    }

    private enum SearchRenderState {
        case initial
        case loading
        case noResults
        case failed
    }

    private var evidenceRoot: URL {
        repositoryRoot(from: packageRoot)
            .appendingPathComponent(".sisyphus/evidence/task-1-p0-state-feedback")
    }

    private func searchModel(state: SearchRenderState) -> AppModel {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["search", "download"])
        let model = AppModel(bridge: bridge, credentialStorage: PlatformServiceStubs.Credentials())
        model.bridgeOps = bridge.capabilityOps
        model.searchScope = "global"

        switch state {
        case .initial:
            model.searchQuery = ""
            model.searchResults = []
        case .loading:
            model.searchQuery = "ubuntu"
            model.searchProgress = 35
            model.isSearchInProgress = true
            model.searchResults = []
        case .noResults:
            model.searchQuery = "rare linux archive"
            model.searchProgress = 100
            model.lastSearchRawOutput = "search complete"
            model.searchResults = []
        case .failed:
            model.searchQuery = "ubuntu"
            model.searchProgress = 0
            model.lastError = "Connection timed out"
            model.searchResults = []
        }

        return model
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

    private func source(_ relativePath: String) throws -> String {
        let url = packageRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
