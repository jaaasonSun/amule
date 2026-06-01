@testable import AMuleRemoteiOS

enum DownloadItemFixtures {
    static func download(
        id: String,
        name: String,
        nameEncodingSuspect: Bool = false,
        nameEncodingSuggestion: String? = nil
    ) -> DownloadItem {
        DownloadItem(
            ecid: 1,
            id: id,
            name: name,
            nameEncodingSuspect: nameEncodingSuspect,
            nameEncodingSuggestion: nameEncodingSuggestion,
            sizeBytes: 100,
            doneBytes: 10,
            transferredBytes: 10,
            progressValue: 10,
            sourceCurrent: 0,
            sourceTotal: 0,
            sourceTransferring: 0,
            sourceA4AF: 0,
            statusCode: 0,
            isCompleted: false,
            status: "Downloading",
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
    }
}
