import XCTest
import AMuleECBridgeAdapter
import AMuleECClient
import SharedViews
import SharedServices
@testable import AMuleRemoteiOS

@MainActor
final class IOSIncomingLinksTests: XCTestCase {
    func testDeepLinkHandlerAcceptsEncodedDirectAndMagnetLinks() {
        let inbox = PendingIncomingLinkInbox()
        let handler = IOSDeepLinkHandler(inbox: inbox)

        handler.handleOpenURL(URL(string: "ed2k://%7Cfile%7Calpha.bin%7C1%7CAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA%7C/")!)
        handler.handleOpenURL(URL(string: "ed2k://%7cfile%7cbeta.bin%7c1%7cBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB%7c/")!)
        handler.handleOpenURL(URL(string: "magnet:?xt=urn:ed2k:CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC")!)
        handler.handleOpenURL(URL(string: "https://example.invalid/not-ed2k")!)

        let drained = handler.drainIncomingLinks()
        XCTAssertEqual(drained.count, 3)
        XCTAssertTrue(drained[0].lowercased().hasPrefix("ed2k://%7cfile%7calpha.bin"))
        XCTAssertTrue(drained[1].lowercased().hasPrefix("ed2k://%7cfile%7cbeta.bin"))
        XCTAssertTrue(drained[2].hasPrefix("magnet:?xt=urn:ed2k:"))
    }

    func testIncomingInboxDedupesAndKeepsLinksQueuedUntilDrain() {
        let inbox = PendingIncomingLinkInbox()
        let first = "ed2k://|file|alpha.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/"
        let second = "ed2k://|file|beta.bin|2|BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB|/"

        inbox.enqueue([first, first, second].joined(separator: "\n"))

        XCTAssertTrue(inbox.hasPendingLinks)
        XCTAssertEqual(inbox.drain(), [first, second])
        XCTAssertFalse(inbox.hasPendingLinks)
        XCTAssertEqual(inbox.drain(), [])
    }

    func testNormalizeLinkFixesEncodedSeparatorsAndHashSuffix() {
        XCTAssertEqual(
            LinkImportSupport.normalizeLink("ed2k://%7Cfile%7Cbeta.bin%7C1%7CBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB%7C/"),
            "ed2k://|file|beta.bin|1|BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB|/"
        )
        XCTAssertEqual(
            LinkImportSupport.normalizeLink("ed2k://|file|gamma.bin|1|CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC|h=source|/"),
            "ed2k://|file|gamma.bin|1|CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC|/|h=source|/"
        )
    }

    func testAddLinksUsesSharedDiagnosticsForMixedInvalidInput() async {
        let bridge = IOSRecordingRenameBridge(downloadsResults: [[]])
        let model = IOSAppModel(bridge: bridge, credentialStorage: InMemoryCredentialStorage())
        model.isSessionConnected = true

        model.addLinks("""
        not a link
        ed2k://|file|queued.iso|100|00112233445566778899aabbccddeeff|/
        ed2k://|file|queued.iso|100|00112233445566778899aabbccddeeff|/
        magnet:?xt=urn:ed2k:BADHASH
        """)

        await waitForAddLinksCompletion(model)

        XCTAssertEqual(model.downloadFeedback, IOSAppModel.linkImportFeedback(LinkImportOutcome(successCount: 1, failureCount: 0)))
        XCTAssertEqual(model.lastError, "Ignored 1 unsupported line.\n1 duplicate link skipped.\n1 link has an invalid ED2K hash.")
    }

    func testAddLinksKeepsPartialFailureReasonInLastError() async {
        let bridge = IOSRecordingRenameBridge(downloadsResults: [[.download(name: "First")]])
        bridge.addLinkErrors = [IOSSnapshotFailure()]
        let model = IOSAppModel(
            bridge: bridge,
            credentialStorage: InMemoryCredentialStorage(),
            localNetworkErrors: StubLocalNetworkErrorPresentation(message: "Bridge refused the first link.")
        )
        model.isSessionConnected = true

        model.addLinks("""
        ed2k://|file|first.iso|100|00112233445566778899aabbccddeeff|/
        ed2k://|file|second.iso|200|11223344556677889900aabbccddee00|/
        """)

        await waitForAddLinksCompletion(model)

        XCTAssertEqual(bridge.addLinkCallCount, 2)
        XCTAssertEqual(model.lastError, "Bridge refused the first link.")
        XCTAssertEqual(
            model.downloadFeedback,
            IOSAppModel.linkImportFeedback(LinkImportOutcome(successCount: 1, failureCount: 1))
        )
    }

    private func waitForAddLinksCompletion(_ model: IOSAppModel) async {
        for _ in 0..<400 {
            let isBusy = await MainActor.run { model.isBusy }
            if !isBusy { return }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTFail("Timed out waiting for add-links completion")
    }
}

@MainActor
private final class StubLocalNetworkErrorPresentation: LocalNetworkErrorPresentation {
    private let message: String

    init(message: String) { self.message = message }

    func userFacingMessage(for error: Error) -> String { message }
}
