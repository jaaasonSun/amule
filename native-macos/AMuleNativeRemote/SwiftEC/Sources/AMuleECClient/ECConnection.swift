@preconcurrency import Network
import Foundation
import AMuleECProtocol

@available(macOS 10.14, iOS 12.0, *)
public protocol ECConnectionTransport: Sendable {
    func connect(timeout: TimeInterval) async throws
    func disconnect() async
    func send(_ packet: ECPacket, timeout: TimeInterval, compressionEnabled: Bool) async throws
    func receivePacket(timeout: TimeInterval, partialReadTimeout: TimeInterval) async throws -> ECPacket
}

@available(macOS 10.14, iOS 12.0, *)
public actor ECConnection: ECConnectionTransport {
    public static let maximumPacketBodyLength = 16 * 1024 * 1024

    private let connection: NWConnection
    private let queue: DispatchQueue
    private var connected = false

    public init(host: String, port: UInt16, parameters: NWParameters = .tcp) throws {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw ECSessionError.invalidPort(port)
        }
        self.connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: parameters)
        self.queue = DispatchQueue(label: "org.amule.swift-ec.connection.\(host).\(port)")
    }

    public init(endpoint: NWEndpoint, parameters: NWParameters = .tcp) {
        self.connection = NWConnection(to: endpoint, using: parameters)
        self.queue = DispatchQueue(label: "org.amule.swift-ec.connection")
    }

    public func connect(timeout: TimeInterval = 30) async throws {
        if connected { return }

        try await ECTimeout.run(seconds: timeout, operation: .connect) { [connection, queue] in
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    let box = ECContinuationBox<Void>(continuation)
                    connection.stateUpdateHandler = { state in
                        switch state {
                        case .ready:
                            box.resume(returning: ())
                        case .failed(let error):
                            box.resume(throwing: ECSessionError.connectionFailed(error.localizedDescription))
                        case .cancelled:
                            box.resume(throwing: ECSessionError.connectionClosed)
                        default:
                            break
                        }
                    }
                    connection.start(queue: queue)
                }
            } onCancel: {
                connection.cancel()
            }
        }
        connected = true
    }

    public func disconnect() async {
        connected = false
        connection.cancel()
    }

    public func send(_ packet: ECPacket, timeout: TimeInterval = 30, compressionEnabled: Bool = false) async throws {
        guard connected else { throw ECSessionError.connectionClosed }
        let data = try packet.encode(compressionEnabled: compressionEnabled)
        try await write(data, timeout: timeout)
    }

    public func receivePacket(timeout: TimeInterval = 30, partialReadTimeout: TimeInterval = 10) async throws -> ECPacket {
        guard connected else { throw ECSessionError.connectionClosed }

        return try await ECTimeout.run(seconds: timeout, operation: .read) { [self] in
            let headerData = try await readExactly(ECPacketHeader.byteCount, timeout: partialReadTimeout)
            let header = try ECPacketHeader.decode(headerData)
            let bodyLength = Int(header.bodyLength)
            guard bodyLength <= Self.maximumPacketBodyLength else {
                throw ECSessionError.packetTooLarge(bodyLength)
            }
            let body = try await readExactly(bodyLength, timeout: partialReadTimeout)
            var bytes = header.encode()
            bytes.append(body)
            return try ECPacket.decode(bytes)
        }
    }

    private func write(_ data: Data, timeout: TimeInterval) async throws {
        try await ECTimeout.run(seconds: timeout, operation: .write) { [connection] in
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    let box = ECContinuationBox<Void>(continuation)
                    connection.send(content: data, completion: .contentProcessed { error in
                        if let error {
                            box.resume(throwing: ECSessionError.connectionFailed(error.localizedDescription))
                        } else {
                            box.resume(returning: ())
                        }
                    })
                }
            } onCancel: {
                connection.cancel()
            }
        }
    }

    private func readExactly(_ count: Int, timeout: TimeInterval) async throws -> Data {
        if count == 0 { return Data() }

        var data = Data()
        data.reserveCapacity(count)
        while data.count < count {
            let remaining = count - data.count
            let chunk = try await readChunk(maximumLength: remaining, timeout: timeout)
            guard !chunk.isEmpty else { throw ECSessionError.connectionClosed }
            data.append(chunk)
        }
        return data
    }

    private func readChunk(maximumLength: Int, timeout: TimeInterval) async throws -> Data {
        try await ECTimeout.run(seconds: timeout, operation: .read) { [connection] in
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    let box = ECContinuationBox<Data>(continuation)
                    connection.receive(minimumIncompleteLength: 1, maximumLength: maximumLength) { data, _, isComplete, error in
                        if let error {
                            box.resume(throwing: ECSessionError.connectionFailed(error.localizedDescription))
                        } else if let data, !data.isEmpty {
                            box.resume(returning: data)
                        } else if isComplete {
                            box.resume(throwing: ECSessionError.connectionClosed)
                        } else {
                            box.resume(returning: Data())
                        }
                    }
                }
            } onCancel: {
                connection.cancel()
            }
        }
    }
}
