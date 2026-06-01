import XCTest
import AMuleECClient
@testable import AMuleRemoteiOS

final class IOSLocalNetworkErrorPresentationTests: XCTestCase {
    @MainActor
    func testMapsLocalNetworkDeniedError() {
        let presenter = IOSLocalNetworkErrorPresentation()
        let raw = "Operation not permitted while accessing local network"
        let message = presenter.userFacingMessage(for: StubError(message: raw))

        XCTAssertFalse(message.isEmpty)
        XCTAssertNotEqual(message, raw)
    }

    @MainActor
    func testMapsCommonConnectionFailures() {
        let presenter = IOSLocalNetworkErrorPresentation()

        let wrongPassword = presenter.userFacingMessage(for: StubError(message: "wrong password"))
        XCTAssertFalse(wrongPassword.isEmpty)
        XCTAssertNotEqual(wrongPassword, "wrong password")

        let connectionRefused = presenter.userFacingMessage(for: StubError(message: "connection refused"))
        XCTAssertFalse(connectionRefused.isEmpty)
        XCTAssertNotEqual(connectionRefused, "connection refused")

        let timedOut = presenter.userFacingMessage(for: StubError(message: "timed out"))
        XCTAssertFalse(timedOut.isEmpty)
        XCTAssertNotEqual(timedOut, "timed out")

        let invalidPort = presenter.userFacingMessage(for: StubError(message: "invalid port 70000"))
        XCTAssertFalse(invalidPort.isEmpty)
        XCTAssertNotEqual(invalidPort, "invalid port 70000")
    }

    @MainActor
    func testMapsSwiftECConnectionClosedWithoutOpaqueErrorCode() {
        let presenter = IOSLocalNetworkErrorPresentation()

        let message = presenter.userFacingMessage(for: ECSessionError.connectionClosed)

        XCTAssertFalse(message.isEmpty)
        XCTAssertFalse(message.contains("error 3"))
    }
}

private struct StubError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}
