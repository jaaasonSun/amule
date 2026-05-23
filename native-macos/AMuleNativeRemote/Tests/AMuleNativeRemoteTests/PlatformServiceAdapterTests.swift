import AppKit
import XCTest
import SharedUI

@testable import AMuleNativeRemote

final class PlatformServiceAdapterTests: XCTestCase {
    func testMacOSPasteboardShareMatchesBaselineNSPasteboardWrite() throws {
        let pasteboard = try XCTUnwrap(NSPasteboard.withUniqueName())
        let adapter = MacOSPasteboardShare(pasteboard: pasteboard)

        adapter.writeString("raw bridge output")

        XCTAssertEqual(pasteboard.string(forType: .string), "raw bridge output")

        pasteboard.clearContents()
        pasteboard.setString("baseline", forType: .string)

        XCTAssertEqual(adapter.readString(), "baseline")
    }

    @MainActor
    func testAppModelClipboardMethodsDelegateThroughPasteboardBoundary() {
        let pasteboard = PlatformServiceStubs.Pasteboard()
        let model = AppModel(pasteboardShare: pasteboard)

        model.outputLog = "log text"
        model.copyLogToClipboard()
        XCTAssertEqual(pasteboard.readString(), "log text")

        model.lastDownloadsRawOutput = "downloads raw"
        model.copyDownloadsRawToClipboard()
        XCTAssertEqual(pasteboard.readString(), "downloads raw")

        model.lastSearchRawOutput = "search raw"
        model.copySearchRawToClipboard()
        XCTAssertEqual(pasteboard.readString(), "search raw")

        model.lastServersRawOutput = "servers raw"
        model.copyServersRawToClipboard()
        XCTAssertEqual(pasteboard.readString(), "servers raw")

        model.lastSourcesRawOutput = "sources raw"
        model.copySourcesRawToClipboard()
        XCTAssertEqual(pasteboard.readString(), "sources raw")

        model.lastUploadsRawOutput = "uploads raw"
        model.copyUploadsRawToClipboard()
        XCTAssertEqual(pasteboard.readString(), "uploads raw")

        model.lastSharedFilesRawOutput = "shared raw"
        model.copySharedFilesRawToClipboard()
        XCTAssertEqual(pasteboard.readString(), "shared raw")

        model.lastCoreLogRawOutput = "core log raw"
        model.copyCoreLogRawToClipboard()
        XCTAssertEqual(pasteboard.readString(), "core log raw")

        model.lastCoreDebugLogRawOutput = "debug log raw"
        model.copyCoreDebugLogRawToClipboard()
        XCTAssertEqual(pasteboard.readString(), "debug log raw")

        let item = DownloadItem(
            ecid: 1,
            id: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
            name: "file name.bin",
            nameEncodingSuspect: false,
            nameEncodingSuggestion: nil,
            sizeBytes: 42,
            doneBytes: 0,
            transferredBytes: 0,
            progressValue: 0,
            sourceCurrent: 0,
            sourceTotal: 0,
            sourceTransferring: 0,
            sourceA4AF: 0,
            statusCode: 0,
            isCompleted: false,
            status: "Waiting",
            speedBytes: 0,
            priority: 0,
            category: 0,
            partMetName: "",
            lastSeenComplete: 0,
            lastReceived: 0,
            activeSeconds: 0,
            availableParts: 0,
            shared: false,
            alternativeNames: [],
            progressColors: []
        )

        model.copyDownloadLinkToClipboard(item)
        XCTAssertEqual(
            pasteboard.readString(),
            "ed2k://|file|file%20name.bin|42|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/"
        )
    }

    @MainActor
    func testMacOSDeepLinkHandlerDelegatesToExistingInboxParser() {
        _ = PendingIncomingLinkInbox.shared.drain()
        let handler = MacOSDeepLinkHandler(inbox: .shared, lifecycle: PlatformServiceStubs.Lifecycle())

        handler.enqueueIncomingLink("""
        ed2k://|file|alpha.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/
        https://example.com
        magnet:?xt=urn:ed2k:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB&dn=beta
        """)

        XCTAssertEqual(handler.drainIncomingLinks(), [
            "ed2k://|file|alpha.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/",
            "magnet:?xt=urn:ed2k:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB&dn=beta"
        ])
    }
}
