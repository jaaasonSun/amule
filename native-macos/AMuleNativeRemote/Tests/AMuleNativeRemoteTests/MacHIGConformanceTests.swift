import XCTest
@testable import AMuleNativeRemote

/// HIG conformance guardrails for macOS native UI.
/// These tests scan source-level patterns that conflict with Apple HIG
/// on macOS 27+. They should fail before implementation and pass after.
final class MacHIGConformanceTests: XCTestCase {

    // MARK: - Helpers

    private func sourceFilesInMacOSSources() -> [URL] {
        let sourcesDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
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
        sourceFilesInMacOSSources()
            .compactMap { try? String(contentsOf: $0, encoding: .utf8) }
    }

    // MARK: - Tests

    /// macOS sheets should not use iOS-only presentation detents.
    func testNoPresentationDetentsOnMacOS() {
        let contents = sourceContents()
        var violations: [(file: String, line: Int)] = []

        for content in contents {
            let lines = content.components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() {
                if line.contains(".presentationDetents(") {
                    violations.append((file: "unknown", line: index + 1))
                }
            }
        }

        XCTAssertTrue(violations.isEmpty,
            "Found .presentationDetents() in macOS sources. These are iOS-only patterns. Violations: \(violations)")
    }

    /// macOS sheets should not hide the drag indicator.
    func testNoPresentationDragIndicatorHiddenOnMacOS() {
        let contents = sourceContents()
        var violations: [(file: String, line: Int)] = []

        for content in contents {
            let lines = content.components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() {
                if line.contains(".presentationDragIndicator(.hidden)") {
                    violations.append((file: "unknown", line: index + 1))
                }
            }
        }

        XCTAssertTrue(violations.isEmpty,
            "Found .presentationDragIndicator(.hidden) in macOS sources. These are iOS-only patterns. Violations: \(violations)")
    }

    /// Sheets should not force .regularMaterial background on macOS.
    func testNoRegularMaterialOnSheetRoots() {
        let contents = sourceContents()
        var violations: [(file: String, line: Int)] = []

        for content in contents {
            let lines = content.components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() {
                if line.contains(".background(.regularMaterial)") {
                    violations.append((file: "unknown", line: index + 1))
                }
            }
        }

        XCTAssertTrue(violations.isEmpty,
            "Found .background(.regularMaterial) in macOS sources. Let system default apply. Violations: \(violations)")
    }

    /// Non-toolbar content should not use .bar material (iOS-centric).
    func testNoBarMaterialOutsideToolbar() {
        let contents = sourceContents()
        var violations: [(file: String, line: Int)] = []

        for content in contents {
            let lines = content.components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() {
                if line.contains(".background(.bar)") {
                    violations.append((file: "unknown", line: index + 1))
                }
            }
        }

        XCTAssertTrue(violations.isEmpty,
            "Found .background(.bar) in macOS sources. Use default backgrounds. Violations: \(violations)")
    }

    /// Custom NSViewRepresentable window chrome hacks should not exist.
    func testNoCustomWindowChromeHacks() {
        let contents = sourceContents()
        let forbiddenTypes = [
            "WindowAppearanceConfigurator",
            "WindowFrameAutosaveConfigurator",
            "WindowTopInsetReader",
            "ServersTableAutosaveConfigurator"
        ]

        var violations: [(type: String, line: Int)] = []

        for content in contents {
            let lines = content.components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() {
                for type in forbiddenTypes {
                    if line.contains(type) {
                        violations.append((type: type, line: index + 1))
                    }
                }
            }
        }

        XCTAssertTrue(violations.isEmpty,
            "Found custom NSViewRepresentable window hacks. Use native SwiftUI APIs. Violations: \(violations)")
    }

    /// Orphaned views should not be referenced in source.
    func testNoOrphanedAddLinksWindowView() {
        let contents = sourceContents()
        var violations: [Int] = []

        for content in contents {
            let lines = content.components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() {
                if line.contains("AddLinksWindowView") {
                    violations.append(index + 1)
                }
            }
        }

        XCTAssertTrue(violations.isEmpty,
            "Found references to AddLinksWindowView (orphaned). Remove all references. Violations: \(violations)")
    }

    /// Custom footer/HUD overlays should not exist in macOS content.
    func testNoCustomFooterOrHUDInContentView() {
        let contents = sourceContents()
        var violations: [(symbol: String, line: Int)] = []

        for content in contents {
            let lines = content.components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() {
                if line.contains("MainFooterBar(") {
                    violations.append((symbol: "MainFooterBar", line: index + 1))
                }
                if line.contains("AddLinksHUD(") {
                    violations.append((symbol: "AddLinksHUD", line: index + 1))
                }
            }
        }

        XCTAssertTrue(violations.isEmpty,
            "Found custom footer/HUD in macOS sources. Use native toolbar/status. Violations: \(violations)")
    }

    /// forceNoToolbar should not exist.
    func testNoForceNoToolbar() {
        let contents = sourceContents()
        var violations: [Int] = []

        for content in contents {
            let lines = content.components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() {
                if line.contains("forceNoToolbar") {
                    violations.append(index + 1)
                }
            }
        }

        XCTAssertTrue(violations.isEmpty,
            "Found forceNoToolbar. Do not fight SwiftUI toolbar. Violations: \(violations)")
    }
}
