import XCTest
import SharedUI

@testable import AMuleNativeRemote

final class IOSPlatformServicesTests: XCTestCase {
    func testIOSKeychainCredentialStorageRoundTripsPassword() {
        #if canImport(Security)
        let key = "amule.password.test.\(UUID().uuidString)"
        let storage = IOSKeychainCredentialStorage(service: "org.amule.tests.ios-keychain")
        storage.deleteCredential(forKey: key)

        storage.writeCredential("hunter2", forKey: key)
        XCTAssertEqual(storage.readCredential(forKey: key), "hunter2")

        storage.deleteCredential(forKey: key)
        XCTAssertNil(storage.readCredential(forKey: key))
        #else
        throw XCTSkip("Security framework unavailable")
        #endif
    }

    @MainActor
    func testIOSDeepLinkHandlerBuffersAcceptedLinksUntilDrain() {
        let inbox = PendingIncomingLinkInbox()
        let handler = IOSDeepLinkHandler(inbox: inbox)

        handler.enqueueIncomingLink("ed2k://|file|alpha.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/")
        handler.enqueueIncomingLink("magnet:?xt=urn:ed2k:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB&dn=beta")
        handler.enqueueIncomingLink("https://example.com")

        XCTAssertEqual(handler.drainIncomingLinks(), [
            "ed2k://|file|alpha.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/",
            "magnet:?xt=urn:ed2k:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB&dn=beta"
        ])
        XCTAssertTrue(handler.drainIncomingLinks().isEmpty)
    }
}
