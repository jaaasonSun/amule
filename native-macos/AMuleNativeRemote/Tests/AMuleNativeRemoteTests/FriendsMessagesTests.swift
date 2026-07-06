import XCTest
@testable import AMuleNativeRemote

@MainActor
final class FriendsMessagesTests: XCTestCase {
    func testAddFriendInvokesBridgeAndRefreshesFriends() async throws {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["friend-add", "friends"])
        let model = AppModel(bridge: bridge, credentialStorage: PlatformServiceStubs.Credentials())
        model.bridgeOps = bridge.capabilityOps

        model.addFriend(hash: "00112233445566778899aabbccddeeff", ip: "1.2.3.4", port: "4662", name: "Alice")

        try await waitUntil {
            bridge.invokedOperations.contains("friend-add") &&
                bridge.invokedOperations.contains("friends")
        }
        XCTAssertEqual(bridge.lastFriendAdd?.hash, "00112233445566778899aabbccddeeff")
        XCTAssertEqual(bridge.lastFriendAdd?.ip, "1.2.3.4")
        XCTAssertEqual(bridge.lastFriendAdd?.port, 4662)
        XCTAssertEqual(bridge.lastFriendAdd?.name, "Alice")
    }

    func testAddFriendRejectsInvalidPortWithoutCallingBridge() {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["friend-add"])
        let model = AppModel(bridge: bridge, credentialStorage: PlatformServiceStubs.Credentials())
        model.bridgeOps = bridge.capabilityOps

        model.addFriend(hash: "00112233445566778899aabbccddeeff", ip: "1.2.3.4", port: "not-a-port", name: "Alice")

        XCTAssertEqual(model.lastError, "Friend port must be between 1 and 65535.")
        XCTAssertFalse(bridge.invokedOperations.contains("friend-add"))
    }

    func testRequestFriendSharedListInvokesBridge() async throws {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["friend-shared"])
        let model = AppModel(bridge: bridge, credentialStorage: PlatformServiceStubs.Credentials())
        model.bridgeOps = bridge.capabilityOps

        model.requestFriendSharedList(id: 11)

        try await waitUntil {
            bridge.invokedOperations.contains("friend-shared")
        }
        XCTAssertEqual(bridge.lastFriendSharedListID, 11)
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
