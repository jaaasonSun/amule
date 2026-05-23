import XCTest
import AMuleRemoteIOSShared
import AMuleECClient

final class DownloadNameSuggestionTests: XCTestCase {
    func testDownloadItemComputesRepeatedEncodingSuggestionFromSwiftECPayload() {
        let payload = ECDownload(
            ecid: 1,
            hash: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
            name: "FranÃƒÂ§ais.iso",
            size: 123,
            done: 0,
            transferred: 0,
            progress: 0,
            sourcesCurrent: 0,
            sourcesTotal: 0,
            sourcesTransferring: 0,
            sourcesA4AF: 0,
            statusCode: 0,
            isCompleted: false,
            status: "Waiting",
            speed: 0,
            priority: 0,
            category: 0,
            partMet: "001.part.met",
            lastSeenComplete: 0,
            lastReceived: 0,
            activeSeconds: 0,
            availableParts: 0,
            shared: false
        )

        let item = DownloadItem.fromBridge([payload])[0]
        XCTAssertEqual(item.name, "FranÃƒÂ§ais.iso")
        XCTAssertTrue(item.nameEncodingSuspect)
        XCTAssertEqual(item.nameEncodingSuggestion, "Français.iso")
    }

    func testAlternativeNameComputesEncodingSuggestion() {
        let alt = DownloadAlternativeName(name: "%E4%B8%AD%E6%96%87.avi", count: 3)
        XCTAssertEqual(alt.meaningfulNameEncodingSuggestion, "中文.avi")
    }
}
