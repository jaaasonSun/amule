import XCTest
import SharedModels
@testable import AMuleNativeRemote

@MainActor
final class DownloadSourcesDetailParityTests: XCTestCase {
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

    func testDownloadDetailsSurfaceUsesOnlySelectedDownloadSources() throws {
        let bridge = FakeBridgeAdapter()
        let model = AppModel(bridge: bridge, credentialStorage: PlatformServiceStubs.Credentials())
        let first = download(hash: "FIRSTDOWNLOAD0000000000000000000001", ecid: 42, name: "First.iso")
        let second = download(hash: "SECONDDOWNLOAD00000000000000000002", ecid: 77, name: "Second.iso")
        model.downloads = [first, second]
        model.selectedDownloadID = first.id
        model.downloadSourcesByHash[first.id] = [
            source(id: 99, requestFileID: first.ecid, name: "first-peer")
        ]
        model.downloadSourcesByHash[second.id] = [
            source(id: 100, requestFileID: second.ecid, name: "second-peer")
        ]

        XCTAssertEqual(model.sources(for: first).map(\.clientName), ["first-peer"])
        XCTAssertEqual(model.sources(for: second).map(\.clientName), ["second-peer"])
        XCTAssertEqual(model.sources(for: first).first?.versionDisplay, "2.3.3")
        XCTAssertEqual(model.sources(for: first).first?.remoteFilename, "remote-first-peer.iso")

        let evidenceURL = repositoryRoot(from: packageRoot)
            .appendingPathComponent(".omo/evidence/download-sources-empty-20260708/download-details-sources-visible.png")
        try writeRenderedSurface(
            DownloadDetailsWindowView().environmentObject(model),
            size: CGSize(width: 920, height: 520),
            to: evidenceURL
        )
    }

    private func download(hash: String, ecid: Int, name: String) -> DownloadItem {
        DownloadItem(
            ecid: ecid,
            id: hash,
            name: name,
            nameEncodingSuspect: false,
            nameEncodingSuggestion: nil,
            sizeBytes: 2_097_152,
            doneBytes: 524_288,
            transferredBytes: 262_144,
            progressValue: 25,
            sourceCurrent: 1,
            sourceTotal: 1,
            sourceTransferring: 0,
            sourceA4AF: 0,
            statusCode: 3,
            isCompleted: false,
            status: "Downloading",
            speedBytes: 0,
            priority: 0,
            category: 0,
            partMetName: "\(ecid).part.met",
            lastSeenComplete: 0,
            lastReceived: 0,
            activeSeconds: 60,
            availableParts: 8,
            shared: false,
            alternativeNames: [],
            progressColors: []
        )
    }

    private func source(id: Int, requestFileID: Int, name: String) -> DownloadSourceItem {
        DownloadSourceItem(
            id: id,
            requestFileID: requestFileID,
            clientName: name,
            userIP: "10.0.0.\(id % 255)",
            userPort: 4662,
            serverName: "ExampleServer",
            serverIP: "1.2.3.4",
            serverPort: 4661,
            software: "aMule",
            softwareVersion: "2.3.3",
            downloadState: 2,
            downloadStateText: "On queue",
            sourceFrom: 1,
            sourceFromText: "Server",
            downSpeedKBps: 0,
            availableParts: 8,
            remoteQueueRank: 12,
            obfuscationStatus: 1,
            extendedProtocol: true,
            remoteFilename: "remote-\(name).iso",
            downloadedTotal: 4_096,
            uploadedTotal: 8_192,
            versionString: "2.3.3",
            sharesFileList: true
        )
    }
}
