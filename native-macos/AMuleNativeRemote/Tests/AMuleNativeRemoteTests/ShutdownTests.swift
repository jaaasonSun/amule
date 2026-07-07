import XCTest
import AMuleECBridgeAdapter
@testable import AMuleNativeRemote

@MainActor
final class ShutdownTests: XCTestCase {
    func testShutdownInvokesBridgeAndDisconnects() async throws {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["shutdown"])
        let model = AppModel(bridge: bridge, credentialStorage: PlatformServiceStubs.Credentials())
        model.bridgeOps = bridge.capabilityOps
        model.isSessionConnected = true

        model.shutdownDaemon()

        try await waitUntil {
            bridge.invokedOperations.contains("shutdown") && !model.isSessionConnected
        }
        XCTAssertFalse(model.isSessionConnected)
    }

    func testShutdownGatedByCapability() async throws {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["status"])
        let model = AppModel(bridge: bridge, credentialStorage: PlatformServiceStubs.Credentials())
        model.bridgeOps = bridge.capabilityOps
        model.isSessionConnected = true

        model.shutdownDaemon()

        try await waitUntil {
            !model.lastError.isEmpty
        }
        XCTAssertTrue(model.lastError.contains("not supported"))
        XCTAssertTrue(model.isSessionConnected)
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 2_000_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now.advanced(by: .nanoseconds(Int(timeoutNanoseconds)))
        while ContinuousClock.now < deadline {
            if condition() { return }
            await Task.yield()
        }
        XCTFail("Timed out waiting for condition")
    }
}
