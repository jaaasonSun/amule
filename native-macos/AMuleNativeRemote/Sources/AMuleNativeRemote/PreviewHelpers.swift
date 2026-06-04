#if DEBUG
import SwiftUI
import SharedModels

@MainActor
extension AppModel {
    static func previewDisconnected() -> AppModel {
        let model = AppModel()
        model.isSessionConnected = false
        return model
    }

    static func previewConnected() -> AppModel {
        let model = AppModel()
        model.isSessionConnected = true
        model.status = StatusSnapshot(
            connected: true,
            ed2k: "Connected",
            kad: "Connected",
            downloadBytesPerSecond: 0,
            uploadBytesPerSecond: 0
        )
        return model
    }

    static func previewWithDownloads() -> AppModel {
        let model = previewConnected()
        model.downloads = [
            DownloadItem(
                ecid: 1,
                id: "ubuntu-iso",
                name: "Ubuntu ISO",
                nameEncodingSuspect: false,
                nameEncodingSuggestion: nil,
                sizeBytes: 2_147_483_648,
                doneBytes: 1_073_741_824,
                transferredBytes: 1_200_000_000,
                progressValue: 50,
                sourceCurrent: 18,
                sourceTotal: 64,
                sourceTransferring: 3,
                sourceA4AF: 1,
                statusCode: 0,
                isCompleted: false,
                status: "Downloading",
                speedBytes: 1_024,
                priority: 0,
                category: 0,
                partMetName: "Ubuntu ISO.part.met",
                lastSeenComplete: 1_717_000_000,
                lastReceived: 1_717_000_120,
                activeSeconds: 3_600,
                availableParts: 128,
                shared: false,
                alternativeNames: [],
                progressColors: [0x4CAF50, 0x81C784]
            ),
            DownloadItem(
                ecid: 2,
                id: "archive-zip",
                name: "Archive.zip",
                nameEncodingSuspect: false,
                nameEncodingSuggestion: nil,
                sizeBytes: 524_288_000,
                doneBytes: 131_072_000,
                transferredBytes: 160_000_000,
                progressValue: 25,
                sourceCurrent: 4,
                sourceTotal: 12,
                sourceTransferring: 0,
                sourceA4AF: 0,
                statusCode: 7,
                isCompleted: false,
                status: "Paused",
                speedBytes: 0,
                priority: 1,
                category: 1,
                partMetName: "Archive.zip.part.met",
                lastSeenComplete: 1_716_000_000,
                lastReceived: 1_716_000_200,
                activeSeconds: 1_800,
                availableParts: 32,
                shared: false,
                alternativeNames: [],
                progressColors: [0xFFB300]
            ),
            DownloadItem(
                ecid: 3,
                id: "movie-mkv",
                name: "Movie.mkv",
                nameEncodingSuspect: false,
                nameEncodingSuggestion: nil,
                sizeBytes: 1_610_612_736,
                doneBytes: 1_610_612_736,
                transferredBytes: 1_640_000_000,
                progressValue: 100,
                sourceCurrent: 12,
                sourceTotal: 12,
                sourceTransferring: 0,
                sourceA4AF: 0,
                statusCode: 9,
                isCompleted: true,
                status: "Complete",
                speedBytes: 0,
                priority: 2,
                category: 0,
                partMetName: "Movie.mkv.part.met",
                lastSeenComplete: 1_715_000_000,
                lastReceived: 1_715_000_300,
                activeSeconds: 7_200,
                availableParts: 256,
                shared: true,
                alternativeNames: [
                    DownloadAlternativeName(name: "Movie Final.mkv", count: 2)
                ],
                progressColors: [0x66BB6A]
            )
        ]
        return model
    }

    static func previewWithSearchResults() -> AppModel {
        let model = previewConnected()
        model.searchResults = [
            SearchResult(
                index: 7,
                hash: "000102030405060708090a0b0c0d0e0f",
                name: "result.bin",
                sizeBytes: 1_234,
                sources: 5,
                completeSources: 2,
                statusCode: 2,
                status: "Queued",
                parentID: 0,
                alreadyHave: true
            ),
            SearchResult(
                index: 8,
                hash: "101112131415161718191a1b1c1d1e1f",
                name: "Ubuntu-Desktop.iso",
                sizeBytes: 2_147_483_648,
                sources: 42,
                completeSources: 11,
                statusCode: 1,
                status: "Available",
                parentID: 0,
                alreadyHave: false
            ),
            SearchResult(
                index: 9,
                hash: "202122232425262728292a2b2c2d2e2f",
                name: "Archive.zip",
                sizeBytes: 524_288_000,
                sources: 9,
                completeSources: 1,
                statusCode: 4,
                status: "Stopped",
                parentID: 0,
                alreadyHave: false
            )
        ]
        return model
    }

    static func previewWithServers() -> AppModel {
        let model = previewConnected()
        model.servers = [
            ServerItem(
                id: 1,
                name: "Server",
                description: "Desc",
                version: "17",
                address: "1.2.3.4:4661",
                ip: "1.2.3.4",
                port: 4661,
                users: 10,
                maxUsers: 20,
                files: 30,
                ping: 40,
                failed: 1,
                priority: 2,
                isStatic: true
            ),
            ServerItem(
                id: 2,
                name: "ExampleServer",
                description: "",
                version: "",
                address: "5.45.85.226:6584",
                ip: "5.45.85.226",
                port: 6584,
                users: 120,
                maxUsers: 0,
                files: 8_240,
                ping: 22,
                failed: 0,
                priority: 0,
                isStatic: false
            )
        ]
        return model
    }

    static func previewWithPreferences() -> AppModel {
        let model = previewConnected()
        model.savedConnectionMaxUpload = 1_024
        model.savedConnectionMaxDownload = 2_048
        model.connectionMaxUploadKBps = 1_024
        model.connectionMaxDownloadKBps = 2_048
        model.connectionMaxUploadInput = "1024"
        model.connectionMaxDownloadInput = "2048"
        return model
    }
}
#endif
