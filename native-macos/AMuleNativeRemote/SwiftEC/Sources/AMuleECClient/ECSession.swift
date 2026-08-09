import Foundation
import AMuleECProtocol

@available(macOS 10.14, iOS 12.0, *)
public actor ECSession {
    public enum State: String, Sendable {
        case disconnected
        case connecting
        case connected
        case authenticating
        case authenticated
    }

    public struct Configuration: Sendable {
        public let host: String
        public let port: UInt16
        public let password: String
        public let clientName: String
        public let clientVersion: String
        public let connectTimeout: TimeInterval
        public let requestTimeout: TimeInterval
        public let partialReadTimeout: TimeInterval
        public let automaticReconnect: Bool
        public let maximumReconnectDelay: TimeInterval
        public let packetFlags: UInt32
        public let advertisesZlib: Bool
        public let advertisesUTF8Numbers: Bool

        public init(
            host: String,
            port: UInt16,
            password: String,
            clientName: String = "SwiftEC",
            clientVersion: String = "1.0",
            connectTimeout: TimeInterval = 30,
            requestTimeout: TimeInterval = 30,
            partialReadTimeout: TimeInterval = 10,
            automaticReconnect: Bool = true,
            maximumReconnectDelay: TimeInterval = 30,
            packetFlags: UInt32 = ECAuthPacket.baseFlags,
            advertisesZlib: Bool = false,
            advertisesUTF8Numbers: Bool = false
        ) {
            self.host = host
            self.port = port
            self.password = password
            self.clientName = clientName
            self.clientVersion = clientVersion
            self.connectTimeout = connectTimeout
            self.requestTimeout = requestTimeout
            self.partialReadTimeout = partialReadTimeout
            self.automaticReconnect = automaticReconnect
            self.maximumReconnectDelay = maximumReconnectDelay
            self.packetFlags = packetFlags
            self.advertisesZlib = advertisesZlib
            self.advertisesUTF8Numbers = advertisesUTF8Numbers
        }
    }

    public private(set) var state: State = .disconnected
    public private(set) var reconnectGeneration: UInt = 0

    private let configuration: Configuration
    private let makeTransport: @Sendable () throws -> any ECConnectionTransport
    private var transport: (any ECConnectionTransport)?
    private var pipeline: ECRequestPipeline?
    private var reconnectDelay: TimeInterval = 1
    private var hasEstablishedTransport = false

    public init(configuration: Configuration) {
        self.configuration = configuration
        self.makeTransport = {
            try ECConnection(host: configuration.host, port: configuration.port)
        }
    }

    public init(
        configuration: Configuration,
        transportFactory: @escaping @Sendable () throws -> any ECConnectionTransport
    ) {
        self.configuration = configuration
        self.makeTransport = transportFactory
    }

    public func connect() async throws {
        guard state == .disconnected else { return }
        state = .connecting

        do {
            let transport = try makeTransport()
            try await transport.connect(timeout: configuration.connectTimeout)
            self.transport = transport
            self.pipeline = ECRequestPipeline(
                transport: transport,
                requestTimeout: configuration.requestTimeout,
                partialReadTimeout: configuration.partialReadTimeout,
                compressionEnabled: configuration.compressionEnabled
            )
            if hasEstablishedTransport {
                reconnectGeneration &+= 1
            } else {
                hasEstablishedTransport = true
            }
            state = .connected
            reconnectDelay = 1
        } catch {
            state = .disconnected
            throw error
        }
    }

    public func authenticate() async throws -> ECAuthResult {
        if state == .disconnected { try await connect() }
        guard state == .connected else {
            throw ECSessionError.invalidState(expected: .connected, actual: state)
        }
        guard let pipeline else { throw ECSessionError.connectionClosed }

        state = .authenticating
        do {
            let saltPacket: ECPacket
            do {
                saltPacket = try await pipeline.send(ECAuthPacket.authRequest(
                    clientName: configuration.clientName,
                    version: configuration.clientVersion,
                    canZlib: configuration.advertisesZlib,
                    canUTF8Numbers: configuration.advertisesUTF8Numbers,
                    flags: configuration.packetFlags
                ))
            } catch {
                throw authenticationHandshakeError(phase: "waiting for auth salt", underlying: error)
            }
            let salt = try ECLegacyAuth.parseSalt(from: saltPacket)
            let authReply: ECPacket
            do {
                authReply = try await pipeline.send(try ECAuthPacket.authPassword(password: configuration.password, salt: salt, flags: configuration.packetFlags))
            } catch {
                throw authenticationHandshakeError(phase: "waiting for auth result", underlying: error)
            }
            let result = try ECLegacyAuth.parseAuthResponse(authReply)
            state = .authenticated
            return result
        } catch let error as ECLegacyAuthError {
            state = .disconnected
            await disconnectTransport()
            throw ECSessionError.authenticationFailed(error.description)
        } catch {
            state = .disconnected
            await disconnectTransport()
            throw error
        }
    }

    public func connectAndAuthenticate() async throws -> ECAuthResult {
        try await connect()
        return try await authenticate()
    }

    public func ensureAuthenticated() async throws {
        switch state {
        case .authenticated:
            return
        case .disconnected:
            _ = try await connectAndAuthenticate()
        case .connected:
            _ = try await authenticate()
        case .connecting, .authenticating:
            throw ECSessionError.invalidState(expected: .authenticated, actual: state)
        }
    }

    public func send(_ packet: ECPacket) async throws -> ECPacket {
        guard state == .authenticated else {
            throw ECSessionError.invalidState(expected: .authenticated, actual: state)
        }
        guard let pipeline else { throw ECSessionError.connectionClosed }

        do {
            return try await pipeline.send(packetForSession(packet))
        } catch {
            state = .disconnected
            await disconnectTransport()
            if configuration.automaticReconnect, !Task.isCancelled, !(error is CancellationError) {
                try await reconnect()
            }
            throw error
        }
    }

    public func sendWithoutReply(_ packet: ECPacket) async throws {
        guard state == .authenticated else {
            throw ECSessionError.invalidState(expected: .authenticated, actual: state)
        }
        guard let pipeline else { throw ECSessionError.connectionClosed }

        do {
            try await pipeline.sendWithoutReply(packetForSession(packet))
        } catch {
            state = .disconnected
            await disconnectTransport()
            if configuration.automaticReconnect, !Task.isCancelled, !(error is CancellationError) {
                try await reconnect()
            }
            throw error
        }
    }

    public func enqueue(_ packet: ECPacket) async throws {
        guard state == .authenticated else {
            throw ECSessionError.invalidState(expected: .authenticated, actual: state)
        }
        guard let pipeline else { throw ECSessionError.connectionClosed }
        await pipeline.enqueue(packetForSession(packet))
    }

    public func sendQueued() async throws -> [ECPacket] {
        guard state == .authenticated else {
            throw ECSessionError.invalidState(expected: .authenticated, actual: state)
        }
        guard let pipeline else { throw ECSessionError.connectionClosed }
        return try await pipeline.sendQueued()
    }

    public func disconnect() async {
        state = .disconnected
        await disconnectTransport()
    }

    public func reconnect() async throws {
        state = .disconnected
        await disconnectTransport()
        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, configuration.maximumReconnectDelay)
        try await ECTimeout.run(seconds: delay + configuration.connectTimeout + configuration.requestTimeout, operation: .reconnect) { [self] in
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            _ = try await connectAndAuthenticate()
        }
    }

    private func disconnectTransport() async {
        if let transport {
            await transport.disconnect()
        }
        transport = nil
        pipeline = nil
    }

    private func packetForSession(_ packet: ECPacket) -> ECPacket {
        ECPacket(flags: configuration.outgoingPacketFlags, opcode: packet.opcode, tags: packet.tags)
    }

    private func authenticationHandshakeError(phase: String, underlying error: Error) -> ECSessionError {
        let message: String
        if let sessionError = error as? ECSessionError {
            message = sessionError.description
        } else {
            message = error.localizedDescription
        }
        return .protocolError("Authentication handshake failed while \(phase): \(message)")
    }
}

private extension ECSession.Configuration {
    var outgoingPacketFlags: UInt32 {
        compressionEnabled ? packetFlags : packetFlags & ~ECCompression.flag
    }

    var compressionEnabled: Bool {
        advertisesZlib && (packetFlags & ECCompression.flag) != 0
    }
}
