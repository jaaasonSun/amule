import XCTest
import AMuleECBridgeAdapter
@testable import AMuleNativeRemote

@MainActor
final class ServersParityTests: XCTestCase {
    func testSetServerStaticInvokesBridgeAndRefreshesServers() async throws {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["server-set-static", "servers"])
        let model = AppModel(bridge: bridge, credentialStorage: PlatformServiceStubs.Credentials())
        model.bridgeOps = bridge.capabilityOps

        model.setServerStatic(ecid: 42, isStatic: true)

        try await waitUntil {
            bridge.invokedOperations.contains("server-set-static") &&
                bridge.invokedOperations.contains("servers")
        }
        XCTAssertEqual(bridge.lastServerStaticECID, 42)
        XCTAssertEqual(bridge.lastServerStatic, true)
    }

    func testSetServerPriorityInvokesBridgeAndRefreshesServers() async throws {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["server-set-priority", "servers"])
        let model = AppModel(bridge: bridge, credentialStorage: PlatformServiceStubs.Credentials())
        model.bridgeOps = bridge.capabilityOps

        model.setServerPriority(ecid: 42, priority: 2)

        try await waitUntil {
            bridge.invokedOperations.contains("server-set-priority") &&
                bridge.invokedOperations.contains("servers")
        }
        XCTAssertEqual(bridge.lastServerPriorityECID, 42)
        XCTAssertEqual(bridge.lastServerPriority, 2)
    }

    func testRefreshServerInfoCapturesLinesAndRawOutput() async throws {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["server-info"])
        bridge.serverInfoResult = (
            BridgeCoreLogPayload(kind: "server-info", lines: ["server log"]),
            #"{"ok":true,"log":{"kind":"server-info","lines":["server log"]}}"#
        )
        let model = AppModel(bridge: bridge, credentialStorage: PlatformServiceStubs.Credentials())
        model.bridgeOps = bridge.capabilityOps

        model.refreshServerInfo()

        try await waitUntil {
            bridge.invokedOperations.contains("server-info") &&
                model.serverInfoLines == ["server log"]
        }
        XCTAssertEqual(
            model.lastServerInfoRawOutput,
            #"{"ok":true,"log":{"kind":"server-info","lines":["server log"]}}"#
        )
    }

    func testClearServerInfoInvokesBridgeAndClearsLines() async throws {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["clear-server-info"])
        let model = AppModel(bridge: bridge, credentialStorage: PlatformServiceStubs.Credentials())
        model.bridgeOps = bridge.capabilityOps
        model.serverInfoLines = ["stale server log"]
        model.lastServerInfoRawOutput = "stale raw output"

        model.clearServerInfo()

        try await waitUntil {
            bridge.invokedOperations.contains("clear-server-info") &&
                model.serverInfoLines.isEmpty
        }
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
