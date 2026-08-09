import XCTest
import SwiftUI
import SharedViews

@testable import AMuleNativeRemote

final class ContentViewFilterRegressionTests: XCTestCase {
    @MainActor
    func testSidebarFreeMainWindowRenderEvidence() throws {
        let evidenceURL = repositoryRoot(from: packageRoot())
            .appendingPathComponent(".sisyphus/evidence/task-3-sidebar-free-main.png")

        try writeRenderedSurface(
            ContentView().environmentObject(AppModel.previewWithDownloads()),
            size: CGSize(width: 1040, height: 620),
            to: evidenceURL
        )
    }

    func testDownloadStatusFilterIsToolbarBasedAndKeepsAllBuckets() throws {
        let content = try source("Sources/AMuleNativeRemote/ContentView.swift")
        let toolbar = try source("Sources/AMuleNativeRemote/MainToolbar.swift")
        let statusControl = try statusFilterToolbarItemSource(in: toolbar)
        let windowTitle = try windowTitleTextSource(in: content)

        XCTAssertTrue(content.contains("enum DownloadStatusFilter"), "The download status buckets should no longer be named after the old sidebar.")
        XCTAssertTrue(content.contains("@State private var selectedDownloadStatusFilter = DownloadStatusFilter.all"))
        XCTAssertTrue(content.contains("downloadStatusFilterCounts"), "ContentView should compute live counts for the toolbar status filter.")
        XCTAssertTrue(content.contains("filteredDownloads(model.downloads, for: selectedDownloadStatusFilter)"), "Displayed downloads should be scoped by the toolbar status filter.")
        XCTAssertFalse(content.contains("DownloadSidebarFilter"), "ContentView should not keep sidebar-era filter naming.")

        XCTAssertTrue(toolbar.contains("Download Status Filter"), "The toolbar should expose a status filter control.")
        XCTAssertTrue(
            statusControl.contains("ToolbarItem(placement: .navigation)"),
            "The first status filter toolbar item should use .navigation so it is placed before the inline window title on macOS."
        )
        XCTAssertTrue(statusControl.contains("Menu {"), "The status filter should be a direct native Menu so the toolbar face sizes to its label.")
        XCTAssertTrue(statusControl.contains("ForEach(ContentView.DownloadStatusFilter.allCases) { filter in"), "The menu should include all status buckets.")
        XCTAssertTrue(
            statusControl.contains("Button {\n                        selectedDownloadStatusFilter = filter\n                    } label: {"),
            "Each status row should select directly without a nested Picker."
        )
        XCTAssertTrue(
            statusControl.contains("Label(downloadStatusFilterLabel(for: filter), systemImage: filter.symbolName)\n                                .labelStyle(.titleAndIcon)"),
            "Status menu rows should keep full names, symbols, and counts."
        )
        XCTAssertTrue(
            statusControl.contains("if filter == selectedDownloadStatusFilter {\n                                Image(systemName: \"checkmark\")\n                            }"),
            "The selected status row should show a native checkmark."
        )
        XCTAssertTrue(statusControl.contains("downloadStatusFilterLabel(for: selectedDownloadStatusFilter)"), "The toolbar label should preserve the active status count for semantics.")
        XCTAssertTrue(
            statusControl.contains("Label(downloadStatusFilterLabel(for: selectedDownloadStatusFilter), systemImage: selectedDownloadStatusFilter == .all ? \"line.3.horizontal.decrease.circle\" : \"line.3.horizontal.decrease.circle.fill\")\n                    .labelStyle(.iconOnly)"),
            "The Menu trigger should use the outline filter symbol for All and the same-family filled symbol for active filters."
        )
        XCTAssertFalse(
            statusControl.contains("systemImage: selectedDownloadStatusFilter.symbolName"),
            "The Menu trigger must not use the selected filter symbol because glyph width changes resize the toolbar control."
        )
        XCTAssertFalse(statusControl.contains("Picker("), "The toolbar status control should not use Picker because menu-style Picker reserves option-title width.")
        XCTAssertFalse(statusControl.contains(".pickerStyle(.menu)"), "The toolbar status control should not use menu-style Picker sizing.")
        XCTAssertFalse(statusControl.contains(".tag(filter)"), "Direct Menu buttons should not keep Picker tags.")
        XCTAssertFalse(
            statusControl.contains("Label(downloadStatusFilterLabel(for: filter), systemImage: filter.symbolName)\n                                .labelStyle(.iconOnly)"),
            "Status menu rows should keep full names, symbols, and counts instead of inheriting icon-only presentation."
        )
        XCTAssertTrue(statusControl.contains(".help(L(\"Download Status Filter\"))"))
        XCTAssertTrue(statusControl.contains(".accessibilityLabel(L(\"Download Status Filter\"))"))
        XCTAssertTrue(statusControl.contains(".accessibilityValue(downloadStatusFilterLabel(for: selectedDownloadStatusFilter))"))

        for forbiddenSizingHack in [".frame(", ".fixedSize(", ".padding", "Spacer(", ".menuIndicator(.hidden)", ".labelsHidden()", ".accessibilityHidden(true)", ".hidden()"] {
            XCTAssertFalse(statusControl.contains(forbiddenSizingHack), "Status toolbar control should not use sizing or hiding hack: \(forbiddenSizingHack)")
        }

        for label in ["case all = \"All\"", "case downloading = \"Downloading\"", "case pending = \"Pending\"", "case paused = \"Paused\"", "case completed = \"Completed\""] {
            XCTAssertTrue(content.contains(label), "Missing status choice: \(label)")
        }

        XCTAssertTrue(windowTitle.contains("selectedDownloadStatusFilter"), "The inline window title should reflect the active status filter.")
        XCTAssertTrue(windowTitle.contains(".all"), "The All filter should keep the plain Downloads title.")
        XCTAssertTrue(windowTitle.contains("L(\"Downloads\")"), "The base Downloads title should remain localized.")
        XCTAssertTrue(
            windowTitle.contains("selectedDownloadStatusFilter.localizedTitle"),
            "Non-All status filters should append the selected localized filter title without requiring a new localization key."
        )

        for bucket in ["all", "downloading", "pending", "paused", "completed"] {
            XCTAssertTrue(content.contains("case \(bucket)"), "Missing status bucket: \(bucket)")
        }
    }

    func testCompletedDownloadIsIncludedInCompletedBucketAndAll() {
        let active = makeDownload(
            statusCode: 0,
            status: "Downloading",
            isCompleted: false,
            sizeBytes: 2_097_152,
            doneBytes: 524_288,
            speedBytes: 4_096,
            sourceTransferring: 1
        )

        let finished = makeDownload(
            statusCode: 9,
            status: "Completed",
            isCompleted: true,
            sizeBytes: 1_048_576,
            doneBytes: 1_048_576,
            speedBytes: 0,
            sourceTransferring: 0
        )

        let malformed = makeDownload(
            statusCode: 0,
            status: "Waiting",
            isCompleted: false,
            sizeBytes: 0,
            doneBytes: 0,
            speedBytes: 0,
            sourceTransferring: 0
        )

        let downloads = [active, finished, malformed]

        XCTAssertTrue(MacOSDownloadClassification.isDownloading(active))
        XCTAssertTrue(MacOSDownloadClassification.isCompleted(finished))
        XCTAssertFalse(MacOSDownloadClassification.isCompleted(active))
        XCTAssertFalse(MacOSDownloadClassification.isCompleted(malformed))

        let completedCount = downloads.filter(MacOSDownloadClassification.isCompleted).count
        let activeCount = downloads.filter { !MacOSDownloadClassification.isCompleted($0) }.count

        XCTAssertEqual(activeCount, 2)
        XCTAssertEqual(completedCount, 1)
    }

    func testMacOSDownloadItemConformanceMatchesSharedFilterBuckets() {
        let downloading = makeDownload(
            statusCode: 0,
            status: "Downloading",
            isCompleted: false,
            sizeBytes: 1_000,
            doneBytes: 100,
            speedBytes: 42,
            sourceTransferring: 1
        )
        let pending = makeDownload(
            statusCode: 0,
            status: "Waiting",
            isCompleted: false,
            sizeBytes: 1_000,
            doneBytes: 100,
            speedBytes: 0,
            sourceTransferring: 0
        )
        let paused = makeDownload(
            statusCode: 7,
            status: "Paused",
            isCompleted: false,
            sizeBytes: 1_000,
            doneBytes: 100,
            speedBytes: 0,
            sourceTransferring: 0
        )
        let completed = makeDownload(
            statusCode: 9,
            status: "Completed",
            isCompleted: true,
            sizeBytes: 1_000,
            doneBytes: 1_000,
            speedBytes: 0,
            sourceTransferring: 0
        )

        let downloads = [downloading, pending, paused, completed]

        XCTAssertEqual(downloads.filter(MacOSDownloadClassification.isDownloading).map(\.id), [downloading.id])
        XCTAssertEqual(downloads.filter(MacOSDownloadClassification.isPending).map(\.id), [pending.id])
        XCTAssertEqual(downloads.filter(MacOSDownloadClassification.isPaused).map(\.id), [paused.id])
        XCTAssertEqual(downloads.filter(MacOSDownloadClassification.isCompleted).map(\.id), [completed.id])
    }

    private func makeDownload(
        statusCode: Int,
        status: String,
        isCompleted: Bool,
        sizeBytes: UInt64,
        doneBytes: UInt64,
        speedBytes: Int,
        sourceTransferring: Int
    ) -> DownloadItem {
        DownloadItem(
            ecid: 1,
            id: UUID().uuidString,
            name: "Example",
            nameEncodingSuspect: false,
            nameEncodingSuggestion: nil,
            sizeBytes: sizeBytes,
            doneBytes: doneBytes,
            transferredBytes: doneBytes,
            progressValue: sizeBytes > 0 ? (Double(doneBytes) / Double(sizeBytes)) * 100 : 0,
            sourceCurrent: 0,
            sourceTotal: 0,
            sourceTransferring: sourceTransferring,
            sourceA4AF: 0,
            statusCode: statusCode,
            isCompleted: isCompleted,
            status: status,
            speedBytes: speedBytes,
            priority: 0,
            category: 0,
            partMetName: "",
            lastSeenComplete: 0,
            lastReceived: 0,
            activeSeconds: 0,
            availableParts: 0,
            shared: false,
            alternativeNames: [],
            progressColors: []
        )
    }

    private func source(_ relativePath: String) throws -> String {
        let url = packageRoot().appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func statusFilterToolbarItemSource(in toolbar: String) throws -> String {
        let start = try XCTUnwrap(
            toolbar.range(of: "ToolbarItem(placement:")?.lowerBound,
            "The first toolbar status filter should be a direct Menu."
        )
        let end = try XCTUnwrap(
            toolbar[start...].range(of: "\n        }\n\n        ToolbarItem(placement: .automatic) {")?.lowerBound,
            "The status filter toolbar item should remain the first toolbar item."
        )
        return String(toolbar[start..<end])
    }

    private func windowTitleTextSource(in content: String) throws -> String {
        let start = try XCTUnwrap(
            content.range(of: "private var windowTitleText: String {")?.lowerBound,
            "ContentView should centralize the inline downloads title."
        )
        let end = try XCTUnwrap(
            content.range(of: "\n\n    private var baseBody: some View", range: start..<content.endIndex)?.lowerBound,
            "The windowTitleText source should end before baseBody."
        )
        return String(content[start..<end])
    }

    private func packageRoot() -> URL {
        let testFile = URL(fileURLWithPath: #filePath)
        return testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
