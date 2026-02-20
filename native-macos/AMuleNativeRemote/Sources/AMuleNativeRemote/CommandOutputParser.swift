import Foundation

struct SearchResult: Identifiable, Hashable {
    let index: Int
    let hash: String
    let name: String
    let sizeBytes: UInt64
    let sources: Int

    var id: String { hash }

    var sizeDisplay: String {
        AMuleFormatter.fileSize(sizeBytes)
    }

    static func fromBridge(_ payload: [BridgeSearchPayload]) -> [SearchResult] {
        payload
            .sorted { $0.id < $1.id }
            .map {
                SearchResult(
                    index: $0.id,
                    hash: $0.hash,
                    name: $0.name,
                    sizeBytes: $0.size,
                    sources: $0.sources
                )
            }
    }
}

struct DownloadItem: Identifiable, Hashable {
    let id: String
    let name: String
    let progressValue: Double
    let sourceCurrent: Int
    let sourceTotal: Int
    let status: String
    let speedBytes: Int
    let priority: Int

    var progressText: String {
        String(format: "%.1f%%", progressValue)
    }

    var sourcesText: String {
        "\(sourceCurrent)/\(sourceTotal)"
    }

    var speedText: String {
        AMuleFormatter.speed(bytesPerSecond: speedBytes)
    }

    static func fromBridge(_ payload: [BridgeDownloadPayload]) -> [DownloadItem] {
        payload.map {
            DownloadItem(
                id: $0.hash,
                name: $0.name,
                progressValue: $0.progress,
                sourceCurrent: $0.sourcesCurrent,
                sourceTotal: $0.sourcesTotal,
                status: $0.status,
                speedBytes: $0.speed,
                priority: $0.priority
            )
        }
    }
}

enum AMuleFormatter {
    static func speed(bytesPerSecond: Int) -> String {
        guard bytesPerSecond > 0 else {
            return "-"
        }
        let text = ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .binary)
        return "\(text)/s"
    }

    static func fileSize(_ bytes: UInt64) -> String {
        guard bytes > 0 else {
            return "-"
        }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
