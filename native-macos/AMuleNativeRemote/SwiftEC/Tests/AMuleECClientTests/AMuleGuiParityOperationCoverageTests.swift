import XCTest
@testable import AMuleECClient
@testable import AMuleECProtocol

final class AMuleGuiParityOperationCoverageTests: XCTestCase {
    func testP1AmuleGuiOperationsAreAdvertised() {
        let required = Set([
            "download-stop",
            "download-a4af-this",
            "download-a4af-auto",
            "download-a4af-others",
            "download-set-category",
            "category-update",
            "shared-file-priority",
            "shared-file-comment-rating",
            "server-set-static",
            "server-set-priority",
            "server-info",
            "clear-server-info",
            "reset-log"
        ])

        XCTAssertTrue(required.isSubset(of: Set(ECSupportedOps.allOperations)))
    }
}
