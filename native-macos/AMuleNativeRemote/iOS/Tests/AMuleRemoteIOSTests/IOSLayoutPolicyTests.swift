import XCTest
@testable import AMuleRemoteIOSShared

final class IOSLayoutPolicyTests: XCTestCase {
    func testPhoneAlwaysUsesDownloadsFirstWithBottomSearch() {
        XCTAssertEqual(IOSLayoutPolicy.rootLayout(device: .phone, horizontalSize: .compact), .downloadsFirst)
        XCTAssertEqual(IOSLayoutPolicy.rootLayout(device: .phone, horizontalSize: .regular), .downloadsFirst)
        XCTAssertEqual(IOSLayoutPolicy.downloadsPresentation(device: .phone, horizontalSize: .regular), .phone)
        XCTAssertEqual(IOSLayoutPolicy.downloadsSearchPlacement(device: .phone, horizontalSize: .regular), .bottomToolbar)
    }

    func testIPadRegularUsesSidebarDetailWithToolbarSearch() {
        XCTAssertEqual(IOSLayoutPolicy.rootLayout(device: .pad, horizontalSize: .regular), .sidebarDetail)
        XCTAssertEqual(IOSLayoutPolicy.downloadsPresentation(device: .pad, horizontalSize: .regular), .pad)
        XCTAssertEqual(IOSLayoutPolicy.downloadsSearchPlacement(device: .pad, horizontalSize: .regular), .toolbarSearchable)
    }

    func testIPadCompactDoesNotStrandUserInSidebarOnlyLayout() {
        XCTAssertEqual(IOSLayoutPolicy.rootLayout(device: .pad, horizontalSize: .compact), .downloadsFirst)
        XCTAssertEqual(IOSLayoutPolicy.downloadsPresentation(device: .pad, horizontalSize: .compact), .phone)
        XCTAssertEqual(IOSLayoutPolicy.downloadsSearchPlacement(device: .pad, horizontalSize: .compact), .bottomToolbar)
    }
}
