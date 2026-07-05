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

    func testDownloadsWindowFrameUsesAppKitAutosave() {
        XCTAssertEqual(DownloadsWindowPersistence.frameAutosaveName, "AMuleNativeRemote.DownloadsWindow")
    }
}
