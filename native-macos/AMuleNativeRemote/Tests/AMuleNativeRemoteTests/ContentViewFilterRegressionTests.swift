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

        XCTAssertTrue(content.contains("enum DownloadStatusFilter"), "The download status buckets should no longer be named after the old sidebar.")
        XCTAssertTrue(content.contains("@State private var selectedDownloadStatusFilter = DownloadStatusFilter.all"))
        XCTAssertTrue(content.contains("downloadStatusFilterCounts"), "ContentView should compute live counts for the toolbar status filter.")
        XCTAssertTrue(content.contains("filteredDownloads(model.downloads, for: selectedDownloadStatusFilter)"), "Displayed downloads should be scoped by the toolbar status filter.")
        XCTAssertFalse(content.contains("DownloadSidebarFilter"), "ContentView should not keep sidebar-era filter naming.")

        XCTAssertTrue(toolbar.contains("Download Status Filter"), "The toolbar should expose a status filter control.")
        XCTAssertFalse(toolbar.contains("Picker(L(\"Download Status Filter\"), selection: $selectedDownloadStatusFilter)"), "The toolbar status control should not use a nested picker that creates an intermediate submenu row.")
        XCTAssertTrue(toolbar.contains("downloadStatusFilterLabel(for: selectedDownloadStatusFilter)"), "The toolbar label should include the active status count.")
        XCTAssertTrue(toolbar.contains("downloadStatusFilterLabel(for: filter)"), "Each status choice should still render through the count label helper or an equivalent presentation.")
        XCTAssertTrue(toolbar.contains(".help(L(\"Download Status Filter\"))"))
        XCTAssertTrue(toolbar.contains(".accessibilityLabel(L(\"Download Status Filter\"))"))
        XCTAssertTrue(toolbar.contains(".accessibilityValue(downloadStatusFilterLabel(for: selectedDownloadStatusFilter))"))

        for label in ["case all = \"All\"", "case downloading = \"Downloading\"", "case pending = \"Pending\"", "case paused = \"Paused\"", "case completed = \"Completed\""] {
            XCTAssertTrue(content.contains(label), "Missing status choice: \(label)")
        }

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

    private func packageRoot() -> URL {
        let testFile = URL(fileURLWithPath: #filePath)
        return testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
