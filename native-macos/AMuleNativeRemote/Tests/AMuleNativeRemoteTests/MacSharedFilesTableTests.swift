import XCTest
import AMuleECBridgeAdapter
@testable import AMuleNativeRemote

@MainActor
final class MacSharedFilesTableTests: XCTestCase {
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

    func testSharedFilesSourceUsesDenseTableWorkflow() throws {
        let source = try source("Sources/AMuleNativeRemote/SharedFilesWindowView.swift")

        XCTAssertTrue(source.contains("Table(filteredSharedFileRows"), "Shared Files should render the populated workflow with a SwiftUI Table.")
        XCTAssertFalse(source.contains("List("), "Shared Files should not keep the oversized List row workflow.")
        XCTAssertTrue(source.contains("@State private var selectedSharedFileIDs"), "Shared Files should keep table selection state.")
        XCTAssertTrue(source.contains("@State private var sharedFileSortOrder"), "Shared Files should keep sortable table state.")
        XCTAssertTrue(source.contains("@State private var sharedFileFilterQuery"), "Shared Files should keep filter/search state.")
        XCTAssertTrue(source.contains(".searchable(text: $sharedFileFilterQuery"), "Shared Files should expose native toolbar filtering.")
        XCTAssertTrue(source.contains("sharedFileRowIdentifier(file: file, offset: offset)"), "Shared Files should retain deterministic row identity for duplicate names and empty hashes.")

        [
            "Name",
            "Size",
            "Path/Location",
            "Priority",
            "Rating/Comment",
            "Requests",
            "Accepted",
            "Transferred",
            "Complete Sources"
        ].forEach { title in
            XCTAssertTrue(source.contains("L(\"\(title)\")"), "Missing Shared Files table column: \(title)")
        }

        [
            "Refresh",
            "Reload",
            "Edit Comment and Rating",
            "Copy eD2k Link",
            "Priority"
        ].forEach { action in
            XCTAssertTrue(source.contains("L(\"\(action)\")"), "Missing visible Shared Files action: \(action)")
        }

        XCTAssertTrue(source.contains("sharedFileContextMenu"), "Existing Shared Files context menu actions should remain available.")
        XCTAssertTrue(source.contains("model.setSharedFilePriority"), "Priority bridge operation should remain wired.")
        XCTAssertTrue(source.contains("model.setSharedFileCommentRating"), "Comment/rating bridge operation should remain wired.")
        XCTAssertTrue(source.contains("model.pasteboardShare.writeString"), "Copy eD2k should remain wired to pasteboard sharing.")
    }

    func testSharedFilesNewVisibleStringsAreLocalized() throws {
        let zhHans = try source("Resources/zh-Hans.lproj/Localizable.strings")
        let zhCN = try source("Resources/zh_CN.lproj/Localizable.strings")

        [
            "Path/Location",
            "Rating/Comment",
            "Requests",
            "Accepted",
            "Complete Sources",
            "Filter Shared Files",
            "No shared files available",
            "Refresh shared files from the remote daemon.",
            "No matching shared files",
            "Adjust the Shared Files filter.",
            "%lld shared file(s)",
            "%lld of %lld shown",
            "Very Low",
            "Very High",
            "Edit Comment and Rating",
            "Refresh Shared Files",
            "Reload Shared Files"
        ].forEach { key in
            XCTAssertTrue(zhHans.contains("\"\(key)\" ="), "zh-Hans missing localization key: \(key)")
            XCTAssertTrue(zhCN.contains("\"\(key)\" ="), "zh_CN missing localization key: \(key)")
        }
    }

    func testPopulatedSharedFilesTableRendersDenseRows() throws {
        let model = sharedFilesModel()
        let evidenceURL = evidenceRoot.appendingPathComponent("shared-files-populated.png")

        try writeRenderedSurface(
            SharedFilesWindowView(embeddedInMainWindow: true).environmentObject(model),
            size: CGSize(width: 1560, height: 560),
            to: evidenceURL
        )
    }

    func testSharedFilesTableRendersEmptyFilteredEmptyAndSelectedStates() throws {
        let emptyModel = sharedFilesModel(files: [])
        try writeRenderedSurface(
            SharedFilesWindowView(embeddedInMainWindow: true).environmentObject(emptyModel),
            size: CGSize(width: 1560, height: 560),
            to: evidenceRoot.appendingPathComponent("shared-files-empty.png")
        )

        let populatedModel = sharedFilesModel()
        try writeRenderedSurface(
            SharedFilesWindowView(embeddedInMainWindow: true, initialFilterQuery: "definitely-no-match")
                .environmentObject(populatedModel),
            size: CGSize(width: 1560, height: 560),
            to: evidenceRoot.appendingPathComponent("shared-files-filtered-empty.png")
        )

        let selectedID = sharedFileRowIdentifier(file: populatedModel.sharedFiles[1], offset: 1)
        try writeRenderedSurface(
            SharedFilesWindowView(
                embeddedInMainWindow: true,
                initialSelectedSharedFileIDs: [selectedID]
            )
            .environmentObject(populatedModel),
            size: CGSize(width: 1560, height: 560),
            to: evidenceRoot.appendingPathComponent("shared-files-selected.png")
        )
    }

    private var evidenceRoot: URL {
        repositoryRoot(from: packageRoot)
            .appendingPathComponent(".sisyphus/evidence/task-3-shared-files-table")
    }

    private func sharedFilesModel(files: [BridgeSharedFilePayload]? = nil) -> AppModel {
        let bridge = FakeBridgeAdapter()
        bridge.capabilityOps = Set([
            "shared-files",
            "shared-files-reload",
            "shared-file-priority",
            "shared-file-comment-rating"
        ])
        let model = AppModel(bridge: bridge, credentialStorage: PlatformServiceStubs.Credentials())
        model.bridgeOps = bridge.capabilityOps
        model.sharedFiles = files ?? [
            sharedFile(
                hash: "00112233445566778899AABBCCDDEEFF",
                name: "Ubuntu Server 27.04.iso",
                path: "/Volumes/Incoming/Linux/Ubuntu Server 27.04.iso",
                size: 2_147_483_648,
                priority: 5,
                requests: 18,
                requestsAll: 94,
                accepts: 14,
                acceptsAll: 80,
                xferred: 734_003_200,
                xferredAll: 3_221_225_472,
                completeSources: 12,
                completeSourcesLow: 8,
                completeSourcesHigh: 16,
                comment: "Verified release",
                rating: 4
            ),
            sharedFile(
                hash: "",
                name: "Concert Recording.flac",
                path: "35.partfile",
                size: 734_003_200,
                priority: 7,
                requests: 4,
                requestsAll: 22,
                accepts: 3,
                acceptsAll: 19,
                xferred: 67_108_864,
                xferredAll: 402_653_184,
                completeSources: 3,
                completeSourcesLow: 1,
                completeSourcesHigh: 5,
                comment: nil,
                rating: 2
            ),
            sharedFile(
                hash: "FFEEDDCCBBAA99887766554433221100",
                name: "Archive.zip",
                path: "/Volumes/Incoming/Archive.zip",
                size: 98_566_144,
                priority: 10,
                requests: 0,
                requestsAll: 9,
                accepts: 0,
                acceptsAll: 7,
                xferred: 0,
                xferredAll: 12_582_912,
                completeSources: 0,
                completeSourcesLow: 0,
                completeSourcesHigh: 0,
                comment: "",
                rating: nil
            )
        ]
        return model
    }

    private func sharedFile(
        hash: String,
        name: String,
        path: String,
        size: UInt64,
        priority: Int,
        requests: Int,
        requestsAll: Int,
        accepts: Int,
        acceptsAll: Int,
        xferred: UInt64,
        xferredAll: UInt64,
        completeSources: Int,
        completeSourcesLow: Int,
        completeSourcesHigh: Int,
        comment: String?,
        rating: Int?
    ) -> BridgeSharedFilePayload {
        BridgeSharedFilePayload(
            hash: hash,
            name: name,
            path: path,
            size: size,
            ed2kLink: "ed2k://|file|\(name)|\(size)|00112233445566778899AABBCCDDEEFF|/",
            priority: priority,
            requests: requests,
            requestsAll: requestsAll,
            accepts: accepts,
            acceptsAll: acceptsAll,
            xferred: xferred,
            xferredAll: xferredAll,
            onQueue: 0,
            completeSources: completeSources,
            completeSourcesLow: completeSourcesLow,
            completeSourcesHigh: completeSourcesHigh,
            comment: comment,
            rating: rating
        )
    }

    private func source(_ relativePath: String) throws -> String {
        let url = packageRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
