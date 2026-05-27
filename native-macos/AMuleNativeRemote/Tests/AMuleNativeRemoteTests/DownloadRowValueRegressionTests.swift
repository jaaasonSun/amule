#if canImport(XCTest)
import XCTest
import SharedUI

@testable import AMuleNativeRemote

final class DownloadRowValueRegressionTests: XCTestCase {
    func testPresentedDownloadRowsExposeNonBlankValuesAndExcludeMalformedSharedRows() throws {
        let json = #"{"ok":true,"downloads":[{"ecid":1001,"hash":"00112233445566778899aabbccddeeff","name":"Active Part.iso","size":2097152,"done":524288,"transferred":524288,"progress":25,"sources_current":1,"sources_total":3,"sources_transferring":1,"sources_a4af":0,"status_code":0,"is_completed":false,"status":"Downloading","speed":4096,"priority":0,"category":0,"part_met":"001.part.met","last_seen_complete":0,"last_received":0,"active_seconds":0,"available_parts":4,"shared":false,"alternative_names":[],"progress_colors":[]},{"ecid":1002,"hash":"8899aabbccddeeff0011223344556677","name":"Finished Movie.mkv","size":1048576,"done":1048576,"transferred":1048576,"progress":100,"sources_current":0,"sources_total":0,"sources_transferring":0,"sources_a4af":0,"status_code":9,"is_completed":true,"status":"Completed","speed":0,"priority":0,"category":0,"part_met":"002.part.met","last_seen_complete":1716681600,"last_received":1716681600,"active_seconds":0,"available_parts":0,"shared":false,"alternative_names":[],"progress_colors":[]},{"ecid":1003,"hash":"fedcba98765432100112233445566778","name":"   ","size":0,"done":0,"transferred":0,"progress":0,"sources_current":0,"sources_total":0,"sources_transferring":0,"sources_a4af":0,"status_code":0,"is_completed":false,"status":"Waiting","speed":0,"priority":0,"category":0,"part_met":"003.part.met","last_seen_complete":0,"last_received":0,"active_seconds":0,"available_parts":0,"shared":false,"alternative_names":[],"progress_colors":[]},{"ecid":1004,"hash":"0123456789abcdeffedcba9876543210","name":"Old Shared Archive.zip","size":3145728,"done":3145728,"transferred":3145728,"progress":100,"sources_current":0,"sources_total":0,"sources_transferring":0,"sources_a4af":0,"status_code":9,"is_completed":true,"status":"Completed","speed":0,"priority":0,"category":0,"part_met":"004.part.met","last_seen_complete":1716681600,"last_received":1716681600,"active_seconds":0,"available_parts":0,"shared":true,"alternative_names":[],"progress_colors":[]}]}"#

        let data = try XCTUnwrap(json.data(using: .utf8))
        let envelope = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        let downloads = try XCTUnwrap(envelope.downloads)
        let items = DownloadItem.fromBridge(downloads)

        let presentedRows = items.filter { item in
            item.trimmedDisplayName != nil && !item.shared
        }

        XCTAssertEqual(presentedRows.map(\.name), ["Active Part.iso", "Finished Movie.mkv"])

        let active = try XCTUnwrap(presentedRows.first(where: { $0.name == "Active Part.iso" }))
        let finished = try XCTUnwrap(presentedRows.first(where: { $0.name == "Finished Movie.mkv" }))
        let malformed = try XCTUnwrap(items.first(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }))
        let shared = try XCTUnwrap(items.first(where: { $0.shared }))

        XCTAssertTrue(DownloadClassification.isDownloading(row(active)))
        XCTAssertTrue(DownloadClassification.isCompleted(row(finished)))

        assertVisibleRowValues(active, expectedStatusSymbol: "arrow.down.circle")
        assertVisibleRowValues(finished, expectedStatusSymbol: "checkmark.circle")

        XCTAssertNil(malformed.trimmedDisplayName)
        XCTAssertTrue(shared.shared)
        XCTAssertEqual(shared.trimmedDisplayName, "Old Shared Archive.zip")
        XCTAssertFalse(presentedRows.contains(where: { $0.name == malformed.name }))
        XCTAssertFalse(presentedRows.contains(where: { $0.name == shared.name }))
    }

    private func assertVisibleRowValues(_ item: DownloadItem, expectedStatusSymbol: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, file: file, line: line)
        XCTAssertFalse(item.progressText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, file: file, line: line)
        XCTAssertFalse(item.sourcesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, file: file, line: line)
        XCTAssertEqual(DownloadStatusSymbol.categorySymbolName(for: row(item)), expectedStatusSymbol, file: file, line: line)
    }

    private func row(_ item: DownloadItem) -> RowDownload {
        RowDownload(
            statusCode: item.statusCode,
            status: item.status,
            isCompleted: item.isCompleted,
            sizeBytes: item.sizeBytes,
            doneBytes: item.doneBytes,
            speedBytes: item.speedBytes,
            sourceTransferring: item.sourceTransferring
        )
    }

    private struct RowDownload: DownloadClassifiable {
        let statusCode: Int
        let status: String
        let isCompleted: Bool
        let sizeBytes: UInt64
        let doneBytes: UInt64
        let speedBytes: Int
        let sourceTransferring: Int
    }
}
#endif
