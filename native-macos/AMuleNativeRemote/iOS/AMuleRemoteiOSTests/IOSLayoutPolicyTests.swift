import XCTest
@testable import AMuleRemoteiOS

final class IOSLayoutPolicyTests: XCTestCase {
    func testCompactPhoneUsesTabViewRootLayout() {
        XCTAssertEqual(IOSLayoutPolicy.rootLayout(device: .phone, horizontalSize: .compact), .tabView)
    }

    func testCompactPadUsesTabViewRootLayout() {
        XCTAssertEqual(IOSLayoutPolicy.rootLayout(device: .pad, horizontalSize: .compact), .tabView)
    }

    func testRegularPadUsesAdaptiveTabRootLayout() {
        XCTAssertEqual(IOSLayoutPolicy.rootLayout(device: .pad, horizontalSize: .regular), .tabView)
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

    func testIPadRegularUsesAdaptiveTabsWithToolbarSearch() {
        XCTAssertEqual(IOSLayoutPolicy.downloadsPresentation(device: .pad, horizontalSize: .regular), .pad)
        XCTAssertEqual(IOSLayoutPolicy.downloadsSearchPlacement(device: .pad, horizontalSize: .regular), .toolbarSearchable)
    }

    func testIPadCompactDoesNotStrandUserInSidebarOnlyLayout() {
        XCTAssertEqual(IOSLayoutPolicy.rootLayout(device: .pad, horizontalSize: .compact), .tabView)
        XCTAssertEqual(IOSLayoutPolicy.downloadsPresentation(device: .pad, horizontalSize: .compact), .phone)
        XCTAssertEqual(IOSLayoutPolicy.downloadsSearchPlacement(device: .pad, horizontalSize: .compact), .navigationBarDrawer)
    }

    func testContentViewUsesSystemAdaptiveTabsForIPadSidebar() throws {
        let source = try appSource(named: "ContentView.swift")

        XCTAssertTrue(source.contains(".tabViewStyle(.sidebarAdaptable)"))
        XCTAssertTrue(source.contains("@AppStorage(\"amule.ios.tabCustomization\")"))
        XCTAssertTrue(source.contains(".tabViewCustomization($tabCustomization)"))
        XCTAssertTrue(source.contains("role: .search"))
        XCTAssertFalse(source.contains("NavigationSplitView"))
        XCTAssertFalse(source.contains("List(AppTab.allCases)"))
    }

    func testAppTabsExposeStableCustomizationIdentifiers() {
        XCTAssertEqual(AppTab.downloads.customizationID, "downloads")
        XCTAssertEqual(AppTab.search.customizationID, "search")
        XCTAssertEqual(AppTab.servers.customizationID, "servers")
        XCTAssertEqual(AppTab.settings.customizationID, "settings")
    }

    private func appSource(named fileName: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let sourceURL = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AMuleRemoteiOS")
            .appendingPathComponent(fileName)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
