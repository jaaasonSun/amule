import XCTest
import Foundation
import AMuleECClient
import AMuleECProtocol
import Fixtures
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

    func testAdapterKeepsOwnedSessionAliveAfterMutation() async throws {
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
        XCTAssertEqual(disconnectCalls, 0)
    }

    func testAdapterDisconnectsCachedSessionWhenConfigChanges() async throws {
        let firstMock = AdapterMockTransport(replies: [Self.salt, Self.authOK, ECPacket(opcode: 0x01)])
        let secondMock = AdapterMockTransport(replies: [Self.salt, Self.authOK, ECPacket(opcode: 0x01)])
        let adapter = SwiftECBridgeAdapter(sessionFactory: { config in
            let mock = config.host == "127.0.0.1" ? firstMock : secondMock
            return ECSession(
                configuration: ECSession.Configuration(
                    host: config.host,
                    port: UInt16(clamping: config.port),
                    password: config.password,
                    automaticReconnect: false
                ),
                transportFactory: { mock }
            )
        })

        _ = try await adapter.pause(hash: "00112233445566778899aabbccddeeff", config: AMuleConnectionConfig(host: "127.0.0.1", password: "secret"))
        _ = try await adapter.pause(hash: "00112233445566778899aabbccddeeff", config: AMuleConnectionConfig(host: "localhost", password: "secret"))

        let firstDisconnects = await firstMock.disconnectCalls()
        let secondDisconnects = await secondMock.disconnectCalls()
        XCTAssertEqual(firstDisconnects, 1)
        XCTAssertEqual(secondDisconnects, 0)
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

        let acknowledgement = try await adapter.rename(
            hash: "00112233445566778899aabbccddeeff",
            name: "中文.iso",
            config: AMuleConnectionConfig(password: "secret")
        )

        XCTAssertEqual(acknowledgement, .failure(message: "Unable to rename file.", raw: #"{"error":"Unable to rename file.","ok":false}"#))
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
        assertJSONEqual(result.raw, try XCTUnwrap(ECJsonEnvelopeFixtures.messageByOperation["rename"]))
        let sentOpcodes = await mock.sentOpcodes()
        XCTAssertEqual(sentOpcodes, [0x02, 0x50, 0x25])
    }

    func testAdapterMutationEnvelopesMatchFixtureMessages() async throws {
        let config = AMuleConnectionConfig(password: "secret")
        let hash = "00112233445566778899aabbccddeeff"

        let scenarios: [(String, [ECPacket], (SwiftECBridgeAdapter) async throws -> (message: String, raw: String), UInt8)] = [
            ("pause", [Self.salt, Self.authOK, ECPacket(opcode: 0x01)], { try await $0.pause(hash: hash, config: config) }, 0x19),
            ("resume", [Self.salt, Self.authOK, ECPacket(opcode: 0x01)], { try await $0.resume(hash: hash, config: config) }, 0x1A),
            ("cancel", [Self.salt, Self.authOK, ECPacket(opcode: 0x01)], { try await $0.cancel(hash: hash, config: config) }, 0x1D),
            ("priority", [Self.salt, Self.authOK, ECPacket(opcode: 0x01)], { try await $0.priority(hash: hash, value: "3", config: config) }, 0x1C),
            ("clear-completed", [Self.salt, Self.authOK, ECPacket(opcode: 0x01)], { try await $0.clearCompleted(ecids: [42], config: config) }, 0x53),
            ("server-connect", [Self.salt, Self.authOK, ECPacket(opcode: 0x01)], { try await $0.serverConnect(ip: "1.2.3.4", port: 4661, config: config) }, 0x2F),
            ("server-disconnect", [Self.salt, Self.authOK, ECPacket(opcode: 0x01)], { try await $0.serverDisconnect(config: config) }, 0x2E),
            ("server-add", [Self.salt, Self.authOK, ECPacket(opcode: 0x01)], { try await $0.serverAdd(address: "1.2.3.4:4661", name: "Fixture", config: config) }, 0x31),
            ("server-remove", [Self.salt, Self.authOK, ECPacket(opcode: 0x01)], { try await $0.serverRemove(ip: "1.2.3.4", port: 4661, config: config) }, 0x30),
            ("server-update-from-url", [Self.salt, Self.authOK, ECPacket(opcode: 0x01)], { try await $0.serverUpdateFromURL(url: "https://example.test/server.met", config: config) }, 0x32),
            ("prefs-connection-set", [Self.salt, Self.authOK, ECPacket(opcode: 0x01)], { try await $0.prefsConnectionSet(maxDownload: 512, maxUpload: 64, config: config) }, 0x40),
            ("category-create", [Self.salt, Self.authOK, ECPacket(opcode: 0x01)], { try await $0.categoryCreate(name: "Linux ISO", path: "/downloads/linux", comment: "Fixture category", color: 0xff00ff, priority: 2, config: config) }, 0x41),
            ("category-delete", [Self.salt, Self.authOK, ECPacket(opcode: 0x01)], { try await $0.categoryDelete(categoryID: 7, config: config) }, 0x43),
        ]

        for (name, replies, call, expectedOpcode) in scenarios {
            let mock = AdapterMockTransport(replies: replies)
            let session = ECSession(configuration: .init(host: "127.0.0.1", port: 4712, password: "secret", automaticReconnect: false), transportFactory: { mock })
            let adapter = SwiftECBridgeAdapter(session: session)

            let result = try await call(adapter)

            assertJSONEqual(result.raw, try XCTUnwrap(ECJsonEnvelopeFixtures.messageByOperation[name]), "fixture mismatch for \(name)")
            let sentOpcodes = await mock.sentOpcodes()
            XCTAssertEqual(sentOpcodes, [0x02, 0x50, expectedOpcode], "opcode mismatch for \(name)")
        }
    }

    func testAdapterBuildsInitialDownloadBaselineWithFullQueueBeforeIncrementalUpdates() async throws {
        let mock = AdapterMockTransport(replies: [
            Self.salt,
            Self.authOK,
            ECPacket(opcode: 0x1F, tags: [
                try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "current.iso"),
            ]),
            ECPacket(opcode: 0x22, tags: [
                try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "current.iso", sourceNameEntries: [
                    ECDownloadPacketFixtures.sourceNameEntry(id: 7, name: "better.iso", count: 3),
                ]),
            ]),
        ])
        let session = ECSession(configuration: .init(host: "127.0.0.1", port: 4712, password: "secret", automaticReconnect: false), transportFactory: { mock })
        let adapter = SwiftECBridgeAdapter(session: session)

        let (initialDownloads, _) = try await adapter.downloads(config: AMuleConnectionConfig(password: "secret"))
        let (updatedDownloads, _) = try await adapter.downloads(config: AMuleConnectionConfig(password: "secret"))

        XCTAssertEqual(initialDownloads.first?.name, "current.iso")
        XCTAssertEqual(updatedDownloads.first?.alternativeNames, [
            ECDownload.AlternativeName(name: "better.iso", count: 3),
        ])
        let sentOpcodes = await mock.sentOpcodes()
        XCTAssertEqual(sentOpcodes, [0x02, 0x50, 0x0D, 0x52])
    }

    func testAdapterReturnsStableDownloadSnapshotWhenUpdateSucceeds() async throws {
        let mock = AdapterMockTransport(replies: [
            Self.salt,
            Self.authOK,
            ECPacket(opcode: 0x1F, tags: [
                try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "current.iso"),
            ]),
        ])
        let session = ECSession(configuration: .init(host: "127.0.0.1", port: 4712, password: "secret", automaticReconnect: false), transportFactory: { mock })
        let adapter = SwiftECBridgeAdapter(session: session)

        let (downloads, _) = try await adapter.downloads(config: AMuleConnectionConfig(password: "secret"))

        XCTAssertEqual(downloads.count, 1)
        XCTAssertEqual(downloads.first?.name, "current.iso")
        XCTAssertEqual(downloads.first?.alternativeNames, [])
        let sentOpcodes = await mock.sentOpcodes()
        XCTAssertEqual(sentOpcodes, [0x02, 0x50, 0x0D])
    }

    func testAdapterResyncsFullDownloadQueueWhenIncrementalUpdateContainsUnknownSparsePartFile() async throws {
        let mock = AdapterMockTransport(replies: [
            Self.salt,
            Self.authOK,
            ECPacket(opcode: 0x1F, tags: [
                try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "current.iso"),
            ]),
            ECPacket(opcode: 0x22, tags: [
                ECTag.integer(name: 0x0300, value: 77, children: [
                    ECTag.integer(name: 0x0303, value: 100),
                ]),
            ]),
            ECPacket(opcode: 0x1F, tags: [
                try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "current.iso"),
                try ECDownloadPacketFixtures.partFile(ecid: 77, hash: Self.otherHash, name: "new.iso"),
            ]),
        ])
        let session = ECSession(configuration: .init(host: "127.0.0.1", port: 4712, password: "secret", automaticReconnect: false), transportFactory: { mock })
        let adapter = SwiftECBridgeAdapter(session: session)

        _ = try await adapter.downloads(config: AMuleConnectionConfig(password: "secret"))
        let (downloads, _) = try await adapter.downloads(config: AMuleConnectionConfig(password: "secret"))

        XCTAssertEqual(downloads.map(\.name), ["current.iso", "new.iso"])
        XCTAssertFalse(downloads.contains { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        let sentOpcodes = await mock.sentOpcodes()
        XCTAssertEqual(sentOpcodes, [0x02, 0x50, 0x0D, 0x52, 0x0D])
    }

    func testAdapterPreservesSourcesAcrossPartialClientDeltas() async throws {
        let mock = AdapterMockTransport(replies: [
            Self.salt,
            Self.authOK,
            ECPacket(opcode: 0x1F, tags: [
                try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "current.iso"),
            ]),
            ECPacket(opcode: 0x22, tags: [
                ECDownloadPacketFixtures.client(id: 99, children: [
                    .integer(name: 0x0620, value: 42),
                    ECTag(name: 0x0100, type: .string, value: .string("peer")),
                    .integer(name: 0x060C, value: 2),
                    ECTag(name: 0x060E, type: .double, value: .double(1.5)),
                ]),
            ]),
            ECPacket(opcode: 0x1F, tags: [
                try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "current.iso"),
            ]),
            ECPacket(opcode: 0x22, tags: [
                ECDownloadPacketFixtures.client(id: 99, children: [
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

    func testAdapterFriendsUsesFriendsCapabilityRatherThanSourcesCapability() async throws {
        let mock = AdapterMockTransport(replies: [
            Self.salt,
            Self.authOK,
            ECPacket(opcode: 0x22, tags: [
                ECDownloadPacketFixtures.friendContainer([
                    try ECDownloadPacketFixtures.friend(id: 7, name: "Peer", hash: Self.hash, ip: 0x05060708, port: 4662, clientID: 123),
                ]),
            ]),
        ])
        let session = ECSession(configuration: .init(host: "127.0.0.1", port: 4712, password: "secret", automaticReconnect: false), transportFactory: { mock })
        let capabilities = ECCapabilities(ops: [ECSupportedOps.friends])
        let adapter = SwiftECBridgeAdapter(session: session, capabilities: capabilities)

        let (friends, raw) = try await adapter.friends(config: AMuleConnectionConfig(password: "secret"))

        XCTAssertEqual(friends, [
            ECFriend(
                id: 7,
                name: "Peer",
                hash: Self.hash,
                ip: "5.6.7.8",
                port: 4662,
                client: "123",
                friendSlot: false
            ),
        ])
        XCTAssertTrue(raw.contains(#""friends""#))
        let sentOpcodes = await mock.sentOpcodes()
        XCTAssertEqual(sentOpcodes, [0x02, 0x50, 0x52])
    }

    func testAdapterRejectsMissingCapabilityBeforeSending() async throws {
        let mock = AdapterMockTransport(replies: [Self.salt, Self.authOK, ECPacket(opcode: 0x01)])
        let session = ECSession(configuration: .init(host: "127.0.0.1", port: 4712, password: "secret", automaticReconnect: false), transportFactory: { mock })
        let capabilities = ECCapabilities(ops: [ECSupportedOps.status])
        let adapter = SwiftECBridgeAdapter(session: session, capabilities: capabilities)

        do {
            _ = try await adapter.pause(hash: Self.hash, config: AMuleConnectionConfig(password: "secret"))
            XCTFail("Expected unsupported operation")
        } catch let error as ECOperationError {
            XCTAssertEqual(error, .unsupportedOperation("pause"))
        }

        let sentOpcodes = await mock.sentOpcodes()
        XCTAssertEqual(sentOpcodes, [])
    }

    func testAdapterDownloadsUsesFullBaselineRegardlessOfSourcesCapability() async throws {
        let mock = AdapterMockTransport(replies: [
            Self.salt,
            Self.authOK,
            ECPacket(opcode: 0x1F, tags: [
                try ECDownloadPacketFixtures.partFile(ecid: 42, hash: Self.hash, name: "current.iso"),
            ]),
        ])
        let session = ECSession(configuration: .init(host: "127.0.0.1", port: 4712, password: "secret", automaticReconnect: false), transportFactory: { mock })
        let capabilities = ECCapabilities(ops: [ECSupportedOps.downloads])
        let adapter = SwiftECBridgeAdapter(session: session, capabilities: capabilities)

        let (downloads, _) = try await adapter.downloads(config: AMuleConnectionConfig(password: "secret"))

        XCTAssertEqual(downloads.count, 1)
        XCTAssertEqual(downloads.first?.name, "current.iso")
        let sentOpcodes = await mock.sentOpcodes()
        XCTAssertEqual(sentOpcodes, [0x02, 0x50, 0x0D])
    }

    func testAdapterSourcesEnvelopeMatchesFixture() async throws {
        let mock = AdapterMockTransport(replies: [
            Self.salt,
            Self.authOK,
            ECPacket(opcode: 0x1F, tags: [
                try ECDownloadPacketFixtures.partFile(ecid: 1001, hash: Self.hash, name: "fixture.iso"),
            ]),
            ECPacket(opcode: 0x22, tags: [
                ECDownloadPacketFixtures.client(id: 501, children: [
                    .integer(name: 0x0620, value: 1001),
                    ECTag(name: 0x0100, type: .string, value: .string("peer")),
                    ECTag(name: 0x0610, type: .ipv4, value: .ipv4(ECIPv4Address(10, 0, 0, 2, port: 0))),
                    .integer(name: 0x0611, value: 4662),
                    ECTag(name: 0x0614, type: .string, value: .string("ExampleServer")),
                    ECTag(name: 0x0612, type: .ipv4, value: .ipv4(ECIPv4Address(1, 2, 3, 4, port: 0))),
                    .integer(name: 0x0613, value: 4661),
                    .integer(name: 0x0601, value: 9),
                    ECTag(name: 0x0615, type: .string, value: .string("2.3.3")),
                    .integer(name: 0x060C, value: 3),
                    .integer(name: 0x060F, value: 2),
                    ECTag(name: 0x060E, type: .double, value: .double(12.5)),
                    .integer(name: 0x062A, value: 8),
                    .integer(name: 0x061A, value: 12),
                    .integer(name: 0x0618, value: 1),
                    .integer(name: 0x061D, value: 1),
                    ECTag(name: 0x0627, type: .string, value: .string("fixture.iso")),
                ]),
            ]),
        ])
        let session = ECSession(configuration: .init(host: "127.0.0.1", port: 4712, password: "secret", automaticReconnect: false), transportFactory: { mock })
        let adapter = SwiftECBridgeAdapter(session: session)

        let (_, raw) = try await adapter.sources(hash: Self.hash, config: AMuleConnectionConfig(password: "secret"))

        assertJSONEqual(raw, ECJsonEnvelopeFixtures.sources)
    }

    func testAdapterCategoriesEnvelopeMatchesFixture() async throws {
        let mock = AdapterMockTransport(replies: [
            Self.salt,
            Self.authOK,
            ECPacket(opcode: 0x40, tags: [
                ECTag(name: 0x1100, type: .custom, children: [
                    ECTag.integer(name: 0x1101, value: 7, children: [
                        ECTag(name: 0x1102, type: .string, value: .string("Linux ISO")),
                        ECTag(name: 0x1103, type: .string, value: .string("/downloads/linux")),
                        ECTag(name: 0x1104, type: .string, value: .string("Fixture category")),
                        ECTag.integer(name: 0x1105, value: 0xff00ff),
                        ECTag.integer(name: 0x1106, value: 2),
                    ]),
                ]),
            ]),
        ])
        let session = ECSession(configuration: .init(host: "127.0.0.1", port: 4712, password: "secret", automaticReconnect: false), transportFactory: { mock })
        let adapter = SwiftECBridgeAdapter(session: session)

        let (_, raw) = try await adapter.categories(config: AMuleConnectionConfig(password: "secret"))

        assertJSONEqual(raw, ECJsonEnvelopeFixtures.categories)
        let sentOpcodes = await mock.sentOpcodes()
        XCTAssertEqual(sentOpcodes, [0x02, 0x50, 0x3F])
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
    private static let otherHash = "ffeeddccbbaa99887766554433221100"

    private func assertJSONEqual(
        _ lhs: String,
        _ rhs: String,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let lhsObject = try? JSONSerialization.jsonObject(with: Data(lhs.utf8), options: [.fragmentsAllowed]) as AnyObject
        let rhsObject = try? JSONSerialization.jsonObject(with: Data(rhs.utf8), options: [.fragmentsAllowed]) as AnyObject
        XCTAssertEqual(lhsObject?.isEqual(rhsObject), true, message(), file: file, line: line)
    }
}
