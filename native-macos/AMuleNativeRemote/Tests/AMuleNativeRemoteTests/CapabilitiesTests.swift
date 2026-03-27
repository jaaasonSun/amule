import XCTest
@testable import AMuleNativeRemote

final class CapabilitiesTests: XCTestCase {
    func testDecodeCapabilitiesEnvelope() throws {
        let json = #"{"ok":true,"schema_version":1,"capabilities":{"bridge_version":"GIT","client_name":"aMuleNativeBridge","default_host":"127.0.0.1","default_port":4712,"ops":["status","capabilities"]}}"#
        let data = try XCTUnwrap(json.data(using: .utf8))

        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        XCTAssertTrue(decoded.ok)
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.capabilities?.clientName, "aMuleNativeBridge")
        XCTAssertEqual(decoded.capabilities?.defaultHost, "127.0.0.1")
        XCTAssertEqual(decoded.capabilities?.defaultPort, 4712)
        XCTAssertEqual(decoded.capabilities?.ops, ["status", "capabilities"])
    }

    @MainActor
    func testGatingDoesNotSetLastError() {
        let model = AppModel()
        model.lastError = "previous"
        model.bridgeOps = ["status", "downloads", "capabilities"]

        XCTAssertFalse(model.isBridgeOpSupported("uploads"))
        XCTAssertEqual(model.lastError, "previous")
    }
}
