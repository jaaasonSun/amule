import Foundation
import AMuleECProtocol

@available(macOS 10.14, iOS 12.0, *)
public actor ECRequestPipeline {
    private let transport: any ECConnectionTransport
    private let requestTimeout: TimeInterval
    private let partialReadTimeout: TimeInterval
    private let compressionEnabled: Bool
    private var queuedPackets: [ECPacket] = []
    private var requestInProgress = false

    public init(
        transport: any ECConnectionTransport,
        requestTimeout: TimeInterval = 30,
        partialReadTimeout: TimeInterval = 10,
        compressionEnabled: Bool = false
    ) {
        self.transport = transport
        self.requestTimeout = requestTimeout
        self.partialReadTimeout = partialReadTimeout
        self.compressionEnabled = compressionEnabled
    }

    public var queuedPacketCount: Int {
        queuedPackets.count
    }

    public func enqueue(_ packet: ECPacket) {
        queuedPackets.append(packet)
    }

    public func sendQueued() async throws -> [ECPacket] {
        var replies: [ECPacket] = []
        while !queuedPackets.isEmpty {
            let packet = queuedPackets.removeFirst()
            replies.append(try await send(packet))
        }
        return replies
    }

    public func send(_ packet: ECPacket) async throws -> ECPacket {
        while requestInProgress {
            try await Task.sleep(nanoseconds: 1_000_000)
        }

        requestInProgress = true
        defer { requestInProgress = false }

        return try await ECTimeout.run(seconds: requestTimeout, operation: .request) { [transport, requestTimeout, partialReadTimeout, compressionEnabled] in
            try await transport.send(packet, timeout: requestTimeout, compressionEnabled: compressionEnabled)
            return try await transport.receivePacket(timeout: requestTimeout, partialReadTimeout: partialReadTimeout)
        }
    }

    public func sendWithoutReply(_ packet: ECPacket) async throws {
        while requestInProgress {
            try await Task.sleep(nanoseconds: 1_000_000)
        }

        requestInProgress = true
        defer { requestInProgress = false }

        try await ECTimeout.run(seconds: requestTimeout, operation: .write) { [transport, requestTimeout, compressionEnabled] in
            try await transport.send(packet, timeout: requestTimeout, compressionEnabled: compressionEnabled)
        }
    }
}
