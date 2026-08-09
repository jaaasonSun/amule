import XCTest

@testable import AMuleNativeRemote

final class DownloadTableColumnLayoutTests: XCTestCase {
    func testAllDownloadColumnsAreResizable() {
        XCTAssertTrue(DownloadTableColumnLayout.name.isResizable)
        XCTAssertTrue(DownloadTableColumnLayout.progress.isResizable)
        XCTAssertTrue(DownloadTableColumnLayout.speed.isResizable)
        XCTAssertTrue(DownloadTableColumnLayout.sources.isResizable)
    }

    func testProgressColumnDefaultIsAtLeastPreviousFixedWidth() {
        XCTAssertGreaterThanOrEqual(DownloadTableColumnLayout.progress.minWidth, 128)
        XCTAssertGreaterThanOrEqual(DownloadTableColumnLayout.progress.idealWidth, 128)
    }

    func testSourceColumnDefaultAndIdealWidthIsSeventyTwo() {
        XCTAssertEqual(DownloadTableColumnLayout.sources.idealWidth, 72)
    }

    func testDownloadTableColumnWidthsUseSwiftUIColumnCustomizationStorage() {
        XCTAssertEqual(
            DownloadTableColumnPersistence.columnCustomizationDefaultsKey,
            "AMuleNativeRemote.DownloadsTable.columnCustomization"
        )
    }

    func testDownloadTableSortOrderUsesPersistentSwiftUIStorage() {
        XCTAssertEqual(
            DownloadTableSortPersistence.sortOrderDefaultsKey,
            "AMuleNativeRemote.DownloadsTable.sortOrder"
        )
    }

    func testDownloadTableSortOrderRoundTripsCriteriaAndDirections() {
        let comparators = [
            KeyPathComparator(\DownloadItem.speedSortValue, order: .reverse),
            KeyPathComparator(\DownloadItem.name, order: .forward),
            KeyPathComparator(\DownloadItem.progressSortValue, order: .reverse),
            KeyPathComparator(\DownloadItem.sourceTotal, order: .forward)
        ]

        let rawValue = DownloadTableSortPersistence.rawValue(for: comparators)
        let entries = DownloadTableSortPersistence.decode(rawValue)
        let restoredComparators = DownloadTableSortPersistence.comparators(from: rawValue)

        XCTAssertEqual(
            entries,
            [
                .init(criterion: .speed, direction: .reverse),
                .init(criterion: .name, direction: .forward),
                .init(criterion: .progress, direction: .reverse),
                .init(criterion: .sources, direction: .forward)
            ]
        )
        XCTAssertEqual(restoredComparators.map(\.keyPath), comparators.map(\.keyPath))
        XCTAssertEqual(restoredComparators.map(\.order), comparators.map(\.order))
    }

    func testDownloadTableSortOrderFallsBackToNameAscending() {
        let entries = DownloadTableSortPersistence.decode("not valid JSON")
        let comparators = DownloadTableSortPersistence.comparators(from: "[]")

        XCTAssertEqual(entries, DownloadTableSortPersistence.defaultEntries)
        XCTAssertEqual(comparators.count, 1)
        XCTAssertEqual(comparators[0].keyPath, \DownloadItem.name)
        XCTAssertEqual(comparators[0].order, .forward)
    }

}
