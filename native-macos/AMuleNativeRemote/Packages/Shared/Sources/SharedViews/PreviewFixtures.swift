#if DEBUG
import SharedModels

public enum PreviewFixtures {
    private static func makeDownloadItem(
        ecid: Int,
        id: String,
        name: String,
        nameEncodingSuspect: Bool,
        nameEncodingSuggestion: String?,
        sizeBytes: UInt64,
        doneBytes: UInt64,
        transferredBytes: UInt64,
        progressValue: Double,
        sourceCurrent: Int,
        sourceTotal: Int,
        sourceTransferring: Int,
        sourceA4AF: Int,
        statusCode: Int,
        isCompleted: Bool,
        status: String,
        speedBytes: Int,
        priority: Int = 0,
        category: Int = 0,
        partMetName: String = "",
        lastSeenComplete: UInt64 = 0,
        lastReceived: UInt64 = 0,
        activeSeconds: Int = 0,
        availableParts: Int = 0,
        shared: Bool = false,
        alternativeNames: [DownloadAlternativeName] = [],
        progressColors: [UInt32] = []
    ) -> DownloadItem {
        DownloadItem(
            ecid: ecid,
            id: id,
            name: name,
            nameEncodingSuspect: nameEncodingSuspect,
            nameEncodingSuggestion: nameEncodingSuggestion,
            sizeBytes: sizeBytes,
            doneBytes: doneBytes,
            transferredBytes: transferredBytes,
            progressValue: progressValue,
            sourceCurrent: sourceCurrent,
            sourceTotal: sourceTotal,
            sourceTransferring: sourceTransferring,
            sourceA4AF: sourceA4AF,
            statusCode: statusCode,
            isCompleted: isCompleted,
            status: status,
            speedBytes: speedBytes,
            priority: priority,
            category: category,
            partMetName: partMetName,
            lastSeenComplete: lastSeenComplete,
            lastReceived: lastReceived,
            activeSeconds: activeSeconds,
            availableParts: availableParts,
            shared: shared,
            alternativeNames: alternativeNames,
            progressColors: progressColors
        )
    }

    // DownloadItem samples
    public static var downloadingDownload: DownloadItem {
        makeDownloadItem(
            ecid: 1001,
            id: "ubuntu-24-04-iso",
            name: "Ubuntu 24.04.iso",
            nameEncodingSuspect: false,
            nameEncodingSuggestion: nil,
            sizeBytes: 5_000_000_000,
            doneBytes: 3_000_000_000,
            transferredBytes: 3_120_000_000,
            progressValue: 60,
            sourceCurrent: 5,
            sourceTotal: 42,
            sourceTransferring: 3,
            sourceA4AF: 0,
            statusCode: 3,
            isCompleted: false,
            status: "Downloading",
            speedBytes: 512_000,
            lastSeenComplete: 1_718_000_000,
            lastReceived: 1_718_003_600,
            activeSeconds: 14_400,
            availableParts: 64,
            progressColors: [0x3B82F6, 0x60A5FA]
        )
    }

    public static var pausedDownload: DownloadItem {
        makeDownloadItem(
            ecid: 1002,
            id: "fedora-40-iso",
            name: "Fedora 40.iso",
            nameEncodingSuspect: false,
            nameEncodingSuggestion: nil,
            sizeBytes: 3_000_000_000,
            doneBytes: 1_000_000_000,
            transferredBytes: 1_000_000_000,
            progressValue: 33,
            sourceCurrent: 0,
            sourceTotal: 20,
            sourceTransferring: 0,
            sourceA4AF: 0,
            statusCode: 7,
            isCompleted: false,
            status: "Paused",
            speedBytes: 0,
            lastSeenComplete: 1_717_000_000,
            lastReceived: 1_717_001_800,
            activeSeconds: 7_200,
            availableParts: 32,
            progressColors: [0xF59E0B]
        )
    }

    public static var completedDownload: DownloadItem {
        makeDownloadItem(
            ecid: 1003,
            id: "arch-linux-iso",
            name: "Arch Linux.iso",
            nameEncodingSuspect: false,
            nameEncodingSuggestion: nil,
            sizeBytes: 1_000_000_000,
            doneBytes: 1_000_000_000,
            transferredBytes: 1_000_000_000,
            progressValue: 100,
            sourceCurrent: 0,
            sourceTotal: 0,
            sourceTransferring: 0,
            sourceA4AF: 0,
            statusCode: 9,
            isCompleted: true,
            status: "Completed",
            speedBytes: 0,
            lastSeenComplete: 1_716_000_000,
            lastReceived: 1_716_000_000,
            activeSeconds: 86_400,
            availableParts: 0,
            progressColors: [0x22C55E]
        )
    }

    public static var suggestedNameDownload: DownloadItem {
        makeDownloadItem(
            ecid: 1001,
            id: "ubuntu-24-04-iso",
            name: "Ubuntu 24.04.iso",
            nameEncodingSuspect: true,
            nameEncodingSuggestion: "Ubuntu 24.04 LTS Desktop AMD64.iso",
            sizeBytes: 5_000_000_000,
            doneBytes: 3_000_000_000,
            transferredBytes: 3_120_000_000,
            progressValue: 60,
            sourceCurrent: 5,
            sourceTotal: 42,
            sourceTransferring: 3,
            sourceA4AF: 0,
            statusCode: 3,
            isCompleted: false,
            status: "Downloading",
            speedBytes: 512_000,
            lastSeenComplete: 1_718_000_000,
            lastReceived: 1_718_003_600,
            activeSeconds: 14_400,
            availableParts: 64,
            progressColors: [0x3B82F6, 0x60A5FA]
        )
    }

    // SearchResult samples
    static var searchResults: [SearchResult] {
        [
            SearchResult(
                index: 1,
                hash: "3D2A3B4C5D6E7F8091A2B3C4D5E6F708",
                name: "Ubuntu 24.04 Desktop ISO",
                sizeBytes: 5_000_000_000,
                sources: 42,
                completeSources: 15,
                statusCode: 2,
                status: "Available",
                parentID: 0,
                alreadyHave: false
            )
        ]
    }

    // ServerItem samples
    static var servers: [ServerItem] {
        [
            ServerItem(
                id: 1,
                name: "eMule Security",
                description: "Stable community server",
                version: "0.50a",
                address: "5.45.85.226",
                ip: "5.45.85.226",
                port: 6584,
                users: 12_481,
                maxUsers: 25_000,
                files: 482_901,
                ping: 42,
                failed: 0,
                priority: 0,
                isStatic: true
            )
        ]
    }

    // Status samples
    static var connectedStatus: StatusSnapshot {
        StatusSnapshot(
            connected: true,
            ed2k: "Connected",
            kad: "Connected",
            downloadBytesPerSecond: 512_000,
            uploadBytesPerSecond: 128_000,
            queueCount: nil,
            sourcesCount: 42
        )
    }

    static var disconnectedStatus: StatusSnapshot {
        StatusSnapshot(
            connected: false,
            ed2k: "Disconnected",
            kad: "Disconnected",
            downloadBytesPerSecond: 0,
            uploadBytesPerSecond: 0,
            queueCount: nil,
            sourcesCount: nil
        )
    }

    // DownloadClassifiable wrapper for preview use
    struct PreviewDownloadClassifiable: DownloadClassifiable {
        public var statusCode: Int
        public var status: String
        public var isCompleted: Bool
        public var sizeBytes: UInt64
        public var doneBytes: UInt64
        public var speedBytes: Int
        public var sourceTransferring: Int
    }

    // DownloadSourceItem samples
    static var downloadSources: [DownloadSourceItem] {
        [
            DownloadSourceItem(
                id: 7_001,
                requestFileID: 1001,
                clientName: "arch-user",
                userIP: "203.0.113.21",
                userPort: 4662,
                serverName: "eMule Security",
                serverIP: "5.45.85.226",
                serverPort: 6584,
                software: "eMule",
                softwareVersion: "0.60d",
                downloadState: 2,
                downloadStateText: "Downloading",
                sourceFrom: 1,
                sourceFromText: "Server",
                downSpeedKBps: 256.0,
                availableParts: 87,
                remoteQueueRank: 4,
                obfuscationStatus: 1,
                extendedProtocol: true,
                remoteFilename: "Ubuntu 24.04.iso"
            ),
            DownloadSourceItem(
                id: 7_002,
                requestFileID: 1001,
                clientName: "fedora-mirror",
                userIP: "198.51.100.42",
                userPort: 4662,
                serverName: "eMule Security",
                serverIP: "5.45.85.226",
                serverPort: 6584,
                software: "aMule",
                softwareVersion: "2.4.2",
                downloadState: 1,
                downloadStateText: "Queued",
                sourceFrom: 2,
                sourceFromText: "Kad",
                downSpeedKBps: 0,
                availableParts: 64,
                remoteQueueRank: 12,
                obfuscationStatus: 0,
                extendedProtocol: false,
                remoteFilename: "Ubuntu 24.04.iso"
            )
        ]
    }
}

extension DownloadItem {
    var asClassifiable: PreviewFixtures.PreviewDownloadClassifiable {
        PreviewFixtures.PreviewDownloadClassifiable(
            statusCode: statusCode,
            status: status,
            isCompleted: isCompleted,
            sizeBytes: sizeBytes,
            doneBytes: doneBytes,
            speedBytes: speedBytes,
            sourceTransferring: sourceTransferring
        )
    }
}
#endif
