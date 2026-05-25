import XCTest
import Foundation
import AMuleECProtocol
@testable import AMuleECClient

@available(macOS 10.14, iOS 12.0, *)
actor MockECTransport: ECConnectionTransport {
    private(set) var didConnect = false
    private(set) var didDisconnect = false
    private(set) var sentPackets: [ECPacket] = []
    private(set) var sentPacketBytes: [Data] = []
    private(set) var sentCompressionEnabled: [Bool] = []
    private var replies: [ECPacket]

    init(replies: [ECPacket]) {
        self.replies = replies
    }

    func connect(timeout: TimeInterval) async throws {
        didConnect = true
    }

    func disconnect() async {
        didDisconnect = true
    }

    func send(_ packet: ECPacket, timeout: TimeInterval, compressionEnabled: Bool) async throws {
        sentPackets.append(packet)
        sentPacketBytes.append(try packet.encode(compressionEnabled: compressionEnabled))
        sentCompressionEnabled.append(compressionEnabled)
    }

    func receivePacket(timeout: TimeInterval, partialReadTimeout: TimeInterval) async throws -> ECPacket {
        guard !replies.isEmpty else { throw ECSessionError.connectionClosed }
        return replies.removeFirst()
    }

    func sentOpcodes() -> [UInt8] {
        sentPackets.map(\.opcode)
    }

    func packetsSent() -> [ECPacket] {
        sentPackets
    }

    func compressionEnabledValues() -> [Bool] {
        sentCompressionEnabled
    }

    func sentHeaderFlags() throws -> [UInt32] {
        try sentPacketBytes.map { data in
            try ECPacketHeader.decode(data.prefix(ECPacketHeader.byteCount)).flags
        }
    }
}

@available(macOS 10.14, iOS 12.0, *)
final class ECSessionTests: XCTestCase {
    func testSessionAuthenticatesThroughPipeline() async throws {
        let salt = ECPacket(
            flags: ECAuthPacket.baseFlags,
            opcode: ECAuthPacket.opAuthSalt,
            tags: [ECTag.integer(name: ECAuthPacket.tagPasswordSalt, value: 0x1234_abcd)]
        )
        let ok = ECPacket(
            flags: ECAuthPacket.baseFlags,
            opcode: ECAuthPacket.opAuthOK,
            tags: [ECTag(name: ECAuthPacket.tagServerVersion, type: .string, value: .string("aMule"))]
        )
        let mock = MockECTransport(replies: [salt, ok])
        let session = ECSession(
            configuration: .init(host: "127.0.0.1", port: 4712, password: "secret", automaticReconnect: false),
            transportFactory: { mock }
        )

        let result = try await session.connectAndAuthenticate()

        XCTAssertEqual(result, .accepted(serverVersion: "aMule"))
        let state = await session.state
        let sentOpcodes = await mock.sentOpcodes()
        XCTAssertEqual(state, .authenticated)
        XCTAssertEqual(sentOpcodes, [ECAuthPacket.opAuthReq, ECAuthPacket.opAuthPassword])
    }

    func testSessionUsesCompatibleBaseFlagsByDefault() async throws {
        let mock = MockECTransport(replies: [
            ECPacket(flags: ECAuthPacket.baseFlags, opcode: ECAuthPacket.opAuthSalt, tags: [
                ECTag.integer(name: ECAuthPacket.tagPasswordSalt, value: 0x1234_abcd),
            ]),
            ECPacket(flags: ECAuthPacket.baseFlags, opcode: ECAuthPacket.opAuthOK),
            ECPacket(flags: ECAuthPacket.baseFlags, opcode: 0x04),
        ])
        let session = ECSession(
            configuration: .init(host: "127.0.0.1", port: 4712, password: "secret", automaticReconnect: false),
            transportFactory: { mock }
        )

        try await session.ensureAuthenticated()
        _ = try await session.send(ECPacket(opcode: 0x25))

        let packets = await mock.packetsSent()
        XCTAssertEqual(packets.map(\.flags), [
            ECAuthPacket.baseFlags,
            ECAuthPacket.baseFlags,
            ECAuthPacket.baseFlags,
        ])
        XCTAssertEqual(packets[0].tags.map(\.name), [
            ECAuthPacket.tagClientName,
            ECAuthPacket.tagClientVersion,
            ECAuthPacket.tagProtocolVersion,
        ])
    }

    func testSessionCanUseNativeBridgeCapabilitiesAndUTF8NumberFlags() async throws {
        let mock = MockECTransport(replies: [
            ECPacket(flags: ECAuthPacket.nativeBridgeFlags, opcode: ECAuthPacket.opAuthSalt, tags: [
                ECTag.integer(name: ECAuthPacket.tagPasswordSalt, value: 0x1234_abcd),
            ]),
            ECPacket(flags: ECAuthPacket.nativeBridgeFlags, opcode: ECAuthPacket.opAuthOK),
            ECPacket(flags: ECAuthPacket.nativeBridgeFlags, opcode: 0x04),
        ])
        let session = ECSession(
            configuration: .init(
                host: "127.0.0.1",
                port: 4712,
                password: "secret",
                automaticReconnect: false,
                packetFlags: ECAuthPacket.nativeBridgeFlags,
                advertisesZlib: true,
                advertisesUTF8Numbers: true
            ),
            transportFactory: { mock }
        )

        try await session.ensureAuthenticated()
        _ = try await session.send(ECPacket(opcode: 0x25))

        let packets = await mock.packetsSent()
        XCTAssertEqual(packets.map(\.flags), [
            ECAuthPacket.nativeBridgeFlags,
            ECAuthPacket.nativeBridgeFlags,
            ECAuthPacket.nativeBridgeFlags,
        ])
        XCTAssertEqual(packets[0].tags.map(\.name), [
            ECAuthPacket.tagClientName,
            ECAuthPacket.tagClientVersion,
            ECAuthPacket.tagProtocolVersion,
            ECAuthPacket.tagCanZlib,
            ECAuthPacket.tagCanUTF8Numbers,
        ])
    }

    func testSessionDoesNotCompressRequestsUnlessZlibFlagIsConfigured() async throws {
        let mock = MockECTransport(replies: [
            ECPacket(flags: ECAuthPacket.baseFlags, opcode: ECAuthPacket.opAuthSalt, tags: [
                ECTag.integer(name: ECAuthPacket.tagPasswordSalt, value: 0x1234_abcd),
            ]),
            ECPacket(flags: ECAuthPacket.baseFlags, opcode: ECAuthPacket.opAuthOK),
            ECPacket(flags: ECAuthPacket.baseFlags, opcode: 0x04),
        ])
        let session = ECSession(
            configuration: .init(host: "127.0.0.1", port: 4712, password: "secret", automaticReconnect: false),
            transportFactory: { mock }
        )

        try await session.ensureAuthenticated()
        _ = try await session.send(ECPacket(opcode: 0x30, tags: [
            ECTag(name: 0x0101, type: .string, value: .string(String(repeating: "x", count: ECCompression.threshold + 512))),
        ]))

        let compressionEnabled = await mock.compressionEnabledValues()
        XCTAssertEqual(compressionEnabled, [false, false, false])
    }

    func testSessionDoesNotSendZlibHeaderWhenFlagIsConfiguredButNotAdvertised() async throws {
        let configuredFlags = ECAuthPacket.nativeBridgeFlags | ECCompression.flag
        let mock = MockECTransport(replies: [
            ECPacket(flags: ECAuthPacket.baseFlags, opcode: ECAuthPacket.opAuthSalt, tags: [
                ECTag.integer(name: ECAuthPacket.tagPasswordSalt, value: 0x1234_abcd),
            ]),
            ECPacket(flags: ECAuthPacket.baseFlags, opcode: ECAuthPacket.opAuthOK),
            ECPacket(flags: ECAuthPacket.baseFlags, opcode: 0x04),
        ])
        let session = ECSession(
            configuration: .init(
                host: "127.0.0.1",
                port: 4712,
                password: "secret",
                automaticReconnect: false,
                packetFlags: configuredFlags,
                advertisesZlib: false,
                advertisesUTF8Numbers: true
            ),
            transportFactory: { mock }
        )

        try await session.ensureAuthenticated()
        _ = try await session.send(ECPacket(opcode: 0x30, tags: [
            ECTag(name: 0x0101, type: .string, value: .string(String(repeating: "x", count: ECCompression.threshold + 512))),
        ]))

        let compressionEnabled = await mock.compressionEnabledValues()
        let headerFlags = try await mock.sentHeaderFlags()
        XCTAssertEqual(compressionEnabled, [false, false, false])
        XCTAssertEqual(headerFlags.map { $0 & ECCompression.flag }, [0, 0, 0])
    }

    func testSessionDoesNotSendZlibHeaderWhenAdvertisedButFlagIsNotConfigured() async throws {
        let mock = MockECTransport(replies: [
            ECPacket(flags: ECAuthPacket.baseFlags, opcode: ECAuthPacket.opAuthSalt, tags: [
                ECTag.integer(name: ECAuthPacket.tagPasswordSalt, value: 0x1234_abcd),
            ]),
            ECPacket(flags: ECAuthPacket.baseFlags, opcode: ECAuthPacket.opAuthOK),
            ECPacket(flags: ECAuthPacket.baseFlags, opcode: 0x04),
        ])
        let session = ECSession(
            configuration: .init(
                host: "127.0.0.1",
                port: 4712,
                password: "secret",
                automaticReconnect: false,
                packetFlags: ECAuthPacket.nativeBridgeFlags,
                advertisesZlib: true,
                advertisesUTF8Numbers: true
            ),
            transportFactory: { mock }
        )

        try await session.ensureAuthenticated()
        _ = try await session.send(ECPacket(opcode: 0x30, tags: [
            ECTag(name: 0x0101, type: .string, value: .string(String(repeating: "x", count: ECCompression.threshold + 512))),
        ]))

        let compressionEnabled = await mock.compressionEnabledValues()
        let headerFlags = try await mock.sentHeaderFlags()
        XCTAssertEqual(compressionEnabled, [false, false, false])
        XCTAssertEqual(headerFlags.map { $0 & ECCompression.flag }, [0, 0, 0])
    }

    func testSessionEnablesCompressionOnlyWhenZlibWasAdvertisedAndConfigured() async throws {
        let flags = ECAuthPacket.nativeBridgeFlags | ECCompression.flag
        let mock = MockECTransport(replies: [
            ECPacket(flags: flags, opcode: ECAuthPacket.opAuthSalt, tags: [
                ECTag.integer(name: ECAuthPacket.tagPasswordSalt, value: 0x1234_abcd),
            ]),
            ECPacket(flags: flags, opcode: ECAuthPacket.opAuthOK),
            ECPacket(flags: flags, opcode: 0x04),
        ])
        let session = ECSession(
            configuration: .init(
                host: "127.0.0.1",
                port: 4712,
                password: "secret",
                automaticReconnect: false,
                packetFlags: flags,
                advertisesZlib: true,
                advertisesUTF8Numbers: true
            ),
            transportFactory: { mock }
        )

        try await session.ensureAuthenticated()
        _ = try await session.send(ECPacket(opcode: 0x30, tags: [
            ECTag(name: 0x0101, type: .string, value: .string(String(repeating: "x", count: ECCompression.threshold + 512))),
        ]))

        let compressionEnabled = await mock.compressionEnabledValues()
        XCTAssertEqual(compressionEnabled, [true, true, true])
    }

    func testSessionCanSendPacketWithoutWaitingForReply() async throws {
        let mock = MockECTransport(replies: [
            ECPacket(flags: ECAuthPacket.baseFlags, opcode: ECAuthPacket.opAuthSalt, tags: [
                ECTag.integer(name: ECAuthPacket.tagPasswordSalt, value: 0x1234_abcd),
            ]),
            ECPacket(flags: ECAuthPacket.baseFlags, opcode: ECAuthPacket.opAuthOK),
        ])
        let session = ECSession(
            configuration: .init(host: "127.0.0.1", port: 4712, password: "secret", automaticReconnect: false),
            transportFactory: { mock }
        )

        try await session.ensureAuthenticated()
        try await session.sendWithoutReply(ECPacket(opcode: 0x25))

        let sentOpcodes = await mock.sentOpcodes()
        XCTAssertEqual(sentOpcodes, [ECAuthPacket.opAuthReq, ECAuthPacket.opAuthPassword, 0x25])
    }

    func testRequestPipelineSerializesQueuedPackets() async throws {
        let firstReply = ECPacket(flags: ECAuthPacket.baseFlags, opcode: 0x10)
        let secondReply = ECPacket(flags: ECAuthPacket.baseFlags, opcode: 0x11)
        let mock = MockECTransport(replies: [firstReply, secondReply])
        let pipeline = ECRequestPipeline(transport: mock, requestTimeout: 1, partialReadTimeout: 1)

        await pipeline.enqueue(ECPacket(flags: ECAuthPacket.baseFlags, opcode: 0x20))
        await pipeline.enqueue(ECPacket(flags: ECAuthPacket.baseFlags, opcode: 0x21))
        let replies = try await pipeline.sendQueued()

        XCTAssertEqual(replies.map(\.opcode), [0x10, 0x11])
        let sentOpcodes = await mock.sentOpcodes()
        let queuedPacketCount = await pipeline.queuedPacketCount
        XCTAssertEqual(sentOpcodes, [0x20, 0x21])
        XCTAssertEqual(queuedPacketCount, 0)
    }

    func testPipelineTimesOutWhenNoReplyArrives() async throws {
        let mock = MockECTransport(replies: [])
        let pipeline = ECRequestPipeline(transport: mock, requestTimeout: 0.05, partialReadTimeout: 0.05)

        do {
            _ = try await pipeline.send(ECPacket(flags: ECAuthPacket.baseFlags, opcode: 0x20))
            XCTFail("Expected request to fail")
        } catch ECSessionError.connectionClosed {
            XCTAssertTrue(true)
        } catch ECSessionError.timeout(.request) {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
