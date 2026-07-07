import XCTest
@testable import AMuleNativeRemote

@MainActor
final class FriendsMessagesTests: XCTestCase {
    func testFriendInputValidationAcceptsValidInput() throws {
        let request = try FriendAddInput(
            hash: "00112233445566778899aabbccddeeff",
            ip: "1.2.3.4",
            port: "4662",
            name: " Alice "
        ).validated()

        XCTAssertEqual(request.hash, "00112233445566778899aabbccddeeff")
        XCTAssertEqual(request.ip, "1.2.3.4")
        XCTAssertEqual(request.port, 4662)
        XCTAssertEqual(request.name, "Alice")
    }

    func testFriendInputValidationKeepsSpecificErrors() {
        XCTAssertThrowsError(try FriendAddInput(hash: "bad", ip: "1.2.3.4", port: "4662", name: "").validated()) { error in
            XCTAssertEqual(error as? FriendAddInput.ValidationError, .invalidHash)
        }

        XCTAssertThrowsError(try FriendAddInput(hash: "00112233445566778899aabbccddeeff", ip: "999.2.3.4", port: "4662", name: "").validated()) { error in
            XCTAssertEqual(error as? FriendAddInput.ValidationError, .invalidIP)
        }

        XCTAssertThrowsError(try FriendAddInput(hash: "00112233445566778899aabbccddeeff", ip: "1.2.3.4", port: "not-a-port", name: "").validated()) { error in
            XCTAssertEqual(error as? FriendAddInput.ValidationError, .invalidPort)
        }
    }

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

    func testRequestFriendSharedListIsNotAdvertised() {
        let bridge = FakeBridgeAdapter()
        let model = AppModel(bridge: bridge, credentialStorage: PlatformServiceStubs.Credentials())
        model.bridgeOps = Set(["friends", "friend-add", "friend-remove", "friend-slot"])

        model.requestFriendSharedList(id: 11)

        XCTAssertFalse(model.isBusy)
        XCTAssertFalse(bridge.invokedOperations.contains("friend-shared"))
        XCTAssertNil(bridge.lastFriendSharedListID)
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
