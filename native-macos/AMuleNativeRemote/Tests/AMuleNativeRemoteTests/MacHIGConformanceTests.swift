import XCTest
@testable import AMuleNativeRemote

/// HIG conformance guardrails for macOS native UI.
/// These tests scan source-level patterns that conflict with Apple HIG
/// on macOS 27+. They should fail before implementation and pass after.
final class MacHIGConformanceTests: XCTestCase {
    private struct SourceSnapshot {
        let relativePath: String
        let contents: String
    }

    // MARK: - Helpers

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

    private func sourceFilesInMacOSSources() -> [URL] {
        let sourcesDir = packageRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("AMuleNativeRemote")

        guard let enumerator = FileManager.default.enumerator(
            at: sourcesDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            XCTFail("Could not enumerate macOS sources")
            return []
        }

        return enumerator
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
    }

    private func sourceContents() -> [String] {
        sourceSnapshots().map(\.contents)
    }

    private func sourceSnapshots() -> [SourceSnapshot] {
        let rootPath = packageRoot.path + "/"
        return sourceFilesInMacOSSources().compactMap { url in
            guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            let relativePath = url.path.hasPrefix(rootPath)
                ? String(url.path.dropFirst(rootPath.count))
                : url.lastPathComponent
            return SourceSnapshot(relativePath: relativePath, contents: contents)
        }
    }

    private func source(_ relativePath: String) throws -> String {
        return try String(
            contentsOf: packageRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    private func mainWindowStatusFooterSource(in source: String) throws -> String {
        let start = try XCTUnwrap(source.range(of: "private struct MainWindowStatusFooter")?.lowerBound)
        let end = try XCTUnwrap(source.range(of: "#if DEBUG", range: start..<source.endIndex)?.lowerBound)
        return String(source[start..<end])
    }

    private func assertMacOSSourcesDoNotContain(_ forbiddenPatterns: [String], message: String) {
        var violations: [(file: String, pattern: String, line: Int)] = []

        for snapshot in sourceSnapshots() {
            let lines = snapshot.contents.components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() {
                for pattern in forbiddenPatterns where line.contains(pattern) {
                    violations.append((file: snapshot.relativePath, pattern: pattern, line: index + 1))
                }
            }
        }

        XCTAssertTrue(violations.isEmpty, "\(message) Violations: \(violations)")
    }

    private func occurrenceCount(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    // MARK: - Tests

    func testAddLinksHUDUsesHistoricalSharedOverlay() throws {
        let content = try source("Sources/AMuleNativeRemote/ContentView.swift")

        XCTAssertTrue(
            content.contains(".overlay {\n                if model.showHUD {\n                    AddLinksHUD(message: model.hudMessage)"),
            "The add-link feedback must use the historical shared HUD overlay."
        )
    }

    func testMainMacSourcesRemainSidebarFree() {
        assertMacOSSourcesDoNotContain(
            [
                "NavigationSplitView",
                ".listStyle(.sidebar)",
                "SidebarSelection",
                "sidebarSelectionBinding",
                "normalizedSidebarSelectionForVisibleSections",
                "normalizedSidebarSelectionForVisibility"
            ],
            message: "The macOS app should keep the downloads shell sidebar-free and open secondary sections in standalone windows."
        )
    }

    func testNoForcedToolbarHidingOrHiddenTitleBarChrome() {
        assertMacOSSourcesDoNotContain(
            [
                ".toolbarVisibility(.hidden",
                ".windowStyle(.hiddenTitleBar)"
            ],
            message: "The macOS app should rely on native window chrome and toolbar behavior instead of hiding system surfaces."
        )
    }

    /// macOS sheets should not use iOS-only presentation detents.
    func testNoPresentationDetentsOnMacOS() {
        assertMacOSSourcesDoNotContain(
            [".presentationDetents("],
            message: "Found .presentationDetents() in macOS sources. These are iOS-only patterns."
        )
    }

    /// macOS sheets should not hide the drag indicator.
    func testNoPresentationDragIndicatorHiddenOnMacOS() {
        assertMacOSSourcesDoNotContain(
            [".presentationDragIndicator(.hidden)"],
            message: "Found .presentationDragIndicator(.hidden) in macOS sources. These are iOS-only patterns."
        )
    }

    /// Sheets should not force .regularMaterial background on macOS.
    func testNoRegularMaterialOnSheetRoots() {
        assertMacOSSourcesDoNotContain(
            [".background(.regularMaterial)"],
            message: "Found .background(.regularMaterial) in macOS sources. Let system default apply."
        )
    }

    /// Non-toolbar content should not use .bar material (iOS-centric).
    func testNoBarMaterialOutsideToolbar() {
        assertMacOSSourcesDoNotContain(
            [".background(.bar)"],
            message: "Found .background(.bar) in macOS sources. Use default backgrounds."
        )
    }

    /// Custom NSViewRepresentable window chrome hacks should not exist.
    func testNoCustomWindowChromeHacks() {
        let forbiddenTypes = [
            "WindowAppearanceConfigurator",
            "WindowFrameAutosaveConfigurator",
            "WindowTopInsetReader",
            "ServersTableAutosaveConfigurator"
        ]

        assertMacOSSourcesDoNotContain(
            forbiddenTypes,
            message: "Found custom NSViewRepresentable window hacks. Use native SwiftUI APIs."
        )
    }

    /// Orphaned views should not be referenced in source.
    func testNoOrphanedAddLinksWindowView() {
        assertMacOSSourcesDoNotContain(
            ["AddLinksWindowView"],
            message: "Found references to AddLinksWindowView (orphaned). Remove all references."
        )
    }

    func testNoCustomFooterInContentView() {
        assertMacOSSourcesDoNotContain(
            ["MainFooterBar("],
            message: "Found retired custom footer in macOS sources. Use native toolbar/status."
        )
    }

    func testMainStatusFooterUsesIndividualNativeButtons() throws {
        let content = try source("Sources/AMuleNativeRemote/ContentView.swift")
        let footer = try mainWindowStatusFooterSource(in: content)

        XCTAssertEqual(occurrenceCount(of: "FooterControlButton(", in: footer), 5, "The footer should expose Connection, eD2K, Kad, Download speed, and Upload speed as five separate controls.")
        XCTAssertTrue(footer.contains("Button(action: action)"), "FooterControlButton should preserve native Button semantics instead of gesture-only clickable text.")
        XCTAssertTrue(footer.contains(".buttonStyle(FooterControlButtonStyle(isHovering: isHovering))"), "Footer buttons should keep the shared native ButtonStyle affordance.")
        XCTAssertFalse(footer.contains(".accessibilityElement(children: .combine)"), "The footer must not collapse all controls into one combined accessibility element.")
        XCTAssertFalse(footer.contains("onTapGesture"), "Footer actions should stay native Button controls, not gesture handlers.")
        XCTAssertTrue(footer.contains(".accessibilityLabel(accessibilityLabel)"), "Each footer button needs an explicit accessibility label.")
        XCTAssertTrue(footer.contains(".accessibilityValue(normalizedAccessibilityValue)"), "Each footer button needs an explicit accessibility value.")
        XCTAssertTrue(footer.contains(".accessibilityHint(accessibilityHint)"), "Each footer button needs an explicit accessibility hint.")
    }

    /// forceNoToolbar should not exist.
    func testNoForceNoToolbar() {
        assertMacOSSourcesDoNotContain(
            ["forceNoToolbar"],
            message: "Found forceNoToolbar. Do not fight SwiftUI toolbar."
        )
    }
}
