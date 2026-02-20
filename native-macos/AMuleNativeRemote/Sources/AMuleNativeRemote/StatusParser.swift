import Foundation

struct StatusSnapshot {
    var connected: Bool = false
    var ed2k: String = "Unknown"
    var kad: String = "Unknown"
    var downloadBytesPerSecond: Int? = nil
    var uploadBytesPerSecond: Int? = nil
    var queueCount: Int? = nil
    var sourcesCount: Int? = nil

    var downloadSpeed: String {
        guard let downloadBytesPerSecond else { return "-" }
        return AMuleFormatter.speed(bytesPerSecond: downloadBytesPerSecond)
    }

    var uploadSpeed: String {
        guard let uploadBytesPerSecond else { return "-" }
        return AMuleFormatter.speed(bytesPerSecond: uploadBytesPerSecond)
    }

    var queue: String {
        guard let queueCount else { return "-" }
        return String(queueCount)
    }

    var sources: String {
        guard let sourcesCount else { return "-" }
        return String(sourcesCount)
    }

    var looksConnected: Bool {
        connected
    }

    static func fromBridge(_ payload: BridgeStatusPayload) -> StatusSnapshot {
        StatusSnapshot(
            connected: payload.connected,
            ed2k: payload.ed2k,
            kad: payload.kad,
            downloadBytesPerSecond: payload.downloadSpeed,
            uploadBytesPerSecond: payload.uploadSpeed,
            queueCount: payload.queue,
            sourcesCount: payload.sources
        )
    }
}
