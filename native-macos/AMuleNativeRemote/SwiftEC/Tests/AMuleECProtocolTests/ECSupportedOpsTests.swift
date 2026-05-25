#if canImport(XCTest) && canImport(AMuleECProtocol)
import XCTest
@testable import AMuleECProtocol

final class ECSupportedOpsTests: XCTestCase {
    /// Verifies Swift allOperations matches C++ SupportedOps() exactly.
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
            "cancel",
            "priority",
            "clear-completed",
            "servers",
            "server-connect",
            "server-disconnect",
            "server-add",
            "server-remove",
            "server-update-from-url",
            "kad-start",
            "kad-stop",
            "kad-bootstrap",
            "kad-update-from-url",
            "prefs-connection-get",
            "prefs-connection-set",
            "uploads",
            "shared-files",
            "shared-files-reload",
            "log",
            "debug-log",
            "categories",
            "category-create",
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
            "cancel",
            "priority",
            "clear-completed",
            "servers",
            "server-connect",
            "server-disconnect",
            "server-add",
            "server-remove",
            "server-update-from-url",
            "kad-start",
            "kad-stop",
            "kad-bootstrap",
            "kad-update-from-url",
            "prefs-connection-get",
            "prefs-connection-set",
            "uploads",
            "shared-files",
            "shared-files-reload",
            "log",
            "debug-log",
            "categories",
            "category-create",
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
        XCTAssertEqual(ECSupportedOps.unsupportedDisabledOperations, [
            "category-update",
            "download-set-category",
        ])

        for operation in ECSupportedOps.unsupportedDisabledOperations {
            XCTAssertFalse(ECSupportedOps.allOperations.contains(operation), operation)
        }
    }
}
#endif
