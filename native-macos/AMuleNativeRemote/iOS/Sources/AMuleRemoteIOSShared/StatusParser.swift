import Foundation
import SharedUI


public enum BridgeCapabilityGate {
    public static func isSupported(_ op: String, by supportedOps: Set<String>) -> Bool {
        supportedOps.isEmpty || supportedOps.contains(op)
    }
}


@available(macOS 12.0, iOS 15.0, *)
public struct StatusSnapshot {
    public var connected: Bool = false
    public var ed2k: String = "Unknown"
    public var kad: String = "Unknown"
    public var downloadBytesPerSecond: Int? = nil
    public var uploadBytesPerSecond: Int? = nil
    public var queueCount: Int? = nil
    public var sourcesCount: Int? = nil

    public init(
        connected: Bool = false,
        ed2k: String = "Unknown",
        kad: String = "Unknown",
        downloadBytesPerSecond: Int? = nil,
        uploadBytesPerSecond: Int? = nil,
        queueCount: Int? = nil,
        sourcesCount: Int? = nil
    ) {
        self.connected = connected
        self.ed2k = ed2k
        self.kad = kad
        self.downloadBytesPerSecond = downloadBytesPerSecond
        self.uploadBytesPerSecond = uploadBytesPerSecond
        self.queueCount = queueCount
        self.sourcesCount = sourcesCount
    }

    public var downloadSpeed: String {
        guard let downloadBytesPerSecond else { return "-" }
        return AMuleFormatter.speed(bytesPerSecond: downloadBytesPerSecond)
    }

    public var uploadSpeed: String {
        guard let uploadBytesPerSecond else { return "-" }
        return AMuleFormatter.speed(bytesPerSecond: uploadBytesPerSecond)
    }

    public var queue: String {
        guard let queueCount else { return "-" }
        return String(queueCount)
    }

    public var sources: String {
        guard let sourcesCount else { return "-" }
        return String(sourcesCount)
    }

    public var looksConnected: Bool {
        connected
    }

    public static func fromBridge(_ payload: BridgeStatusPayload) -> StatusSnapshot {
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
