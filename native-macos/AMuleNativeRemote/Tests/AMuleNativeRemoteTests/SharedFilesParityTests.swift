import XCTest
import AMuleECBridgeAdapter
@testable import AMuleNativeRemote

@MainActor
final class SharedFilesParityTests: XCTestCase {
    private var packageRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.lastPathComponent != "AMuleNativeRemote" {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path {
                XCTFail("Could not locate AMuleNativeRemote package root from \(#filePath)")
                return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            }
            url = parent
        }
        return url
    }

    func testSharedFilesSurfaceRendersDistinctRowsForPartfileBackedEntries() throws {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set(["shared-files"])
        let model = AppModel(bridge: bridge, credentialStorage: PlatformServiceStubs.Credentials())
        model.bridgeOps = bridge.capabilityOps
        model.sharedFiles = [
            sharedFile(hash: "", name: "Ubuntu.iso", path: "34.partfile"),
            sharedFile(hash: "", name: "Movie.mkv", path: "35.partfile"),
            sharedFile(hash: "", name: "Archive.zip", path: "36.partfile")
        ]

        XCTAssertEqual(model.sharedFiles.map(\.name), ["Ubuntu.iso", "Movie.mkv", "Archive.zip"])

        let evidenceURL = repositoryRoot(from: packageRoot)
            .appendingPathComponent(".omo/evidence/shared-stats-crash-20260708/shared-files-surface.png")
        try writeRenderedSurface(
            SharedFilesWindowView(embeddedInMainWindow: true).environmentObject(model),
            size: CGSize(width: 780, height: 520),
            to: evidenceURL
        )
    }

    func testSharedFilesRowIdentityKeepsPartfileBackedEntriesDistinctWhenHashesAreEmpty() {
        let files = [
            sharedFile(hash: "", name: "Ubuntu.iso", path: "34.partfile"),
            sharedFile(hash: "", name: "Movie.mkv", path: "35.partfile"),
            sharedFile(hash: "", name: "Archive.zip", path: "36.partfile")
        ]

        let identifiers = files.enumerated().map { offset, file in
            sharedFileRowIdentifier(file: file, offset: offset)
        }

        XCTAssertEqual(Set(identifiers).count, files.count)
        XCTAssertEqual(identifiers[0], "0||34.partfile|Ubuntu.iso")
        XCTAssertEqual(identifiers[1], "1||35.partfile|Movie.mkv")
        XCTAssertEqual(identifiers[2], "2||36.partfile|Archive.zip")
    }

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

    private func sharedFile(hash: String, name: String, path: String) -> BridgeSharedFilePayload {
        BridgeSharedFilePayload(
            hash: hash,
            name: name,
            path: path,
            size: 1_048_576,
            ed2kLink: "ed2k://|file|\(name)|1048576|00112233445566778899AABBCCDDEEFF|/",
            priority: 5,
            requests: 0,
            requestsAll: 0,
            accepts: 0,
            acceptsAll: 0,
            xferred: 0,
            xferredAll: 0,
            onQueue: 0,
            completeSources: 0,
            completeSourcesLow: 0,
            completeSourcesHigh: 0,
            comment: nil,
            rating: nil
        )
    }
}
