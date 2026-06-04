import XCTest
@testable import AMuleRemoteiOS

final class IOSLayoutPolicyTests: XCTestCase {
    func testCompactPhoneUsesTabViewRootLayout() {
        XCTAssertEqual(IOSLayoutPolicy.rootLayout(device: .phone, horizontalSize: .compact), .tabView)
    }

    func testCompactPadUsesTabViewRootLayout() {
        XCTAssertEqual(IOSLayoutPolicy.rootLayout(device: .pad, horizontalSize: .compact), .tabView)
    }

    func testRegularPadKeepsSidebarDetailLayout() {
        XCTAssertEqual(IOSLayoutPolicy.rootLayout(device: .pad, horizontalSize: .regular), .sidebarDetail)
    }

    func testCompactPhoneUsesNavigationBarDrawerSearch() {
        XCTAssertEqual(IOSLayoutPolicy.downloadsSearchPlacement(device: .phone, horizontalSize: .compact), .navigationBarDrawer)
    }

    func testCompactPadUsesNavigationBarDrawerSearch() {
        XCTAssertEqual(IOSLayoutPolicy.downloadsSearchPlacement(device: .pad, horizontalSize: .compact), .navigationBarDrawer)
    }

    func testRegularPadKeepsToolbarSearchable() {
        XCTAssertEqual(IOSLayoutPolicy.downloadsSearchPlacement(device: .pad, horizontalSize: .regular), .toolbarSearchable)
    }

    func testAppTabsExposePrimarySectionsInStableOrder() {
        XCTAssertEqual(AppTab.allCases, [.downloads, .search, .servers, .settings])
    }

    func testPhoneAlwaysUsesTabViewWithNavigationBarDrawerSearch() {
        XCTAssertEqual(IOSLayoutPolicy.rootLayout(device: .phone, horizontalSize: .regular), .tabView)
        XCTAssertEqual(IOSLayoutPolicy.downloadsPresentation(device: .phone, horizontalSize: .regular), .phone)
        XCTAssertEqual(IOSLayoutPolicy.downloadsSearchPlacement(device: .phone, horizontalSize: .regular), .navigationBarDrawer)
    }

    func testIPadRegularUsesSidebarDetailWithToolbarSearch() {
        XCTAssertEqual(IOSLayoutPolicy.downloadsPresentation(device: .pad, horizontalSize: .regular), .pad)
        XCTAssertEqual(IOSLayoutPolicy.downloadsSearchPlacement(device: .pad, horizontalSize: .regular), .toolbarSearchable)
    }

    func testIPadCompactDoesNotStrandUserInSidebarOnlyLayout() {
        XCTAssertEqual(IOSLayoutPolicy.rootLayout(device: .pad, horizontalSize: .compact), .tabView)
        XCTAssertEqual(IOSLayoutPolicy.downloadsPresentation(device: .pad, horizontalSize: .compact), .phone)
        XCTAssertEqual(IOSLayoutPolicy.downloadsSearchPlacement(device: .pad, horizontalSize: .compact), .navigationBarDrawer)
    }
}
