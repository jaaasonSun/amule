import XCTest
import SharedViews
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
}
