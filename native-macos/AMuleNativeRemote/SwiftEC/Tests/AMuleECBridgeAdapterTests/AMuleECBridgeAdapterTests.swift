import XCTest
import Foundation
import AMuleECClient
import AMuleECProtocol
@testable import AMuleECBridgeAdapter

@available(macOS 10.15, iOS 13.0, *)
actor AdapterMockTransport: ECConnectionTransport {
    private(set) var sentPackets: [ECPacket] = []
    private(set) var disconnectCount = 0
    private var replies: [ECPacket]

    init(replies: [ECPacket]) { self.replies = replies }
    func connect(timeout: TimeInterval) async throws {}
    func disconnect() async { disconnectCount += 1 }
    func send(_ packet: ECPacket, timeout: TimeInterval, compressionEnabled: Bool) async throws { sentPackets.append(packet) }
    func receivePacket(timeout: TimeInterval, partialReadTimeout: TimeInterval) async throws -> ECPacket {
        guard !replies.isEmpty else { throw ECSessionError.connectionClosed }
        return replies.removeFirst()
    }
    func sentOpcodes() -> [UInt8] { sentPackets.map(\.opcode) }
    func disconnectCalls() -> Int { disconnectCount }
}

@available(macOS 10.15, iOS 13.0, *)
final class AMuleECBridgeAdapterTests: XCTestCase {
    func testInit() {}

    func testAdapterSendsMutationAndReturnsJSONEnvelope() async throws {
        let mock = AdapterMockTransport(replies: [Self.salt, Self.authOK, ECPacket(opcode: 0x01)])
        let session = ECSession(configuration: .init(host: "127.0.0.1", port: 4712, password: "secret", automaticReconnect: false), transportFactory: { mock })
        let adapter = SwiftECBridgeAdapter(session: session)

        let result = try await adapter.pause(hash: "00112233445566778899aabbccddeeff", config: AMuleConnectionConfig(password: "secret"))

        XCTAssertEqual(result.message, "Action completed")
        XCTAssertTrue(result.raw.contains("\"ok\":true"))
        let sentOpcodes = await mock.sentOpcodes()
        XCTAssertEqual(sentOpcodes, [0x02, 0x50, 0x19])
    }

    func testAdapterDisconnectsOwnedEphemeralSessionAfterMutation() async throws {
        let mock = AdapterMockTransport(replies: [Self.salt, Self.authOK, ECPacket(opcode: 0x01)])
        let adapter = SwiftECBridgeAdapter(sessionFactory: { config in
            ECSession(
                configuration: ECSession.Configuration(
                    host: config.host,
                    port: UInt16(clamping: config.port),
                    password: config.password,
                    automaticReconnect: false
                ),
                transportFactory: { mock }
            )
        })

        let result = try await adapter.rename(
            hash: "00112233445566778899aabbccddeeff",
            name: "renamed.iso",
            config: AMuleConnectionConfig(password: "secret")
        )

        XCTAssertEqual(result.message, "Rename requested")
        let sentOpcodes = await mock.sentOpcodes()
        XCTAssertEqual(sentOpcodes, [0x02, 0x50, 0x25])
        let disconnectCalls = await mock.disconnectCalls()
        XCTAssertEqual(disconnectCalls, 1)
    }

    func testAdapterSurfacesRenameFailureMessageFromDaemon() async throws {
        let mock = AdapterMockTransport(replies: [
            Self.salt,
            Self.authOK,
            ECPacket(opcode: 0x05, tags: [
                ECTag(name: 0x0000, type: .string, value: .string("Unable to rename file.")),
            ]),
        ])
        let session = ECSession(configuration: .init(host: "127.0.0.1", port: 4712, password: "secret", automaticReconnect: false), transportFactory: { mock })
        let adapter = SwiftECBridgeAdapter(session: session)

        do {
            _ = try await adapter.rename(
                hash: "00112233445566778899aabbccddeeff",
                name: "中文.iso",
                config: AMuleConnectionConfig(password: "secret")
            )
            XCTFail("Expected daemon rename failure")
        } catch let error as ECResponseParserError {
            XCTAssertEqual(error.localizedDescription, "Unable to rename file.")
        }
    }

    func testAdapterTreatsClosedRenameSocketAsIndeterminateSend() async throws {
        let mock = AdapterMockTransport(replies: [Self.salt, Self.authOK])
        let session = ECSession(configuration: .init(host: "127.0.0.1", port: 4712, password: "secret", automaticReconnect: false), transportFactory: { mock })
        let adapter = SwiftECBridgeAdapter(session: session)

        let result = try await adapter.rename(
            hash: "00112233445566778899aabbccddeeff",
            name: "renamed.iso",
            config: AMuleConnectionConfig(password: "secret")
        )

        XCTAssertEqual(result.message, "Rename requested")
        let sentOpcodes = await mock.sentOpcodes()
        XCTAssertEqual(sentOpcodes, [0x02, 0x50, 0x25])
    }

    func testAdapterMergesDownloadSnapshotWithIncrementalAlternativeNames() async throws {
        let mock = AdapterMockTransport(replies: [
            Self.salt,
            Self.authOK,
            ECPacket(opcode: 0x1F, tags: [
                Self.partFile(ecid: 42, hash: Self.hash, name: "current.iso"),
            ]),
            ECPacket(opcode: 0x22, tags: [
                Self.partFile(ecid: 42, hash: Self.hash, name: "current.iso", sourceNameEntries: [
                    Self.sourceNameEntry(id: 7, name: "better.iso", count: 3),
                ]),
            ]),
        ])
        let session = ECSession(configuration: .init(host: "127.0.0.1", port: 4712, password: "secret", automaticReconnect: false), transportFactory: { mock })
        let adapter = SwiftECBridgeAdapter(session: session)

        let (downloads, _) = try await adapter.downloads(config: AMuleConnectionConfig(password: "secret"))

        XCTAssertEqual(downloads.first?.alternativeNames, [
            ECDownload.AlternativeName(name: "better.iso", count: 3),
        ])
        let sentOpcodes = await mock.sentOpcodes()
        XCTAssertEqual(sentOpcodes, [0x02, 0x50, 0x0D, 0x52])
    }

    func testAdapterSeedsAlternativeNameIDsFromFullSnapshotForCountOnlyUpdate() async throws {
        let mock = AdapterMockTransport(replies: [
            Self.salt,
            Self.authOK,
            ECPacket(opcode: 0x1F, tags: [
                Self.partFile(ecid: 42, hash: Self.hash, name: "current.iso", sourceNameEntries: [
                    Self.sourceNameEntry(id: 7, name: "better.iso", count: 3),
                ]),
            ]),
            ECPacket(opcode: 0x22, tags: [
                Self.partFile(ecid: 42, hash: Self.hash, name: "current.iso", sourceNameEntries: [
                    Self.sourceNameEntry(id: 7, name: nil, count: 5),
                ]),
            ]),
        ])
        let session = ECSession(configuration: .init(host: "127.0.0.1", port: 4712, password: "secret", automaticReconnect: false), transportFactory: { mock })
        let adapter = SwiftECBridgeAdapter(session: session)

        let (downloads, _) = try await adapter.downloads(config: AMuleConnectionConfig(password: "secret"))

        XCTAssertEqual(downloads.first?.alternativeNames, [
            ECDownload.AlternativeName(name: "better.iso", count: 5),
        ])
    }

    func testAdapterPreservesSourcesAcrossPartialClientDeltas() async throws {
        let mock = AdapterMockTransport(replies: [
            Self.salt,
            Self.authOK,
            ECPacket(opcode: 0x1F, tags: [
                Self.partFile(ecid: 42, hash: Self.hash, name: "current.iso"),
            ]),
            ECPacket(opcode: 0x22, tags: [
                Self.client(id: 99, children: [
                    .integer(name: 0x0620, value: 42),
                    ECTag(name: 0x0100, type: .string, value: .string("peer")),
                    .integer(name: 0x060C, value: 2),
                    ECTag(name: 0x060E, type: .double, value: .double(1.5)),
                ]),
            ]),
            ECPacket(opcode: 0x1F, tags: [
                Self.partFile(ecid: 42, hash: Self.hash, name: "current.iso"),
            ]),
            ECPacket(opcode: 0x22, tags: [
                Self.client(id: 99, children: [
                    .integer(name: 0x060C, value: 3),
                    ECTag(name: 0x060E, type: .double, value: .double(12.5)),
                ]),
            ]),
        ])
        let session = ECSession(configuration: .init(host: "127.0.0.1", port: 4712, password: "secret", automaticReconnect: false), transportFactory: { mock })
        let adapter = SwiftECBridgeAdapter(session: session)

        _ = try await adapter.sources(hash: Self.hash, config: AMuleConnectionConfig(password: "secret"))
        let (sources, _) = try await adapter.sources(hash: Self.hash, config: AMuleConnectionConfig(password: "secret"))

        XCTAssertEqual(sources.count, 1)
        let source = try XCTUnwrap(sources.first)
        XCTAssertEqual(source.clientID, 99)
        XCTAssertEqual(source.requestFileID, 42)
        XCTAssertEqual(source.clientName, "peer")
        XCTAssertEqual(source.downloadState, 3)
        XCTAssertEqual(source.downSpeedKBps, 12.5)
        let sentOpcodes = await mock.sentOpcodes()
        XCTAssertEqual(sentOpcodes, [0x02, 0x50, 0x0D, 0x52, 0x0D, 0x52])
    }

    func testAdapterSurfacesSearchStartFailureBeforePolling() async throws {
        let mock = AdapterMockTransport(replies: [
            Self.salt,
            Self.authOK,
            ECPacket(opcode: 0x05, tags: [
                ECTag(name: 0x0000, type: .string, value: .string("No server connected.")),
            ]),
        ])
        let session = ECSession(configuration: .init(host: "127.0.0.1", port: 4712, password: "secret", automaticReconnect: false), transportFactory: { mock })
        let adapter = SwiftECBridgeAdapter(session: session)

        do {
            _ = try await adapter.search(scope: "global", query: "ubuntu", polls: 1, pollIntervalMs: 0, config: AMuleConnectionConfig(password: "secret"))
            XCTFail("Expected search start failure")
        } catch let error as ECResponseParserError {
            XCTAssertEqual(error, .operationFailed("No server connected."))
        }

        let sentOpcodes = await mock.sentOpcodes()
        XCTAssertEqual(sentOpcodes, [0x02, 0x50, 0x26])
    }

    func testAdapterAcceptsOriginalSuccessOpcodesForSearchStopAndSearchDownload() async throws {
        let searchStopMock = AdapterMockTransport(replies: [Self.salt, Self.authOK, ECPacket(opcode: 0x07)])
        let searchStopSession = ECSession(configuration: .init(host: "127.0.0.1", port: 4712, password: "secret", automaticReconnect: false), transportFactory: { searchStopMock })
        let searchStopAdapter = SwiftECBridgeAdapter(session: searchStopSession)

        let searchStop = try await searchStopAdapter.searchStop(config: AMuleConnectionConfig(password: "secret"))
        XCTAssertEqual(searchStop.message, "Search stop requested")

        let downloadMock = AdapterMockTransport(replies: [Self.salt, Self.authOK, ECPacket(opcode: 0x06)])
        let downloadSession = ECSession(configuration: .init(host: "127.0.0.1", port: 4712, password: "secret", automaticReconnect: false), transportFactory: { downloadMock })
        let downloadAdapter = SwiftECBridgeAdapter(session: downloadSession)

        let download = try await downloadAdapter.download(hash: "00112233445566778899aabbccddeeff", config: AMuleConnectionConfig(password: "secret"))
        XCTAssertEqual(download.message, "Download request accepted")
    }

    private static let salt = ECPacket(
        flags: ECAuthPacket.baseFlags,
        opcode: ECAuthPacket.opAuthSalt,
        tags: [ECTag.integer(name: ECAuthPacket.tagPasswordSalt, value: 0x1234_abcd)]
    )

    private static let authOK = ECPacket(
        flags: ECAuthPacket.baseFlags,
        opcode: ECAuthPacket.opAuthOK,
        tags: [ECTag(name: ECAuthPacket.tagServerVersion, type: .string, value: .string("aMule"))]
    )

    private static let hash = "00112233445566778899aabbccddeeff"

    private static func partFile(ecid: Int, hash: String, name: String, sourceNameEntries: [ECTag] = []) -> ECTag {
        var children = [
            ECTag(name: 0x0301, type: .string, value: .string(name)),
            ECTag.integer(name: 0x0303, value: 100),
            ECTag.integer(name: 0x0306, value: 10),
            ECTag.integer(name: 0x0308, value: 7),
            ECTag(name: 0x031E, type: .hash16, value: .hash16(Data(hex: hash))),
        ]
        if !sourceNameEntries.isEmpty {
            children.append(ECTag(name: 0x0315, type: .unknown, children: sourceNameEntries))
        }
        return ECTag.integer(name: 0x0300, value: UInt64(ecid), children: children)
    }

    private static func sourceNameEntry(id: Int, name: String?, count: Int) -> ECTag {
        var children = [ECTag.integer(name: 0x031C, value: UInt64(count))]
        if let name {
            children.append(ECTag(name: 0x0315, type: .string, value: .string(name)))
        }
        return ECTag.integer(name: 0x0315, value: UInt64(id), children: children)
    }

    private static func client(id: Int, children: [ECTag]) -> ECTag {
        ECTag.integer(name: 0x0600, value: UInt64(id), children: children)
    }
}

private extension Data {
    init(hex: String) {
        self.init()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            append(UInt8(hex[index..<next], radix: 16)!)
            index = next
        }
    }
}
