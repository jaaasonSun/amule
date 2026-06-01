import XCTest
import AMuleRemoteIOSShared
import SharedViews

final class DownloadListPresentationTests: XCTestCase {
    func testSearchQueryFiltersDownloadNamesAndStatus() {
        let downloads = [
            download(name: "Ubuntu ISO", status: "Downloading", speedBytes: 1024),
            download(name: "Archive.zip", status: "Paused", statusCode: 7),
            download(name: "Movie.mkv", status: "Complete", statusCode: 9, isCompleted: true),
        ]

        XCTAssertEqual(
            DownloadListPresentation.displayedDownloads(downloads, filter: .all, query: "ubuntu", sort: .name, ascending: true).map(\.name),
            ["Ubuntu ISO"]
        )
        XCTAssertEqual(
            DownloadListPresentation.displayedDownloads(downloads, filter: .all, query: "paused", sort: .name, ascending: true).map(\.name),
            ["Archive.zip"]
        )
    }

    func testStatusFiltersMatchSharedClassification() {
        let downloads = [
            download(name: "Active", status: "Downloading", speedBytes: 1024),
            download(name: "Waiting", status: "Waiting"),
            download(name: "Paused", status: "Paused", statusCode: 7),
            download(name: "No Space", status: "Insufficient disk space", statusCode: 5),
            download(name: "Done", status: "Complete", statusCode: 9, isCompleted: true),
        ]

        XCTAssertEqual(DownloadListPresentation.displayedDownloads(downloads, filter: .downloading, query: "", sort: .name, ascending: true).map(\.name), ["Active"])
        XCTAssertEqual(DownloadListPresentation.displayedDownloads(downloads, filter: .pending, query: "", sort: .name, ascending: true).map(\.name), ["Waiting"])
        XCTAssertEqual(DownloadListPresentation.displayedDownloads(downloads, filter: .paused, query: "", sort: .name, ascending: true).map(\.name), ["No Space", "Paused"])
        XCTAssertEqual(DownloadListPresentation.displayedDownloads(downloads, filter: .completed, query: "", sort: .name, ascending: true).map(\.name), ["Done"])
    }

    func testFilterIconsUseSharedCategorySymbols() {
        XCTAssertEqual(DownloadListFilter.downloading.systemImage, DownloadStatusSymbol.downloadingCategorySymbolName)
        XCTAssertEqual(DownloadListFilter.pending.systemImage, DownloadStatusSymbol.pendingCategorySymbolName)
        XCTAssertEqual(DownloadListFilter.paused.systemImage, DownloadStatusSymbol.pausedCategorySymbolName)
        XCTAssertEqual(DownloadListFilter.completed.systemImage, DownloadStatusSymbol.completedCategorySymbolName)
    }

    func testSortsBySpeedProgressSizeSourcesAndStatus() {
        let downloads = [
            download(name: "Slow", status: "Waiting", sizeBytes: 10, progressValue: 10, sourceTotal: 1, speedBytes: 1),
            download(name: "Fast", status: "Downloading", sizeBytes: 30, progressValue: 30, sourceTotal: 3, speedBytes: 3),
            download(name: "Mid", status: "Paused", statusCode: 7, sizeBytes: 20, progressValue: 20, sourceTotal: 2),
        ]

        XCTAssertEqual(DownloadListPresentation.displayedDownloads(downloads, filter: .all, query: "", sort: .speed, ascending: false).map(\.name), ["Fast", "Slow", "Mid"])
        XCTAssertEqual(DownloadListPresentation.displayedDownloads(downloads, filter: .all, query: "", sort: .progress, ascending: false).map(\.name), ["Fast", "Mid", "Slow"])
        XCTAssertEqual(DownloadListPresentation.displayedDownloads(downloads, filter: .all, query: "", sort: .size, ascending: false).map(\.name), ["Fast", "Mid", "Slow"])
        XCTAssertEqual(DownloadListPresentation.displayedDownloads(downloads, filter: .all, query: "", sort: .sources, ascending: false).map(\.name), ["Fast", "Mid", "Slow"])
        XCTAssertEqual(DownloadListPresentation.displayedDownloads(downloads, filter: .all, query: "", sort: .status, ascending: true).map(\.name), ["Fast", "Mid", "Slow"])
    }

    private func download(
        name: String,
        status: String,
        statusCode: Int = 0,
        isCompleted: Bool = false,
        sizeBytes: UInt64 = 100,
        doneBytes: UInt64 = 10,
        progressValue: Double = 10,
        sourceTotal: Int = 0,
        speedBytes: Int = 0
    ) -> DownloadItem {
        DownloadItem(
            ecid: 1,
            id: name,
            name: name,
            nameEncodingSuspect: false,
            nameEncodingSuggestion: nil,
            sizeBytes: sizeBytes,
            doneBytes: doneBytes,
            transferredBytes: doneBytes,
            progressValue: progressValue,
            sourceCurrent: sourceTotal,
            sourceTotal: sourceTotal,
            sourceTransferring: speedBytes > 0 ? 1 : 0,
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
