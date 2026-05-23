import XCTest
@testable import AMuleRemoteIOSShared

final class RenameVerificationTests: XCTestCase {
    func testRenameIsVerifiedByMatchingHashAndNewName() {
        let downloads = [
            download(id: "other", name: "Corrected.mkv"),
            download(id: "hash", name: "Corrected.mkv"),
        ]

        XCTAssertTrue(RenameVerification.wasApplied(downloadID: "hash", newName: "Corrected.mkv", downloads: downloads))
    }

    func testRenameIsNotVerifiedWhenNameRemainsUnchanged() {
        let downloads = [
            download(id: "hash", name: "Original.mkv"),
        ]

        XCTAssertFalse(RenameVerification.wasApplied(downloadID: "hash", newName: "Corrected.mkv", downloads: downloads))
    }

    private func download(id: String, name: String) -> DownloadItem {
        DownloadItem(
            ecid: 1,
            id: id,
            name: name,
            nameEncodingSuspect: false,
            nameEncodingSuggestion: nil,
            sizeBytes: 100,
            doneBytes: 10,
            transferredBytes: 10,
            progressValue: 10,
            sourceCurrent: 0,
            sourceTotal: 0,
            sourceTransferring: 0,
            sourceA4AF: 0,
            statusCode: 0,
            isCompleted: false,
            status: "Downloading",
            speedBytes: 0,
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
