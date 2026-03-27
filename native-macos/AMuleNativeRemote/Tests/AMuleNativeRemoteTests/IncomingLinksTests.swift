import XCTest

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

}
