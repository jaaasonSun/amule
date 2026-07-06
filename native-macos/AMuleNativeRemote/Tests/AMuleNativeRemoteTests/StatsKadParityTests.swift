import XCTest
@testable import AMuleNativeRemote

final class StatsKadParityTests: XCTestCase {
    func testKadStatusSummaryKeepsEd2kAndKadSeparate() {
        let summary = NetworkStatusSummary(ed2k: "Connected HighID", kad: "Connected")
        XCTAssertEqual(summary.ed2k, "Connected HighID")
        XCTAssertEqual(summary.kad, "Connected")
    }
}
