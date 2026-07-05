#if canImport(XCTest) && canImport(AMuleECProtocol)
import XCTest
@testable import AMuleECProtocol

final class ECSupportedOpsTests: XCTestCase {
    /// Verifies Swift allOperations matches the native V1 operation surface exactly.
    func testAllOperationsMatchCanonicalFixture() {
        let expected = [
            "capabilities",
            "status",
            "downloads",
            "sources",
            "search",
            "search-stop",
            "download",
            "add-link",
            "rename",
            "connect",
            "disconnect",
            "pause",
            "resume",
            "download-stop",
            "download-a4af-this",
            "download-a4af-auto",
            "download-a4af-others",
            "cancel",
            "priority",
            "download-set-category",
            "clear-completed",
            "servers",
            "server-connect",
            "server-disconnect",
            "server-add",
            "server-remove",
            "server-update-from-url",
            "server-set-static",
            "server-set-priority",
            "server-info",
            "clear-server-info",
            "kad-start",
            "kad-stop",
            "kad-bootstrap",
            "kad-update-from-url",
            "prefs-connection-get",
            "prefs-connection-set",
            "uploads",
            "shared-files",
            "shared-files-reload",
            "shared-file-priority",
            "shared-file-comment-rating",
            "log",
            "debug-log",
            "reset-log",
            "categories",
            "category-create",
            "category-update",
            "category-delete",
            "ipfilter-reload",
            "ipfilter-update",
            "friends",
            "friend-remove",
            "friend-slot",
            "stats-tree",
            "stats-graphs",
        ]

        XCTAssertEqual(ECSupportedOps.allOperations, expected)
    }

    /// Verifies no operations exist beyond the canonical V1 list.
    func testNoUnauthorizedOperations() {
        let canonical = Set([
            "capabilities",
            "status",
            "downloads",
            "sources",
            "search",
            "search-stop",
            "download",
            "add-link",
            "rename",
            "connect",
            "disconnect",
            "pause",
            "resume",
            "download-stop",
            "download-a4af-this",
            "download-a4af-auto",
            "download-a4af-others",
            "cancel",
            "priority",
            "download-set-category",
            "clear-completed",
            "servers",
            "server-connect",
            "server-disconnect",
            "server-add",
            "server-remove",
            "server-update-from-url",
            "server-set-static",
            "server-set-priority",
            "server-info",
            "clear-server-info",
            "kad-start",
            "kad-stop",
            "kad-bootstrap",
            "kad-update-from-url",
            "prefs-connection-get",
            "prefs-connection-set",
            "uploads",
            "shared-files",
            "shared-files-reload",
            "shared-file-priority",
            "shared-file-comment-rating",
            "log",
            "debug-log",
            "reset-log",
            "categories",
            "category-create",
            "category-update",
            "category-delete",
            "ipfilter-reload",
            "ipfilter-update",
            "friends",
            "friend-remove",
            "friend-slot",
            "stats-tree",
            "stats-graphs",
        ])

        let unauthorizedOperations = ECSupportedOps.allOperations.filter { !canonical.contains($0) }

        XCTAssertEqual(unauthorizedOperations, [])
    }

    func testUnsupportedDisabledOperationsAreNotAdvertised() {
        XCTAssertEqual(ECSupportedOps.unsupportedDisabledOperations, [])

        for operation in ECSupportedOps.unsupportedDisabledOperations {
            XCTAssertFalse(ECSupportedOps.allOperations.contains(operation), operation)
        }
    }
}
#endif
