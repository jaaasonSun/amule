import XCTest
@testable import AMuleRemoteiOS

final class RenameVerificationTests: XCTestCase {
    func testRenameIsVerifiedByMatchingHashAndNewName() {
        let downloads = [
            DownloadItemFixtures.download(id: "other", name: "Corrected.mkv"),
            DownloadItemFixtures.download(id: "hash", name: "Corrected.mkv"),
        ]

        XCTAssertTrue(RenameVerification.wasApplied(downloadID: "hash", newName: "Corrected.mkv", downloads: downloads))
    }

    func testRenameIsNotVerifiedWhenNameRemainsUnchanged() {
        let downloads = [
            DownloadItemFixtures.download(id: "hash", name: "Original.mkv"),
        ]

        XCTAssertFalse(RenameVerification.wasApplied(downloadID: "hash", newName: "Corrected.mkv", downloads: downloads))
    }
}
