import XCTest
import SharedUI

@testable import AMuleNativeRemote

final class ContentViewFilterRegressionTests: XCTestCase {
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
}
