#if DEBUG
import SwiftUI
import SharedModels

extension IOSAppModel {
    /// Disconnected, no data
    @MainActor
    static func previewDisconnected() -> IOSAppModel {
        let model = IOSAppModel()
        model.isSessionConnected = false
        return model
    }

    /// Connected but empty (no downloads/servers/search results)
    @MainActor
    static func previewConnectedEmpty() -> IOSAppModel {
        let model = IOSAppModel()
        model.isSessionConnected = true
        model.status = StatusSnapshot(
            connected: true,
            ed2k: "Connected",
            kad: "Connected",
            downloadBytesPerSecond: 0,
            uploadBytesPerSecond: 0,
            queueCount: 0,
            sourcesCount: 0
        )
        return model
    }

    /// Connected with sample downloads (mix of downloading, paused, completed)
    @MainActor
    static func previewWithDownloads() -> IOSAppModel {
        let model = previewConnectedEmpty()
        model.downloads = [
            Self.previewDownloadingItem(),
            Self.previewPausedItem(),
            Self.previewCompletedItem()
        ]
        return model
    }

    /// Connected with completed downloads only
    @MainActor
    static func previewWithCompletedDownloads() -> IOSAppModel {
        let model = previewConnectedEmpty()
        model.downloads = [Self.previewCompletedItem()]
        return model
    }

    /// Connected with search results
    @MainActor
    static func previewWithSearchResults() -> IOSAppModel {
        let model = previewConnectedEmpty()
        model.searchResults = [Self.previewSearchResult()]
        return model
    }

    /// Search in progress
    @MainActor
    static func previewSearchInProgress() -> IOSAppModel {
        let model = previewConnectedEmpty()
        model.isSearchInProgress = true
        model.searchProgress = 45
        return model
    }

    /// Connected with sample servers
    @MainActor
    static func previewWithServers() -> IOSAppModel {
        let model = previewConnectedEmpty()
        model.servers = [Self.previewServerItem()]
        model.userServers = [Self.previewUserServer()]
        return model
    }

    /// Connected with settings/preferences
    @MainActor
    static func previewWithSettings() -> IOSAppModel {
        let model = previewConnectedEmpty()
        model.uploadLimitKBps = 1024
        model.downloadLimitKBps = 2048
        return model
    }

    @MainActor
    private static func previewDownloadingItem() -> DownloadItem {
        DownloadItem(
            ecid: 1,
            id: "00112233445566778899aabbccddeeff",
            name: "Ubuntu 24.04.iso",
            nameEncodingSuspect: false,
            nameEncodingSuggestion: nil,
            sizeBytes: 5_368_709_120,
            doneBytes: 3_221_225_472,
            transferredBytes: 3_355_443_200,
            progressValue: 60,
            sourceCurrent: 5,
            sourceTotal: 42,
            sourceTransferring: 3,
            sourceA4AF: 0,
            statusCode: 3,
            isCompleted: false,
            status: "Downloading",
            speedBytes: 524_288,
            priority: 2,
            category: 0,
            partMetName: "Ubuntu 24.04.iso.part",
            lastSeenComplete: 1_730_000_000,
            lastReceived: 1_730_000_600,
            activeSeconds: 7_200,
            availableParts: 128,
            shared: false,
            alternativeNames: [],
            progressColors: []
        )
    }

    @MainActor
    private static func previewPausedItem() -> DownloadItem {
        DownloadItem(
            ecid: 2,
            id: "ffeeddccbbaa99887766554433221100",
            name: "Fedora 40.iso",
            nameEncodingSuspect: false,
            nameEncodingSuggestion: nil,
            sizeBytes: 3_221_225_472,
            doneBytes: 1_073_741_824,
            transferredBytes: 1_209_999_360,
            progressValue: 33.3,
            sourceCurrent: 0,
            sourceTotal: 20,
            sourceTransferring: 0,
            sourceA4AF: 0,
            statusCode: 7,
            isCompleted: false,
            status: "Paused",
            speedBytes: 0,
            priority: 1,
            category: 0,
            partMetName: "Fedora 40.iso.part",
            lastSeenComplete: 1_729_900_000,
            lastReceived: 1_729_900_300,
            activeSeconds: 3_600,
            availableParts: 64,
            shared: false,
            alternativeNames: [],
            progressColors: []
        )
    }

    @MainActor
    private static func previewCompletedItem() -> DownloadItem {
        DownloadItem(
            ecid: 3,
            id: "11112222333344445555666677778888",
            name: "Arch Linux.iso",
            nameEncodingSuspect: false,
            nameEncodingSuggestion: nil,
            sizeBytes: 1_073_741_824,
            doneBytes: 1_073_741_824,
            transferredBytes: 1_073_741_824,
            progressValue: 100,
            sourceCurrent: 0,
            sourceTotal: 0,
            sourceTransferring: 0,
            sourceA4AF: 0,
            statusCode: 9,
            isCompleted: true,
            status: "Completed",
            speedBytes: 0,
            priority: 0,
            category: 0,
            partMetName: "Arch Linux.iso.part",
            lastSeenComplete: 1_728_000_000,
            lastReceived: 1_728_000_000,
            activeSeconds: 0,
            availableParts: 0,
            shared: true,
            alternativeNames: [],
            progressColors: []
        )
    }

    @MainActor
    private static func previewSearchResult() -> SearchResult {
        SearchResult(
            index: 1,
            hash: "00112233445566778899aabbccddeeff",
            name: "Ubuntu 24.04 Desktop ISO",
            sizeBytes: 5_368_709_120,
            sources: 42,
            completeSources: 15,
            statusCode: 2,
            status: "Available",
            parentID: 0,
            alreadyHave: false
        )
    }

    @MainActor
    private static func previewServerItem() -> ServerItem {
        ServerItem(
            id: 1,
            name: "eMule Security",
            description: "Trusted community server",
            version: "1.0",
            address: "5.45.85.226:6584",
            ip: "5.45.85.226",
            port: 6584,
            users: 1_234,
            maxUsers: 2_000_000,
            files: 150_000,
            ping: 42,
            failed: 0,
            priority: 0,
            isStatic: true
        )
    }

    @MainActor
    private static func previewUserServer() -> UserServer {
        UserServer(name: "My Server", ip: "192.168.1.100", port: 4661)
    }
}
#endif
