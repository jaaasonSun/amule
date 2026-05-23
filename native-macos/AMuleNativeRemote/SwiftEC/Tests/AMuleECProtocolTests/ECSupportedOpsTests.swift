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
            "kad-update-from-url",
            "prefs-connection-get",
            "prefs-connection-set",
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
            "kad-update-from-url",
            "prefs-connection-get",
            "prefs-connection-set",
        ])

        let unauthorizedOperations = ECSupportedOps.allOperations.filter { !canonical.contains($0) }

        XCTAssertEqual(unauthorizedOperations, [])
    }
}
#endif
