import Foundation
import XCTest

final class MacNetworkPrivacyPackagingTests: XCTestCase {
    func testMacAppDeclaresLocalNetworkUsage() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let infoPlistURL = packageRoot
            .appendingPathComponent("Sources/AMuleNativeRemote/Info.plist")
        let data = try Data(contentsOf: infoPlistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        let usageDescription = try XCTUnwrap(plist["NSLocalNetworkUsageDescription"] as? String)

        XCTAssertFalse(usageDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
