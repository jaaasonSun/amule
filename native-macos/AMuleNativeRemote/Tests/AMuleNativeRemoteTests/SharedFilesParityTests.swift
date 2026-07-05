import XCTest
@testable import AMuleNativeRemote

@MainActor
final class SharedFilesParityTests: XCTestCase {
    func testSetSharedFilePriorityInvokesBridgeAndRefreshesSharedFiles() async throws {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["shared-file-priority", "shared-files"])
        let model = AppModel(bridge: bridge, credentialStorage: PlatformServiceStubs.Credentials())
        model.bridgeOps = bridge.capabilityOps

        model.setSharedFilePriority(hash: "00112233445566778899AABBCCDDEEFF", priority: 7)

        try await waitUntil {
            bridge.invokedOperations.contains("shared-file-priority") &&
                bridge.invokedOperations.contains("shared-files")
        }
        XCTAssertEqual(bridge.lastSharedFilePriority, 7)
        XCTAssertEqual(bridge.lastSharedFilePriorityHash, "00112233445566778899AABBCCDDEEFF")
    }

    func testSetSharedFileCommentRatingInvokesBridgeAndRefreshesSharedFiles() async throws {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["shared-file-comment-rating", "shared-files"])
        let model = AppModel(bridge: bridge, credentialStorage: PlatformServiceStubs.Credentials())
        model.bridgeOps = bridge.capabilityOps

        model.setSharedFileCommentRating(
            hash: "FFEEDDCCBBAA99887766554433221100",
            comment: "Verified release",
            rating: 4
        )

        try await waitUntil {
            bridge.invokedOperations.contains("shared-file-comment-rating") &&
                bridge.invokedOperations.contains("shared-files")
        }
        XCTAssertEqual(bridge.lastSharedFileCommentHash, "FFEEDDCCBBAA99887766554433221100")
        XCTAssertEqual(bridge.lastSharedFileComment, "Verified release")
        XCTAssertEqual(bridge.lastSharedFileRating, 4)
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
