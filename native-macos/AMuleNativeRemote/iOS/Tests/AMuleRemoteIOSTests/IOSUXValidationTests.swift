import XCTest
@testable import AMuleRemoteIOSShared

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
}