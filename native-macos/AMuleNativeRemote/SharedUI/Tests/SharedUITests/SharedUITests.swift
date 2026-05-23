import XCTest
@testable import SharedUI

final class ConnectionStateParserTests: XCTestCase {
    func testConnectedStates() {
        XCTAssertEqual(ConnectionStateParser.parse("Connected"), .connected)
        XCTAssertEqual(ConnectionStateParser.parse("connected"), .connected)
        XCTAssertEqual(ConnectionStateParser.parse("Connected to server"), .connected)
        XCTAssertEqual(ConnectionStateParser.parse("HighID"), .connected)
        XCTAssertEqual(ConnectionStateParser.parse("LowID"), .connected)
        XCTAssertEqual(ConnectionStateParser.parse("Firewalled"), .connected)
        XCTAssertEqual(ConnectionStateParser.parse("on"), .connected)
        XCTAssertEqual(ConnectionStateParser.parse("已连接"), .connected)
        XCTAssertEqual(ConnectionStateParser.parse("已連線"), .connected)
    }

    func testDisconnectedStates() {
        XCTAssertEqual(ConnectionStateParser.parse("Disconnected"), .disconnected)
        XCTAssertEqual(ConnectionStateParser.parse("disconnected"), .disconnected)
        XCTAssertEqual(ConnectionStateParser.parse("Not connected"), .disconnected)
        XCTAssertEqual(ConnectionStateParser.parse("offline"), .disconnected)
        XCTAssertEqual(ConnectionStateParser.parse("stopped"), .disconnected)
        XCTAssertEqual(ConnectionStateParser.parse("off"), .disconnected)
        XCTAssertEqual(ConnectionStateParser.parse("断开"), .disconnected)
        XCTAssertEqual(ConnectionStateParser.parse("未连接"), .disconnected)
    }

    func testTransitionalStates() {
        XCTAssertEqual(ConnectionStateParser.parse("Connecting"), .transitional)
        XCTAssertEqual(ConnectionStateParser.parse("connecting"), .transitional)
        XCTAssertEqual(ConnectionStateParser.parse("Starting"), .transitional)
        XCTAssertEqual(ConnectionStateParser.parse("initializing"), .transitional)
        XCTAssertEqual(ConnectionStateParser.parse("pending"), .transitional)
        XCTAssertEqual(ConnectionStateParser.parse("run"), .transitional)
        XCTAssertEqual(ConnectionStateParser.parse("running"), .transitional)
        XCTAssertEqual(ConnectionStateParser.parse("连接中"), .transitional)
    }

    func testUnknownStates() {
        XCTAssertEqual(ConnectionStateParser.parse(""), .unknown)
        XCTAssertEqual(ConnectionStateParser.parse("-"), .unknown)
        XCTAssertEqual(ConnectionStateParser.parse("unknown"), .unknown)
        XCTAssertEqual(ConnectionStateParser.parse("未知"), .unknown)
        XCTAssertEqual(ConnectionStateParser.parse("something random"), .unknown)
    }

    func testWhitespaceHandling() {
        XCTAssertEqual(ConnectionStateParser.parse("  Connected  "), .connected)
        XCTAssertEqual(ConnectionStateParser.parse("\nDisconnected\n"), .disconnected)
    }
}

final class ConnectionStateLocalizerTests: XCTestCase {
    func testLocalizedText() {
        XCTAssertEqual(ConnectionStateLocalizer.localizedText(for: .connected), "Connected")
        XCTAssertEqual(ConnectionStateLocalizer.localizedText(for: .disconnected), "Disconnected")
        XCTAssertEqual(ConnectionStateLocalizer.localizedText(for: .transitional), "Connecting")
        XCTAssertEqual(ConnectionStateLocalizer.localizedText(for: .unknown), "Unknown")
    }

    func testCompactText() {
        XCTAssertEqual(ConnectionStateLocalizer.compactText(for: .connected), "On")
        XCTAssertEqual(ConnectionStateLocalizer.compactText(for: .disconnected), "Off")
        XCTAssertEqual(ConnectionStateLocalizer.compactText(for: .transitional), "Run")
        XCTAssertEqual(ConnectionStateLocalizer.compactText(for: .unknown), "?")
    }
}

final class ED2kBadgeFormatterTests: XCTestCase {
    func testCompactBadgeValueConnectedWithServerName() {
        let result = ED2kBadgeFormatter.compactBadgeValue("Connected to DonkeyServer")
        XCTAssertEqual(result, "DonkeyServer")
    }

    func testCompactBadgeValueConnectingWithServerName() {
        let result = ED2kBadgeFormatter.compactBadgeValue("Connecting to DonkeyServer")
        XCTAssertEqual(result, "DonkeyServer")
    }

    func testCompactBadgeValueWithIP() {
        let result = ED2kBadgeFormatter.compactBadgeValue("Connected to DonkeyServer [1.2.3.4:4661]")
        XCTAssertEqual(result, "DonkeyServer")
    }

    func testCompactBadgeValueWithLowID() {
        let result = ED2kBadgeFormatter.compactBadgeValue("Connected to DonkeyServer LowID")
        XCTAssertEqual(result, "DonkeyServer")
    }

    func testCompactBadgeValueDisconnected() {
        let result = ED2kBadgeFormatter.compactBadgeValue("Disconnected")
        XCTAssertEqual(result, "Off")
    }

    func testCompactBadgeValueUnknown() {
        let result = ED2kBadgeFormatter.compactBadgeValue("")
        XCTAssertEqual(result, "?")
    }
}

final class DownloadClassificationTests: XCTestCase {
    struct MockDownload: DownloadClassifiable {
        var statusCode: Int
        var status: String
        var isCompleted: Bool
        var sizeBytes: UInt64
        var doneBytes: UInt64
        var speedBytes: Int
        var sourceTransferring: Int
    }

    func testIsCompletedByStatusCode() {
        let item = MockDownload(statusCode: 9, status: "Completed", isCompleted: true, sizeBytes: 100, doneBytes: 100, speedBytes: 0, sourceTransferring: 0)
        XCTAssertTrue(DownloadClassification.isCompleted(item))
    }

    func testIsCompletedBySizeMatch() {
        let item = MockDownload(statusCode: 0, status: "Downloading", isCompleted: false, sizeBytes: 100, doneBytes: 100, speedBytes: 0, sourceTransferring: 0)
        XCTAssertTrue(DownloadClassification.isCompleted(item))
    }

    func testIsCompletedByStatusText() {
        let item = MockDownload(statusCode: 0, status: "Completed", isCompleted: false, sizeBytes: 100, doneBytes: 50, speedBytes: 0, sourceTransferring: 0)
        XCTAssertTrue(DownloadClassification.isCompleted(item))
    }

    func testIsCompletedByChineseStatus() {
        let item = MockDownload(statusCode: 0, status: "完成", isCompleted: false, sizeBytes: 100, doneBytes: 50, speedBytes: 0, sourceTransferring: 0)
        XCTAssertTrue(DownloadClassification.isCompleted(item))
    }

    func testIsPausedByStatusCode() {
        let item = MockDownload(statusCode: 7, status: "Paused", isCompleted: false, sizeBytes: 100, doneBytes: 50, speedBytes: 0, sourceTransferring: 0)
        XCTAssertTrue(DownloadClassification.isPaused(item))
    }

    func testIsPausedByStatusCode5() {
        let item = MockDownload(statusCode: 5, status: "Insufficient", isCompleted: false, sizeBytes: 100, doneBytes: 50, speedBytes: 0, sourceTransferring: 0)
        XCTAssertTrue(DownloadClassification.isPaused(item))
    }

    func testIsPausedByStatusText() {
        let item = MockDownload(statusCode: 0, status: "Paused", isCompleted: false, sizeBytes: 100, doneBytes: 50, speedBytes: 0, sourceTransferring: 0)
        XCTAssertTrue(DownloadClassification.isPaused(item))
    }

    func testIsPausedByChineseStatus() {
        let item = MockDownload(statusCode: 0, status: "暂停", isCompleted: false, sizeBytes: 100, doneBytes: 50, speedBytes: 0, sourceTransferring: 0)
        XCTAssertTrue(DownloadClassification.isPaused(item))
    }

    func testIsDownloadingBySpeed() {
        let item = MockDownload(statusCode: 0, status: "Waiting", isCompleted: false, sizeBytes: 100, doneBytes: 50, speedBytes: 1024, sourceTransferring: 0)
        XCTAssertTrue(DownloadClassification.isDownloading(item))
    }

    func testIsDownloadingByStatusText() {
        let item = MockDownload(statusCode: 0, status: "Downloading", isCompleted: false, sizeBytes: 100, doneBytes: 50, speedBytes: 0, sourceTransferring: 1)
        XCTAssertTrue(DownloadClassification.isDownloading(item))
    }

    func testIsNotDownloadingWhenCompleted() {
        let item = MockDownload(statusCode: 9, status: "Completed", isCompleted: true, sizeBytes: 100, doneBytes: 100, speedBytes: 1024, sourceTransferring: 1)
        XCTAssertFalse(DownloadClassification.isDownloading(item))
    }

    func testIsNotDownloadingWhenPaused() {
        let item = MockDownload(statusCode: 7, status: "Paused", isCompleted: false, sizeBytes: 100, doneBytes: 50, speedBytes: 1024, sourceTransferring: 1)
        XCTAssertFalse(DownloadClassification.isDownloading(item))
    }

    func testIsPendingWhenNotOtherStates() {
        let item = MockDownload(statusCode: 0, status: "Waiting", isCompleted: false, sizeBytes: 100, doneBytes: 0, speedBytes: 0, sourceTransferring: 0)
        XCTAssertTrue(DownloadClassification.isPending(item))
    }

    func testIsNotPendingWhenDownloading() {
        let item = MockDownload(statusCode: 0, status: "Downloading", isCompleted: false, sizeBytes: 100, doneBytes: 50, speedBytes: 1024, sourceTransferring: 0)
        XCTAssertFalse(DownloadClassification.isPending(item))
    }
}

final class DownloadStatusSymbolTests: XCTestCase {
    struct MockDownload: DownloadClassifiable {
        var statusCode: Int
        var status: String
        var isCompleted: Bool
        var sizeBytes: UInt64
        var doneBytes: UInt64
        var speedBytes: Int
        var sourceTransferring: Int
    }

    func testErrorStatus() {
        XCTAssertEqual(DownloadStatusSymbol.symbolName(for: "Error"), "xmark")
        XCTAssertEqual(DownloadStatusSymbol.symbolName(for: "Erroneous"), "xmark")
        XCTAssertEqual(DownloadStatusSymbol.symbolName(for: "错误"), "xmark")
    }

    func testCompletedStatus() {
        XCTAssertEqual(DownloadStatusSymbol.symbolName(for: "Completed"), "checkmark")
        XCTAssertEqual(DownloadStatusSymbol.symbolName(for: "已完成"), "checkmark")
    }

    func testPausedStatus() {
        XCTAssertEqual(DownloadStatusSymbol.symbolName(for: "Paused"), "pause")
        XCTAssertEqual(DownloadStatusSymbol.symbolName(for: "暂停"), "pause")
    }

    func testHashingStatus() {
        XCTAssertEqual(DownloadStatusSymbol.symbolName(for: "Hashing"), "progress.indicator")
        XCTAssertEqual(DownloadStatusSymbol.symbolName(for: "Allocating"), "progress.indicator")
    }

    func testDownloadingStatus() {
        XCTAssertEqual(DownloadStatusSymbol.symbolName(for: "Downloading"), "arrow.down")
        XCTAssertEqual(DownloadStatusSymbol.symbolName(for: "下载中"), "arrow.down")
    }

    func testWaitingStatus() {
        XCTAssertEqual(DownloadStatusSymbol.symbolName(for: "Waiting"), "clock")
        XCTAssertEqual(DownloadStatusSymbol.symbolName(for: "等待"), "clock")
    }

    func testUnknownStatus() {
        XCTAssertEqual(DownloadStatusSymbol.symbolName(for: "Something"), "questionmark")
    }

    func testCircleSymbolVariants() {
        XCTAssertEqual(DownloadStatusSymbol.circleSymbolName(for: "Error"), "xmark.circle")
        XCTAssertEqual(DownloadStatusSymbol.circleSymbolName(for: "Completed"), "checkmark.circle")
        XCTAssertEqual(DownloadStatusSymbol.circleSymbolName(for: "Paused"), "pause.circle")
        XCTAssertEqual(DownloadStatusSymbol.circleSymbolName(for: "Downloading"), "arrow.down.circle")
        XCTAssertEqual(DownloadStatusSymbol.circleSymbolName(for: "Waiting"), "clock")
    }

    func testCategorySymbolVariantsMatchDownloadFilters() {
        XCTAssertEqual(DownloadStatusSymbol.categorySymbolName(for: MockDownload(statusCode: 0, status: "Downloading", isCompleted: false, sizeBytes: 100, doneBytes: 50, speedBytes: 1024, sourceTransferring: 1)), "arrow.down")
        XCTAssertEqual(DownloadStatusSymbol.categorySymbolName(for: MockDownload(statusCode: 0, status: "Waiting", isCompleted: false, sizeBytes: 100, doneBytes: 0, speedBytes: 0, sourceTransferring: 0)), "clock")
        XCTAssertEqual(DownloadStatusSymbol.categorySymbolName(for: MockDownload(statusCode: 7, status: "Paused", isCompleted: false, sizeBytes: 100, doneBytes: 20, speedBytes: 0, sourceTransferring: 0)), "pause")
        XCTAssertEqual(DownloadStatusSymbol.categorySymbolName(for: MockDownload(statusCode: 9, status: "Completed", isCompleted: true, sizeBytes: 100, doneBytes: 100, speedBytes: 0, sourceTransferring: 0)), "checkmark")
    }
}

final class ConnectionStateSymbolTests: XCTestCase {
    func testSymbolNames() {
        XCTAssertEqual(ConnectionStateSymbol.symbolName(for: .connected), "checkmark.circle")
        XCTAssertEqual(ConnectionStateSymbol.symbolName(for: .disconnected), "xmark.circle")
        XCTAssertEqual(ConnectionStateSymbol.symbolName(for: .transitional), "arrow.2.circlepath")
        XCTAssertEqual(ConnectionStateSymbol.symbolName(for: .unknown), "questionmark.circle")
    }
}

@MainActor
final class MetricChipViewTests: XCTestCase {
    func testMetricChipViewInit() {
        let chip = MetricChipView(title: "Download", value: "1.2 MB/s")
        XCTAssertEqual(chip.title, "Download")
        XCTAssertEqual(chip.value, "1.2 MB/s")
    }
}

@MainActor
final class ConnectionStateIndicatorTests: XCTestCase {
    func testIndicatorInit() {
        let indicator = ConnectionStateIndicator(state: .connected, showLabel: true, compact: false)
        XCTAssertEqual(indicator.state, .connected)
        XCTAssertTrue(indicator.showLabel)
        XCTAssertFalse(indicator.compact)
    }

    func testIndicatorInitCompact() {
        let indicator = ConnectionStateIndicator(state: .disconnected, showLabel: false, compact: true)
        XCTAssertEqual(indicator.state, .disconnected)
        XCTAssertFalse(indicator.showLabel)
        XCTAssertTrue(indicator.compact)
    }
}

@MainActor
final class EmptyStateViewTests: XCTestCase {
    func testEmptyStateViewInit() {
        let view = EmptyStateView(icon: "tray", title: "No Downloads", subtitle: "Items will appear here")
        XCTAssertEqual(view.icon, "tray")
        XCTAssertEqual(view.title, "No Downloads")
        XCTAssertEqual(view.subtitle, "Items will appear here")
    }

    func testEmptyStateViewWithoutSubtitle() {
        let view = EmptyStateView(icon: "tray", title: "No Downloads")
        XCTAssertNil(view.subtitle)
    }
}

@MainActor
final class AddLinksHUDTests: XCTestCase {
    func testHUDInit() {
        let hud = AddLinksHUD(message: "Added 3 link(s)")
        XCTAssertEqual(hud.message, "Added 3 link(s)")
    }
}

@MainActor
final class LinkImportPanelContentTests: XCTestCase {
    func testPanelIsBusyProperty() {
        XCTAssertTrue(LinkImportPanelContent(draft: .constant(""), isBusy: true, onImport: {}, onClear: {}).isBusy)
        XCTAssertFalse(LinkImportPanelContent(draft: .constant(""), isBusy: false, onImport: {}, onClear: {}).isBusy)
    }
}

@MainActor
final class ConnectionPanelContentTests: XCTestCase {
    func testPanelConnectionState() {
        let disconnectedPanel = ConnectionPanelContent(
            host: .constant("127.0.0.1"),
            port: .constant(4712),
            password: .constant(""),
            isConnected: false,
            isBusy: false,
            onConnect: {},
            onDisconnect: {},
            onClose: {}
        )
        XCTAssertFalse(disconnectedPanel.isConnected)
        XCTAssertFalse(disconnectedPanel.isBusy)

        let connectedPanel = ConnectionPanelContent(
            host: .constant("127.0.0.1"),
            port: .constant(4712),
            password: .constant(""),
            isConnected: true,
            isBusy: true,
            onConnect: {},
            onDisconnect: {},
            onClose: {}
        )
        XCTAssertTrue(connectedPanel.isConnected)
        XCTAssertTrue(connectedPanel.isBusy)
    }
}

@MainActor
final class KadPanelContentTests: XCTestCase {
    func testPanelStateProperties() {
        let panel = KadPanelContent(
            nodesURL: .constant("http://example.com/nodes.dat"),
            kadStatusText: "Connected",
            kadConnectionState: .connected,
            isRefreshing: false,
            isBusy: false,
            onRefresh: {},
            onUpdateNodes: {},
            onClose: {}
        )
        XCTAssertEqual(panel.kadStatusText, "Connected")
        XCTAssertEqual(panel.kadConnectionState, .connected)
        XCTAssertFalse(panel.isRefreshing)
        XCTAssertFalse(panel.isBusy)
    }

    func testPanelBusyState() {
        let panel = KadPanelContent(
            nodesURL: .constant(""),
            kadStatusText: "Unknown",
            kadConnectionState: .unknown,
            isRefreshing: true,
            isBusy: true,
            onRefresh: {},
            onUpdateNodes: {},
            onClose: {}
        )
        XCTAssertTrue(panel.isRefreshing)
        XCTAssertTrue(panel.isBusy)
    }
}

@MainActor
final class DownloadRowContentTests: XCTestCase {
    struct MockItem: DownloadClassifiable {
        var statusCode: Int
        var status: String
        var isCompleted: Bool
        var sizeBytes: UInt64
        var doneBytes: UInt64
        var speedBytes: Int
        var sourceTransferring: Int
    }

    func testRowContentInit() {
        let item = MockItem(statusCode: 0, status: "Downloading", isCompleted: false, sizeBytes: 100, doneBytes: 50, speedBytes: 1024, sourceTransferring: 1)
        let row = DownloadRowContent(
            item: item,
            name: "test.txt",
            progressText: "50.0%",
            speedText: "1.0 KB/s",
            sourcesText: "1/5",
            progressColors: [],
            progressDisplayValue: 50.0
        )
        XCTAssertEqual(row.name, "test.txt")
        XCTAssertEqual(row.progressText, "50.0%")
        XCTAssertEqual(row.speedText, "1.0 KB/s")
        XCTAssertEqual(row.sourcesText, "1/5")
    }
}

@MainActor
final class StatusTintedContentTests: XCTestCase {
    func testDisconnectedState() {
        let content = StatusTintedContent(state: .disconnected) { }
        XCTAssertEqual(content.state, .disconnected)
    }

    func testConnectedState() {
        let content = StatusTintedContent(state: .connected) { }
        XCTAssertEqual(content.state, .connected)
    }

    func testTransitionalState() {
        let content = StatusTintedContent(state: .transitional) { }
        XCTAssertEqual(content.state, .transitional)
    }

    func testUnknownState() {
        let content = StatusTintedContent(state: .unknown) { }
        XCTAssertEqual(content.state, .unknown)
    }
}

@MainActor
final class ConnectionFooterBarTests: XCTestCase {
    func testFooterBarInit() {
        let bar = ConnectionFooterBar(
            serverState: .connected,
            ed2kState: .disconnected,
            kadState: .unknown,
            ed2kStatusText: "Off",
            downloadSpeed: "1.2 MB/s",
            uploadSpeed: "256 KB/s",
            onServerTap: {},
            onEd2kTap: {},
            onKadTap: {}
        )
        XCTAssertEqual(bar.serverState, .connected)
        XCTAssertEqual(bar.ed2kState, .disconnected)
        XCTAssertEqual(bar.kadState, .unknown)
        XCTAssertEqual(bar.ed2kStatusText, "Off")
        XCTAssertEqual(bar.downloadSpeed, "1.2 MB/s")
        XCTAssertEqual(bar.uploadSpeed, "256 KB/s")
    }
}

final class LinkImportSupportTests: XCTestCase {
    func testParseLinksKeepsSupportedSchemesAndDedupesInOrder() {
        let parsed = LinkImportSupport.parseLinks(from: """
        ed2k://|file|alpha.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/
        https://example.invalid/ignored
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
            LinkImportSupport.extractEd2kHash(from: "ed2k://|file|alpha.bin|1|aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|/"),
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        )
        XCTAssertNil(LinkImportSupport.extractEd2kHash(from: "ed2k://|file|broken.bin|1|not-a-hash|/"))
    }

    func testLinkImportPlanPrecomputesNormalizedLinksAndHashes() {
        let plan = LinkImportPlan(rawInput: """
        ed2k://%7Cfile%7Calpha.bin%7C1%7CAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA%7C/
        magnet:?xt=urn:ed2k:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB&dn=beta
        """)

        XCTAssertEqual(plan?.count, 2)
        XCTAssertEqual(plan?.normalizedLinks.first, "ed2k://|file|alpha.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/")
        XCTAssertEqual(plan?.requestedHashes, [
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
            "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
        ])
        XCTAssertNil(LinkImportPlan(rawInput: "https://example.invalid/ignored"))
    }

    func testLinkImportOutcomeDefaultsDisplayedCountToSuccessCount() {
        let outcome = LinkImportOutcome(successCount: 2, failureCount: 1)
        XCTAssertEqual(outcome.displayedAddedCount, 2)
        XCTAssertTrue(outcome.hasFailures)
        XCTAssertTrue(outcome.hasAnyResult)

        let empty = LinkImportOutcome(successCount: 0, failureCount: 0, displayedAddedCount: 3)
        XCTAssertEqual(empty.displayedAddedCount, 3)
        XCTAssertFalse(empty.hasFailures)
        XCTAssertFalse(empty.hasAnyResult)
    }
}

@MainActor
final class PendingIncomingLinkInboxTests: XCTestCase {
    func testInboxDedupesQueuesAndDrains() {
        let inbox = PendingIncomingLinkInbox()
        inbox.enqueue("""
        ed2k://|file|alpha.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/
        ed2k://|file|alpha.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/
        magnet:?xt=urn:ed2k:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB&dn=beta
        https://example.invalid/ignored
        """)

        XCTAssertTrue(inbox.hasPendingLinks)
        XCTAssertEqual(inbox.drain(), [
            "ed2k://|file|alpha.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/",
            "magnet:?xt=urn:ed2k:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB&dn=beta"
        ])
        XCTAssertFalse(inbox.hasPendingLinks)
        XCTAssertTrue(inbox.drain().isEmpty)
    }
}

final class TransferLimitSettingsTests: XCTestCase {
    func testParsesTrimmedNonNegativeIntegers() throws {
        let limits = try TransferLimitSettings(downloadText: " 512 ", uploadText: "64")

        XCTAssertEqual(limits.maxDownload, 512)
        XCTAssertEqual(limits.maxUpload, 64)
    }

    func testAcceptsZeroAsUnlimited() throws {
        let limits = try TransferLimitSettings(downloadText: "0", uploadText: "0")

        XCTAssertEqual(limits, TransferLimitSettings(maxDownload: 0, maxUpload: 0))
    }

    func testRejectsInvalidDownloadBeforeUpload() {
        XCTAssertThrowsError(try TransferLimitSettings(downloadText: "-1", uploadText: "bad")) { error in
            XCTAssertEqual(error as? TransferLimitValidationError, .invalidDownload)
        }
    }

    func testRejectsInvalidUpload() {
        XCTAssertThrowsError(try TransferLimitSettings(downloadText: "128", uploadText: "bad")) { error in
            XCTAssertEqual(error as? TransferLimitValidationError, .invalidUpload)
        }
    }
}
