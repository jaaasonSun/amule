import XCTest
@testable import AMuleRemoteiOS

final class SourceDownloadStateTests: XCTestCase {
    func testAllKnownStateCodesMapToCorrectEnum() {
        XCTAssertEqual(SourceDownloadState(rawValue: 1), .connecting)
        XCTAssertEqual(SourceDownloadState(rawValue: 2), .onQueue)
        XCTAssertEqual(SourceDownloadState(rawValue: 4), .downloading)
        XCTAssertEqual(SourceDownloadState(rawValue: 5), .tooManyConnections)
    }

    func testUnknownStateCodeReturnsNil() {
        XCTAssertNil(SourceDownloadState(rawValue: 0))
        XCTAssertNil(SourceDownloadState(rawValue: 3))
        XCTAssertNil(SourceDownloadState(rawValue: 99))
    }

    func testPhoneDownloadsToolbarKeepsFilterAndSortVisible() throws {
        let source = try appSource(named: "DownloadsView.swift")
        let toolbar = try XCTUnwrap(source.range(of: "private var phoneToolbarItems"))
        let padToolbar = try XCTUnwrap(source.range(of: "private var padToolbarItems"))
        let phoneToolbarSource = String(source[toolbar.lowerBound..<padToolbar.lowerBound])

        XCTAssertTrue(phoneToolbarSource.contains("filterMenu"))
        XCTAssertTrue(phoneToolbarSource.contains("sortMenu"))
    }

    func testSettingsDoesNotExposeBridgeImplementationDetails() throws {
        let source = try appSource(named: "SettingsView.swift")

        XCTAssertFalse(source.contains("CapabilitiesSection"))
        XCTAssertFalse(source.contains("Bridge Version"))
        XCTAssertFalse(source.contains("View All Operations"))
        XCTAssertFalse(source.contains("model.bridgeVersion"))
        XCTAssertFalse(source.contains("model.bridgeClientName"))
        XCTAssertFalse(source.contains("model.bridgeDefaultHost"))
        XCTAssertFalse(source.contains("model.bridgeDefaultPort"))
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
