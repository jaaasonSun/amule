import XCTest
import AMuleECClient
@testable import AMuleRemoteIOSShared

final class IOSLocalNetworkErrorPresentationTests: XCTestCase {
    @MainActor
    func testMapsLocalNetworkDeniedError() {
        let presenter = IOSLocalNetworkErrorPresentation()

        XCTAssertTrue(
            presenter.userFacingMessage(for: StubError(message: "Operation not permitted while accessing local network"))
                .contains("This app needs local network access to connect to aMule")
        )
    }

    @MainActor
    func testMapsCommonConnectionFailures() {
        let presenter = IOSLocalNetworkErrorPresentation()

        XCTAssertTrue(presenter.userFacingMessage(for: StubError(message: "wrong password")).contains("Incorrect password"))
        XCTAssertTrue(presenter.userFacingMessage(for: StubError(message: "connection refused")).contains("Cannot connect to aMule daemon"))
        XCTAssertTrue(presenter.userFacingMessage(for: StubError(message: "timed out")).contains("Connection timed out"))
        XCTAssertTrue(presenter.userFacingMessage(for: StubError(message: "invalid port 70000")).contains("Invalid port"))
    }

    @MainActor
    func testMapsSwiftECConnectionClosedWithoutOpaqueErrorCode() {
        let presenter = IOSLocalNetworkErrorPresentation()

        let message = presenter.userFacingMessage(for: ECSessionError.connectionClosed)

        XCTAssertTrue(message.contains("Connection closed"))
        XCTAssertFalse(message.contains("error 3"))
    }
}

private struct StubError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}
