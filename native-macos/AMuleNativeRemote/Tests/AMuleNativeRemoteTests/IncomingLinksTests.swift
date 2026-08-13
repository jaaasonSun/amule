import XCTest
import AMuleECBridgeAdapter
import SharedViews

@testable import AMuleNativeRemote

final class IncomingLinksTests: XCTestCase {
    func testParseLinksKeepsSupportedSchemesAndDedupes() {
        let parsed = LinkImportSupport.parseLinks(from: """
        ed2k://|file|alpha.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/
        
        https://example.com
        magnet:?xt=urn:ed2k:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB&dn=beta
        ed2k://|file|alpha.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/
        """)

        XCTAssertEqual(parsed, [
            "ed2k://|file|alpha.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/",
            "magnet:?xt=urn:ed2k:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB&dn=beta"
        ])
    }

    func testNormalizeLinkFixesEncodedSeparatorsAndHashSuffix() {
        XCTAssertEqual(
            LinkImportSupport.normalizeLink("ed2k://%7Cfile%7Cname.bin%7C1%7CAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA%7C/"),
            "ed2k://|file|name.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/"
        )

        XCTAssertEqual(
            LinkImportSupport.normalizeLink("ed2k://|file|name.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|h=abc"),
            "ed2k://|file|name.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/|h=abc"
        )
    }

    func testExtractEd2kHashSupportsMagnetAndDirectLinks() {
        XCTAssertEqual(
            LinkImportSupport.extractEd2kHash(from: "magnet:?xt=urn:ed2k:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB&dn=beta"),
            "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
        )

        XCTAssertEqual(
            LinkImportSupport.extractEd2kHash(from: "ed2k://|file|alpha.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/"),
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        )
    }

    @MainActor
    func testPendingIncomingLinkInboxDedupesAndDrains() {
        _ = PendingIncomingLinkInbox.shared.drain()

        PendingIncomingLinkInbox.shared.enqueue("""
        ed2k://|file|alpha.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/
        ed2k://|file|alpha.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/
        magnet:?xt=urn:ed2k:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB&dn=beta
        https://example.com
        """)

        XCTAssertEqual(
            PendingIncomingLinkInbox.shared.drain(),
            [
                "ed2k://|file|alpha.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/",
                "magnet:?xt=urn:ed2k:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB&dn=beta"
            ]
        )

        XCTAssertTrue(PendingIncomingLinkInbox.shared.drain().isEmpty)
    }

    @MainActor
    func testFlushIncomingLinksKeepsInboxWhenDisconnected() {
        _ = PendingIncomingLinkInbox.shared.drain()

        PendingIncomingLinkInbox.shared.enqueue("ed2k://|file|alpha.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/")

        let model = AppModel()
        model.isSessionConnected = false
        model.flushIncomingLinksIfAny()

        XCTAssertTrue(PendingIncomingLinkInbox.shared.hasPendingLinks)
        XCTAssertEqual(
            PendingIncomingLinkInbox.shared.drain(),
            ["ed2k://|file|alpha.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/"]
        )
    }

    @MainActor
    func testAddingLinkReportsBridgeFailureInLastError() async throws {
        struct TestBridgeFailure: LocalizedError {
            var errorDescription: String? { "bridge said no" }
        }

        let bridge = FakeBridgeAdapter()
        bridge.addLinkResult = .failure(TestBridgeFailure())
        let model = AppModel(bridge: bridge)

        model.addLinks("ed2k://|file|alpha.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/")

        try await waitUntil {
            !model.isBusy && model.showHUD
        }

        XCTAssertEqual(model.hudMessage, LF3("Added %lld link(s), failed %lld.", Int64(0), Int64(1)))
        XCTAssertTrue(model.lastError.contains("bridge said no"))
        XCTAssertTrue(model.lastError.contains("ed2k://|file|alpha.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/"))
    }

    @MainActor
    func testAddingLinkReportsAlreadyPresentAsSkippedNotFailed() async throws {
        let bridge = FakeBridgeAdapter()
        let existingDownload = DownloadItem.fromBridge([
            BridgeDownloadPayload(
                ecid: 101,
                hash: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
                name: "alpha.bin",
                nameEncodingSuspect: false,
                nameEncodingSuggestion: nil,
                size: 1,
                done: 1,
                transferred: 1,
                progress: 100,
                sourcesCurrent: 0,
                sourcesTotal: 0,
                sourcesTransferring: 0,
                sourcesA4AF: 0,
                statusCode: 9,
                isCompleted: true,
                status: "Completed",
                speed: 0,
                priority: 0,
                category: 0,
                partMet: "101.part.met",
                lastSeenComplete: 0,
                lastReceived: 0,
                activeSeconds: 0,
                availableParts: 0,
                shared: true,
                alternativeNames: [],
                progressColors: []
            )
        ]).first
        XCTAssertNotNil(existingDownload)
        bridge.downloadsResult = (
            [
                BridgeDownloadPayload(
                    ecid: 101,
                    hash: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
                    name: "alpha.bin",
                    nameEncodingSuspect: false,
                    nameEncodingSuggestion: nil,
                    size: 1,
                    done: 1,
                    transferred: 1,
                    progress: 100,
                    sourcesCurrent: 0,
                    sourcesTotal: 0,
                    sourcesTransferring: 0,
                    sourcesA4AF: 0,
                    statusCode: 9,
                    isCompleted: true,
                    status: "Completed",
                    speed: 0,
                    priority: 0,
                    category: 0,
                    partMet: "101.part.met",
                    lastSeenComplete: 0,
                    lastReceived: 0,
                    activeSeconds: 0,
                    availableParts: 0,
                    shared: true,
                    alternativeNames: [],
                    progressColors: []
                )
            ],
            #"{"ok":true,"downloads":[{"ecid":101,"hash":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"}] }"#
        )
        let model = AppModel(bridge: bridge)
        model.downloads = [existingDownload!]

        model.addLinks("ed2k://|file|alpha.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/")

        try await waitUntil {
            !model.isBusy && model.showHUD
        }

        XCTAssertEqual(model.hudMessage, LF3("Added %lld link(s)", Int64(0)))
        XCTAssertTrue(model.lastError.contains("Already present or skipped"))
        XCTAssertFalse(model.lastError.contains("failed"))
    }

    @MainActor
    func testAddingLinkReportsAcceptedButNotVisibleWithoutBlame() async throws {
        let bridge = FakeBridgeAdapter()
        bridge.downloadsResult = ([], #"{"ok":true,"downloads":[]}"#)
        let model = AppModel(bridge: bridge)

        model.addLinks("ed2k://|file|alpha.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/")

        try await waitUntil {
            !model.isBusy && model.showHUD
        }

        XCTAssertEqual(model.hudMessage, LF3("Added %lld link(s)", Int64(0)))
        XCTAssertTrue(model.lastError.contains("accepted but not visible") || model.lastError.contains("not visible"))
        XCTAssertFalse(model.lastError.contains("bridge said no"))
    }

    @MainActor
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
