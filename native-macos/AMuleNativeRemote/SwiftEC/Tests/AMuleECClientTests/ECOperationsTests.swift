import XCTest
import Foundation
import AMuleECProtocol
import Fixtures
@testable import AMuleECClient

final class ECOperationsTests: XCTestCase {
    func testOperationBuildersUseBridgeOpcodesAndDetailLevels() throws {
        let status = try ECOperations.status()
        XCTAssertEqual(status.opcode, 0x0A)
        XCTAssertEqual(status.tags.first?.name, 0x0004)
        XCTAssertEqual(try ECPacketHeader.decode(status.encode().prefix(ECPacketHeader.byteCount)).flags, 0x20)

        let downloads = try ECOperations.downloads()
        XCTAssertEqual(downloads.opcode, 0x0D)
        XCTAssertTrue(downloads.tags.isEmpty)

        let servers = try ECOperations.servers()
        XCTAssertEqual(servers.opcode, 0x2C)
        XCTAssertTrue(servers.tags.isEmpty)

        let sourcePackets = try ECOperations.sources(hash: "00112233445566778899aabbccddeeff")
        XCTAssertEqual(sourcePackets.map(\.opcode), [0x0D, 0x52])
        XCTAssertEqual(sourcePackets[0].tags.first?.value, .uint(0x00))
        XCTAssertEqual(sourcePackets[1].tags.first?.value, .uint(0x04))

        let friends = try ECOperations.friends()
        XCTAssertEqual(friends.opcode, 0x52)
        XCTAssertEqual(friends.tags.first?.value, .uint(0x04))
    }

    func testMutatingOperationBuildersUseBridgeOpcodesAndTags() throws {
        XCTAssertEqual(try ECOperations.search(scope: "global", query: "ubuntu").opcode, 0x26)
        XCTAssertEqual(try ECOperations.searchStop().opcode, 0x27)
        XCTAssertEqual(ECOperations.searchProgress().opcode, 0x29)
        XCTAssertEqual(ECOperations.searchResults().opcode, 0x28)
        XCTAssertTrue(ECOperations.searchResults().tags.isEmpty)

        let hash = "00112233445566778899aabbccddeeff"
        XCTAssertEqual(try ECOperations.download(hash: hash).opcode, 0x2A)
        XCTAssertEqual(try ECOperations.addLink("ed2k://|file|x|1|00112233445566778899aabbccddeeff|h=abc|").opcode, 0x09)
        XCTAssertEqual(try ECOperations.pause(hash: hash).opcode, 0x19)
        XCTAssertEqual(try ECOperations.resume(hash: hash).opcode, 0x1A)
        let rename = try ECOperations.rename(hash: hash, name: "renamed.iso")
        XCTAssertEqual(rename.tags.map(\.name), [0x0400, 0x0301])
        let priority = try ECOperations.priority(hash: hash, value: 2)
        XCTAssertEqual(priority.tags.first?.name, 0x0300)
        XCTAssertEqual(priority.tags.first?.children.first?.name, 0x0309)
        let clear = try ECOperations.clearCompleted(ecids: [42])
        XCTAssertEqual(clear.tags.first?.name, 0x000F)
        XCTAssertEqual(try ECOperations.serverConnect(ip: "1.2.3.4", port: 4661).opcode, 0x2F)
        XCTAssertEqual(try ECOperations.serverDisconnect().opcode, 0x2E)
        XCTAssertEqual(try ECOperations.serverAdd(address: "1.2.3.4:4661", name: "srv").opcode, 0x31)
        XCTAssertEqual(try ECOperations.serverRemove(ip: "1.2.3.4", port: 4661).opcode, 0x30)
        XCTAssertEqual(try ECOperations.serverUpdateFromURL(url: "https://example.test/server.met").tags.first?.name, 0x170C)
        XCTAssertEqual(try ECOperations.kadUpdateFromURL(url: "https://example.test/nodes.dat").tags.first?.name, 0x1E01)
        XCTAssertEqual(try ECOperations.prefsConnectionGet().opcode, 0x3F)
        XCTAssertEqual(try ECOperations.prefsConnectionGet().tags.first { $0.name == 0x1000 }?.value, .uint(0x04))
        let prefsSet = try ECOperations.prefsConnectionSet(maxDownload: 512, maxUpload: 64)
        XCTAssertEqual(prefsSet.opcode, 0x40)
        XCTAssertNil(prefsSet.tags.first { $0.name == 0x0004 })
    }

    func testRenamePacketMatchesNativeBridgeWireFormat() throws {
        let packet = try ECOperations.rename(hash: "00112233445566778899aabbccddeeff", name: "renamed.iso")
        let body = try packet.encodeBody()

        XCTAssertEqual(
            body.map { String(format: "%02x", $0) }.joined(),
            "2500020800090000001000112233445566778899aabbccddeeff0602060000000c72656e616d65642e69736f00"
        )
    }

    func testRenamePacketMatchesNativeBridgeUTF8NumberWireFormat() throws {
        let packet = try ECOperations.rename(hash: "00112233445566778899aabbccddeeff", name: "renamed.iso")
        let body = try packet.encodeBody(utf8Numbers: true)

        XCTAssertEqual(
            body.map { String(format: "%02x", $0) }.joined(),
            "2502e0a080091000112233445566778899aabbccddeeffd882060c72656e616d65642e69736f00"
        )

        let decoded = try ECPacket.decodeBody(body, flags: ECPacket.protocolBaseFlags | ECPacket.utf8NumbersFlag)
        XCTAssertEqual(decoded.opcode, packet.opcode)
        XCTAssertEqual(decoded.tags, packet.tags)
    }

    func testMutationBuildersPreserveExpectedFixtureTags() throws {
        let hash = "00112233445566778899aabbccddeeff"

        let pause = try ECOperations.pause(hash: hash)
        XCTAssertEqual(pause.tags.map(\.name), [ECOperations.TagName.partFile])
        XCTAssertEqual(pause.tags.first?.hashStringValue, hash)

        let resume = try ECOperations.resume(hash: hash)
        XCTAssertEqual(resume.tags.map(\.name), [ECOperations.TagName.partFile])
        XCTAssertEqual(resume.tags.first?.hashStringValue, hash)

        let cancel = try ECOperations.cancel(hash: hash)
        XCTAssertEqual(cancel.tags.map(\.name), [ECOperations.TagName.partFile])
        XCTAssertEqual(cancel.tags.first?.hashStringValue, hash)

        let priority = try ECOperations.priority(hash: hash, value: 3)
        XCTAssertEqual(priority.tags.first?.hashStringValue, hash)
        XCTAssertEqual(priority.tags.first?.children.first?.name, ECOperations.TagName.partFilePriority)
        XCTAssertEqual(priority.tags.first?.children.first?.intValue, 3)

        let clearCompleted = try ECOperations.clearCompleted(ecids: [42, -7])
        XCTAssertEqual(clearCompleted.tags.map(\.name), [ECOperations.TagName.ecid, ECOperations.TagName.ecid])
        XCTAssertEqual(clearCompleted.tags.map(\.intValue), [42, 0])

        let serverConnect = try ECOperations.serverConnect(ip: "1.2.3.4", port: 4661)
        XCTAssertEqual(serverConnect.tags.first?.name, ECOperations.TagName.server)
        XCTAssertEqual(serverConnect.tags.first?.ipStringValue, "1.2.3.4")
        if case .ipv4(let serverConnectAddress) = serverConnect.tags.first?.value {
            XCTAssertEqual(serverConnectAddress.port, 4661)
        } else {
            XCTFail("Expected IPv4 server-connect tag")
        }

        let serverAdd = try ECOperations.serverAdd(address: "1.2.3.4:4661", name: "Fixture")
        XCTAssertEqual(serverAdd.tags.map(\.name), [ECOperations.TagName.serverAddress, ECOperations.TagName.serverName])
        XCTAssertEqual(serverAdd.tags.first?.stringValue, "1.2.3.4:4661")
        XCTAssertEqual(serverAdd.tags.last?.stringValue, "Fixture")

        let serverRemove = try ECOperations.serverRemove(ip: "1.2.3.4", port: 4661)
        XCTAssertEqual(serverRemove.tags.first?.name, ECOperations.TagName.server)
        XCTAssertEqual(serverRemove.tags.first?.ipStringValue, "1.2.3.4")
        if case .ipv4(let serverRemoveAddress) = serverRemove.tags.first?.value {
            XCTAssertEqual(serverRemoveAddress.port, 4661)
        } else {
            XCTFail("Expected IPv4 server-remove tag")
        }

        let serverUpdate = try ECOperations.serverUpdateFromURL(url: "https://example.test/server.met")
        XCTAssertEqual(serverUpdate.tags.first?.name, ECOperations.TagName.serversUpdateURL)
        XCTAssertEqual(serverUpdate.tags.first?.stringValue, "https://example.test/server.met")

        let prefsSet = try ECOperations.prefsConnectionSet(maxDownload: 512, maxUpload: 64)
        XCTAssertEqual(prefsSet.tags.map(\.name), [ECOperations.TagName.selectPrefs, ECOperations.TagName.prefsConnections])
        XCTAssertEqual(prefsSet.tags.first?.intValue, 4)
        XCTAssertEqual(prefsSet.tags.last?.children.map(\.name), [ECOperations.TagName.connMaxDownload, ECOperations.TagName.connMaxUpload])
        XCTAssertEqual(prefsSet.tags.last?.children.map(\.intValue), [512, 64])

        let categories = try ECOperations.categories()
        XCTAssertEqual(categories.opcode, ECOperations.OpCode.getPreferences)
        XCTAssertEqual(categories.tags.map(\.name), [ECOperations.TagName.selectPrefs])
        XCTAssertEqual(categories.tags.first?.intValue, 1)

        let categoryCreate = try ECOperations.categoryCreate(name: "Linux ISO", path: "/downloads/linux", comment: "Fixture category", color: 0xff00ff, priority: 2)
        XCTAssertEqual(categoryCreate.tags.first?.name, ECOperations.TagName.category)
        XCTAssertEqual(categoryCreate.tags.first?.children.map(\.name), [
            ECOperations.TagName.categoryTitle,
            ECOperations.TagName.categoryPath,
            ECOperations.TagName.categoryComment,
            ECOperations.TagName.categoryColor,
            ECOperations.TagName.categoryPriority,
        ])

        let categoryDelete = try ECOperations.categoryDelete(categoryID: 7)
        XCTAssertEqual(categoryDelete.tags.first?.name, ECOperations.TagName.category)
        XCTAssertEqual(categoryDelete.tags.first?.intValue, 7)
    }

    func testCapabilityGateRejectsUnsupportedReadOnlyOperation() throws {
        let gate = ECCapabilityGate([ECSupportedOps.status])
        XCTAssertNoThrow(try gate.require(.status))
        XCTAssertThrowsError(try ECOperations.downloads(gate: gate)) { error in
            XCTAssertEqual(error as? ECOperationError, .unsupportedOperation("downloads"))
        }
    }

    func testFriendsBuilderUsesFriendsCapabilityInsteadOfSourcesCapability() throws {
        let gate = ECCapabilityGate([ECSupportedOps.friends])

        XCTAssertNoThrow(try ECOperations.friends(gate: gate))
        XCTAssertThrowsError(try ECOperations.sourcesUpdate(gate: gate)) { error in
            XCTAssertEqual(error as? ECOperationError, .unsupportedOperation("sources"))
        }
    }

    func testDisabledOperationNamesRemainUnadvertisedAndRejected() throws {
        let disabledOperations = [
            ECOperationName.categoryUpdate.rawValue,
            ECOperationName.downloadSetCategory.rawValue,
        ]

        XCTAssertEqual(ECSupportedOps.unsupportedDisabledOperations, disabledOperations)
        for operation in disabledOperations {
            XCTAssertFalse(ECSupportedOps.allOperations.contains(operation), operation)
            XCTAssertFalse(ECOperations.capabilities().ops.contains(operation), operation)
        }

        let gate = ECCapabilityGate(capabilities: ECOperations.capabilities())
        XCTAssertThrowsError(try gate.require(.categoryUpdate)) { error in
            XCTAssertEqual(error as? ECOperationError, .unsupportedOperation("category-update"))
        }
        XCTAssertThrowsError(try gate.require(.downloadSetCategory)) { error in
            XCTAssertEqual(error as? ECOperationError, .unsupportedOperation("download-set-category"))
        }
    }

    func testStatusParserAndEnvelopeMatchBridgeShape() throws {
        let packet = ECPacket(opcode: 0x0C, tags: [
            .integer(name: 0x0005, value: 1),
            .integer(name: 0x0201, value: 1024),
            .integer(name: 0x0200, value: 512),
            .integer(name: 0x0208, value: 7),
            .integer(name: 0x0206, value: 99),
        ])

        let status = try ECResponseParser.parseStatus(packet)
        XCTAssertEqual(status, ECStatus(connected: true, ed2k: "Connected", kad: "Unknown", downloadSpeed: 1024, uploadSpeed: 512, queue: 7, sources: 99))

        let json = try jsonObject(ECJSONEnvelope.status(status))
        XCTAssertEqual(json["ok"] as? Bool, true)
        let payload = try XCTUnwrap(json["status"] as? [String: Any])
        XCTAssertEqual(payload["download_speed"] as? Int, 1024)
        XCTAssertEqual(payload["upload_speed"] as? Int, 512)
        XCTAssertNil(json["success"])
    }

    func testDownloadParserAndEnvelopeMatchBridgeShape() throws {
        let hash = Data((0..<16).map(UInt8.init))
        let packet = ECPacket(opcode: 0x1F, tags: [
            ECTag(name: 0x0300, type: .uint32, value: .uint(42), children: [
                ECTag(name: 0x031E, type: .hash16, value: .hash16(hash)),
                ECTag(name: 0x0301, type: .string, value: .string("file.iso")),
                .integer(name: 0x0303, value: 1000),
                .integer(name: 0x0306, value: 250),
                .integer(name: 0x0304, value: 300),
                .integer(name: 0x030A, value: 12),
                .integer(name: 0x030C, value: 2),
                .integer(name: 0x030D, value: 3),
                .integer(name: 0x030B, value: 1),
                .integer(name: 0x0308, value: 1),
                .integer(name: 0x0307, value: 4096),
                .integer(name: 0x0309, value: 2),
                .integer(name: 0x030F, value: 0),
                ECTag(name: 0x0302, type: .string, value: .string("001.part.met")),
                .integer(name: 0x0311, value: 123),
                .integer(name: 0x0310, value: 456),
                .integer(name: 0x031D, value: 8),
                .integer(name: 0x031F, value: 1),
            ]),
        ])

        let downloads = try ECResponseParser.parseDownloads(packet)
        XCTAssertEqual(downloads.count, 1)
        XCTAssertEqual(downloads[0].hash, "000102030405060708090a0b0c0d0e0f")
        XCTAssertEqual(downloads[0].sourcesCurrent, 10)
        XCTAssertEqual(downloads[0].progress, 25)

        let json = try jsonObject(ECJSONEnvelope.downloads(downloads))
        let payload = try XCTUnwrap((json["downloads"] as? [[String: Any]])?.first)
        XCTAssertEqual(payload["name_encoding_suspect"] as? Bool, false)
        XCTAssertTrue(payload.keys.contains("alternative_names"))
        XCTAssertTrue(payload.keys.contains("progress_colors"))
    }

    func testDownloadParserAddsNameEncodingSuggestion() throws {
        let hash = Data((0..<16).map(UInt8.init))
        let packet = ECPacket(opcode: 0x1F, tags: [
            ECTag(name: 0x0300, type: .uint32, value: .uint(42), children: [
                ECTag(name: 0x031E, type: .hash16, value: .hash16(hash)),
                ECTag(name: 0x0301, type: .string, value: .string("FranÃƒÂ§ais.iso")),
                .integer(name: 0x0303, value: 1000),
                .integer(name: 0x0306, value: 250),
                .integer(name: 0x0308, value: 0),
            ]),
        ])

        let download = try XCTUnwrap(ECResponseParser.parseDownloads(packet).first)
        XCTAssertEqual(download.name, "FranÃƒÂ§ais.iso")
        XCTAssertTrue(download.nameEncodingSuspect)
        XCTAssertEqual(download.nameEncodingSuggestion, "Français.iso")
    }

    func testDownloadParserExtractsAlternativeSourceNamesLikeNativeBridge() throws {
        let hash = Data((0..<16).map(UInt8.init))
        let packet = ECPacket(opcode: 0x1F, tags: [
            ECTag(name: 0x0300, type: .uint32, value: .uint(42), children: [
                ECTag(name: 0x031E, type: .hash16, value: .hash16(hash)),
                ECTag(name: 0x0301, type: .string, value: .string("current.iso")),
                .integer(name: 0x0303, value: 1000),
                .integer(name: 0x0306, value: 250),
                .integer(name: 0x0308, value: 0),
                ECTag(name: 0x0315, type: .custom, children: [
                    ECTag(name: 0x0315, type: .uint32, value: .uint(1), children: [
                        ECTag(name: 0x0315, type: .string, value: .string("better.iso")),
                        .integer(name: 0x031C, value: 7),
                    ]),
                    ECTag(name: 0x0315, type: .uint32, value: .uint(2), children: [
                        ECTag(name: 0x0315, type: .string, value: .string("current.iso")),
                        .integer(name: 0x031C, value: 4),
                    ]),
                    ECTag(name: 0x0315, type: .uint32, value: .uint(3), children: [
                        ECTag(name: 0x0315, type: .string, value: .string("also.iso")),
                        .integer(name: 0x031C, value: 2),
                    ]),
                ]),
            ]),
        ])

        let download = try XCTUnwrap(ECResponseParser.parseDownloads(packet).first)

        XCTAssertEqual(download.alternativeNames, [
            ECDownload.AlternativeName(name: "better.iso", count: 7),
            ECDownload.AlternativeName(name: "also.iso", count: 2),
        ])
    }

    func testDownloadParserBuildsEmuleProgressColorsFromGapPartAndRequestTags() throws {
        let partSize: UInt64 = 9_728_000
        let fileSize = partSize * 2
        let hash = Data((0..<16).map(UInt8.init))
        let packet = ECPacket(opcode: 0x1F, tags: [
            ECTag(name: 0x0300, type: .uint32, value: .uint(42), children: [
                ECTag(name: 0x031E, type: .hash16, value: .hash16(hash)),
                ECTag(name: 0x0301, type: .string, value: .string("file.iso")),
                .integer(name: 0x0303, value: fileSize),
                .integer(name: 0x0306, value: partSize),
                .integer(name: 0x0308, value: 1),
                ECTag(name: 0x0313, type: .custom, value: .custom(rleEncodedUInt64s([0, partSize]))),
                ECTag(name: 0x0312, type: .custom, value: .custom(rleEncodedBytes([2]))),
                ECTag(name: 0x0314, type: .custom, value: .custom(rleEncodedUInt64s([partSize, fileSize]))),
            ]),
        ])

        let download = try XCTUnwrap(ECResponseParser.parseDownloads(packet).first)

        XCTAssertEqual(download.progressColors.count, 64)
        guard download.progressColors.count == 64 else { return }
        XCTAssertEqual(download.progressColors[0], packedColor(r: 0, g: 188, b: 255))
        XCTAssertEqual(download.progressColors[31], packedColor(r: 0, g: 188, b: 255))
        XCTAssertEqual(download.progressColors[32], packedColor(r: 255, g: 208, b: 0))
        XCTAssertEqual(download.progressColors[63], packedColor(r: 255, g: 208, b: 0))
    }

    func testPartFileStatusTextMatchesNativeDownloadSections() throws {
        let hash = Data((0..<16).map(UInt8.init))
        let packet = ECPacket(opcode: 0x1F, tags: [
            ECTag(name: 0x0300, type: .uint32, value: .uint(42), children: [
                ECTag(name: 0x031E, type: .hash16, value: .hash16(hash)),
                ECTag(name: 0x0301, type: .string, value: .string("paused.iso")),
                .integer(name: 0x0303, value: 1000),
                .integer(name: 0x0306, value: 250),
                .integer(name: 0x0308, value: 7),
            ]),
        ])

        let download = try XCTUnwrap(ECResponseParser.parseDownloads(packet).first)
        XCTAssertEqual(download.statusCode, 7)
        XCTAssertEqual(download.status, "Paused")
        XCTAssertFalse(download.isCompleted)
    }

    func testPartFileStatusTextDownloadingWhenTransferring() throws {
        let hash = Data((0..<16).map(UInt8.init))
        let packet = ECPacket(opcode: 0x1F, tags: [
            ECTag(name: 0x0300, type: .uint32, value: .uint(42), children: [
                ECTag(name: 0x031E, type: .hash16, value: .hash16(hash)),
                ECTag(name: 0x0301, type: .string, value: .string("active.iso")),
                .integer(name: 0x0303, value: 1000),
                .integer(name: 0x0306, value: 250),
                .integer(name: 0x0308, value: 0),
                .integer(name: 0x030D, value: 3),
            ]),
        ])

        let download = try XCTUnwrap(ECResponseParser.parseDownloads(packet).first)
        XCTAssertEqual(download.statusCode, 0)
        XCTAssertEqual(download.status, "Downloading")
        XCTAssertFalse(download.isCompleted)
    }

    func testPartFileStatusTextWaitingWhenNotTransferring() throws {
        let hash = Data((0..<16).map(UInt8.init))
        let packet = ECPacket(opcode: 0x1F, tags: [
            ECTag(name: 0x0300, type: .uint32, value: .uint(42), children: [
                ECTag(name: 0x031E, type: .hash16, value: .hash16(hash)),
                ECTag(name: 0x0301, type: .string, value: .string("pending.iso")),
                .integer(name: 0x0303, value: 1000),
                .integer(name: 0x0306, value: 0),
                .integer(name: 0x0308, value: 0),
                .integer(name: 0x030D, value: 0),
            ]),
        ])

        let download = try XCTUnwrap(ECResponseParser.parseDownloads(packet).first)
        XCTAssertEqual(download.statusCode, 0)
        XCTAssertEqual(download.status, "Waiting")
        XCTAssertFalse(download.isCompleted)
    }

    func testServersParserAndEnvelopeMatchBridgeShape() throws {
        let packet = ECPacket(opcode: 0x2D, tags: [
            ECTag(name: 0x0500, type: .ipv4, value: .ipv4(ECIPv4Address(1, 2, 3, 4, port: 4661)), children: [
                ECTag(name: 0x0501, type: .string, value: .string("Server")),
                ECTag(name: 0x0502, type: .string, value: .string("Desc")),
                ECTag(name: 0x050B, type: .string, value: .string("17")),
                .integer(name: 0x0505, value: 10),
                .integer(name: 0x0506, value: 20),
                .integer(name: 0x0507, value: 30),
                .integer(name: 0x0504, value: 40),
                .integer(name: 0x0509, value: 1),
                .integer(name: 0x0508, value: 2),
                .integer(name: 0x050A, value: 1),
            ]),
        ])

        let servers = try ECResponseParser.parseServers(packet)
        XCTAssertEqual(servers, [ECServer(id: 1, name: "Server", description: "Desc", version: "17", address: "1.2.3.4:4661", ip: "1.2.3.4", port: 4661, users: 10, maxUsers: 20, files: 30, ping: 40, failed: 1, priority: 2, isStatic: true)])

        let json = try jsonObject(ECJSONEnvelope.servers(servers))
        let payload = try XCTUnwrap((json["servers"] as? [[String: Any]])?.first)
        XCTAssertEqual(payload["max_users"] as? Int, 20)
        XCTAssertEqual(payload["is_static"] as? Bool, true)
    }

    func testSourcesParserAndEnvelopeMatchBridgeShape() throws {
        let packet = ECPacket(opcode: 0x22, tags: [
            ECTag(name: 0x0600, type: .uint32, value: .uint(99), children: [
                .integer(name: 0x0620, value: 42),
                ECTag(name: 0x0100, type: .string, value: .string("Client")),
                ECTag(name: 0x0610, type: .ipv4, value: .ipv4(ECIPv4Address(5, 6, 7, 8, port: 0))),
                .integer(name: 0x0611, value: 1234),
                ECTag(name: 0x0614, type: .string, value: .string("Srv")),
                ECTag(name: 0x0612, type: .ipv4, value: .ipv4(ECIPv4Address(1, 1, 1, 1, port: 0))),
                .integer(name: 0x0613, value: 4661),
                .integer(name: 0x0601, value: 0),
                ECTag(name: 0x0615, type: .string, value: .string("1.0")),
                .integer(name: 0x060C, value: 3),
                .integer(name: 0x060F, value: 1),
                ECTag(name: 0x060E, type: .double, value: .double(12.5)),
                .integer(name: 0x062A, value: 5),
                .integer(name: 0x061A, value: 12),
                .integer(name: 0x0618, value: 1),
                .integer(name: 0x061D, value: 1),
                ECTag(name: 0x0627, type: .string, value: .string("remote.bin")),
            ]),
        ])

        let sources = try ECResponseParser.parseSources(packet, requestFileID: 42)
        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources[0].clientID, 99)
        XCTAssertEqual(sources[0].userIP, "5.6.7.8")
        XCTAssertEqual(sources[0].downSpeedKBps, 12.5)

        let json = try jsonObject(ECJSONEnvelope.sources(sources))
        let payload = try XCTUnwrap((json["sources"] as? [[String: Any]])?.first)
        XCTAssertEqual(payload["client_id"] as? Int, 99)
        XCTAssertEqual(payload["down_speed_kbps"] as? Double, 12.5)
        XCTAssertEqual(payload["extended_protocol"] as? Bool, true)
    }

    func testFriendsParserHandlesNestedUpdateContainerAndEnvelope() throws {
        let packet = ECPacket(opcode: 0x22, tags: [
            ECTag(name: 0x0800, type: .unknown, children: [
                ECTag.integer(name: 0x0800, value: 7, children: [
                    ECTag(name: 0x0801, type: .string, value: .string("Peer")),
                    ECTag(name: 0x0802, type: .hash16, value: .hash16(Data((0..<16).map(UInt8.init)))),
                    .integer(name: 0x0803, value: 0x05060708),
                    .integer(name: 0x0804, value: 4662),
                    .integer(name: 0x0805, value: 123),
                ]),
            ]),
        ])

        let friends = try ECResponseParser.parseFriends(packet)

        XCTAssertEqual(friends, [
            ECFriend(
                id: 7,
                name: "Peer",
                hash: "000102030405060708090a0b0c0d0e0f",
                ip: "5.6.7.8",
                port: 4662,
                client: "123",
                friendSlot: false
            ),
        ])
        let json = try jsonObject(ECJSONEnvelope.friends(friends))
        let payload = try XCTUnwrap((json["friends"] as? [[String: Any]])?.first)
        XCTAssertEqual(payload["id"] as? Int, 7)
        XCTAssertEqual(payload["name"] as? String, "Peer")
    }

    func testMutationParsersAndEnvelopesMatchBridgeShape() throws {
        let message = try ECResponseParser.parseMutationResponse(ECPacket(opcode: 0x01), successMessage: "Action completed")
        XCTAssertEqual(message, "Action completed")
        XCTAssertThrowsError(try ECResponseParser.parseMutationResponse(ECPacket(opcode: 0x05, tags: [ECTag(name: 0x0000, type: .string, value: .string("nope"))]), successMessage: "ok"))
        XCTAssertThrowsError(try ECResponseParser.parseMutationResponse(ECPacket(opcode: 0x04), successMessage: "ok")) { error in
            XCTAssertEqual(error as? ECResponseParserError, .unexpectedOpcode(expected: 0x01, actual: 0x04))
        }
        XCTAssertEqual(
            try ECResponseParser.parseMutationResponse(ECPacket(opcode: 0x06), successMessage: "Download request accepted", expectedSuccessOpcodes: [0x06]),
            "Download request accepted"
        )

        let searchPacket = ECPacket(opcode: 0x28, tags: [
            ECTag(name: 0x0700, type: .uint32, value: .uint(7), children: [
                ECTag(name: 0x031E, type: .hash16, value: .hash16(Data((0..<16).map(UInt8.init)))),
                ECTag(name: 0x0301, type: .string, value: .string("result.bin")),
                .integer(name: 0x0303, value: 1234),
                .integer(name: 0x030A, value: 5),
                .integer(name: 0x030D, value: 2),
                .integer(name: 0x0308, value: 2),
                .integer(name: 0x0709, value: 0),
            ]),
        ])
        let results = try ECResponseParser.parseSearchResults(searchPacket)
        XCTAssertEqual(results, [ECSearchResult(id: 7, hash: "000102030405060708090a0b0c0d0e0f", name: "result.bin", size: 1234, sources: 5, completeSources: 2, statusCode: 2, status: "Queued", parentID: 0, alreadyHave: true)])
        let searchJSON = try jsonObject(ECJSONEnvelope.search(progress: 80, results: results))
        XCTAssertEqual(searchJSON["progress"] as? Int, 80)
        XCTAssertEqual((searchJSON["results"] as? [[String: Any]])?.first?["complete_sources"] as? Int, 2)

        let prefsPacket = ECPacket(opcode: 0x40, tags: [
            ECTag(name: 0x1300, type: .custom, children: [
                .integer(name: 0x1303, value: 512),
                .integer(name: 0x1304, value: 64),
            ]),
        ])
        let prefs = try ECResponseParser.parseConnectionPrefs(prefsPacket)
        XCTAssertEqual(prefs, ECConnectionPrefs(maxDownload: 512, maxUpload: 64))
        let prefsJSON = try jsonObject(ECJSONEnvelope.prefsConnection(prefs))
        XCTAssertEqual((prefsJSON["prefs_connection"] as? [String: Any])?["max_dl"] as? Int, 512)
    }

    func testCategoriesParserAndEnvelopeMatchFixtureShape() throws {
        let packet = ECPacket(opcode: 0x40, tags: [
            ECTag(name: 0x1100, type: .custom, children: [
                ECTag.integer(name: 0x1101, value: 7, children: [
                    ECTag(name: 0x1102, type: .string, value: .string("Linux ISO")),
                    ECTag(name: 0x1103, type: .string, value: .string("/downloads/linux")),
                    ECTag(name: 0x1104, type: .string, value: .string("Fixture category")),
                    ECTag.integer(name: 0x1105, value: 0xff00ff),
                    ECTag.integer(name: 0x1106, value: 2),
                ]),
            ]),
        ])

        let categories = try ECResponseParser.parseCategories(packet)
        XCTAssertEqual(categories, [ECCategory(id: 7, title: "Linux ISO", path: "/downloads/linux", comment: "Fixture category", color: 0xff00ff, priority: 2)])
        assertJSONEqual(ECJSONEnvelope.jsonString(try ECJSONEnvelope.categories(categories)), ECJsonEnvelopeFixtures.categories)
    }

    func testUnsupportedCapabilityCanBeSurfacedAsErrorEnvelope() throws {
        let gate = ECCapabilityGate([ECSupportedOps.status])

        XCTAssertThrowsError(try ECOperations.pause(hash: "00112233445566778899aabbccddeeff", gate: gate)) { error in
            XCTAssertEqual(error as? ECOperationError, .unsupportedOperation("pause"))
            self.assertJSONEqual(
                ECJSONEnvelope.jsonString(try! ECJSONEnvelope.error(error.localizedDescription)),
                ECJsonEnvelopeFixtures.unsupportedPause
            )
        }
    }

    func testReadParsersRejectUnexpectedResponseOpcodes() throws {
        assertUnexpectedOpcode(
            try ECResponseParser.parseStatus(ECPacket(opcode: 0x1F)),
            expected: 0x0C,
            actual: 0x1F
        )
        assertUnexpectedOpcode(
            try ECResponseParser.parseDownloads(ECPacket(opcode: 0x22)),
            expected: 0x1F,
            actual: 0x22
        )
        assertUnexpectedOpcode(
            try ECResponseParser.parseDownloadFileID(hash: "00112233445566778899aabbccddeeff", in: ECPacket(opcode: 0x22)),
            expected: 0x1F,
            actual: 0x22
        )
        assertUnexpectedOpcode(
            try ECResponseParser.parseSources(ECPacket(opcode: 0x52), requestFileID: 42),
            expected: 0x22,
            actual: 0x52
        )
        assertUnexpectedOpcode(
            try ECResponseParser.parseServers(ECPacket(opcode: 0x1F)),
            expected: 0x2D,
            actual: 0x1F
        )
        assertUnexpectedOpcode(
            try ECResponseParser.parseSearchProgress(ECPacket(opcode: 0x28)),
            expected: 0x29,
            actual: 0x28
        )
        assertUnexpectedOpcode(
            try ECResponseParser.parseSearchResults(ECPacket(opcode: 0x29)),
            expected: 0x28,
            actual: 0x29
        )
        assertUnexpectedOpcode(
            try ECResponseParser.parseConnectionPrefs(ECPacket(opcode: 0x3F)),
            expected: 0x40,
            actual: 0x3F
        )
        assertUnexpectedOpcode(
            try ECResponseParser.parseFriends(ECPacket(opcode: 0x52)),
            expected: 0x22,
            actual: 0x52
        )
    }

    func testReadParsersRejectFailedPacketsLikeNativeBridge() throws {
        let failed = ECPacket(opcode: 0x05, tags: [
            ECTag(name: 0x0000, type: .string, value: .string("daemon rejected request")),
        ])

        XCTAssertThrowsError(try ECResponseParser.parseStatus(failed)) { error in
            XCTAssertEqual(error as? ECResponseParserError, .operationFailed("daemon rejected request"))
        }
        XCTAssertThrowsError(try ECResponseParser.parseDownloads(failed)) { error in
            XCTAssertEqual(error as? ECResponseParserError, .operationFailed("daemon rejected request"))
        }
        XCTAssertThrowsError(try ECResponseParser.parseServers(failed)) { error in
            XCTAssertEqual(error as? ECResponseParserError, .operationFailed("daemon rejected request"))
        }
        XCTAssertThrowsError(try ECResponseParser.parseSources(failed, requestFileID: 42)) { error in
            XCTAssertEqual(error as? ECResponseParserError, .operationFailed("daemon rejected request"))
        }
    }

    func testCapabilitiesEnvelopeMatchesBridgeSchemaVersionShape() throws {
        let capabilities = ECCapabilities(bridgeVersion: "GIT", clientName: "aMuleNativeBridge", defaultHost: "127.0.0.1", defaultPort: 4712, ops: ["capabilities", "status"])
        let json = try jsonObject(ECJSONEnvelope.capabilities(capabilities))
        XCTAssertEqual(json["ok"] as? Bool, true)
        XCTAssertEqual(json["schema_version"] as? Int, 1)
        let payload = try XCTUnwrap(json["capabilities"] as? [String: Any])
        XCTAssertEqual(payload["bridge_version"] as? String, "GIT")
        XCTAssertEqual(payload["client_name"] as? String, "aMuleNativeBridge")
        XCTAssertEqual(payload["ops"] as? [String], ["capabilities", "status"])
    }

private func jsonObject(_ data: Data) throws -> [String: Any] {
    try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

    private func assertUnexpectedOpcode<T>(
        _ expression: @autoclosure () throws -> T,
        expected: UInt8,
        actual: UInt8,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            XCTAssertEqual(error as? ECResponseParserError, .unexpectedOpcode(expected: expected, actual: actual), file: file, line: line)
        }
    }

    private func assertJSONEqual(
        _ lhs: String,
        _ rhs: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let lhsObject = try? JSONSerialization.jsonObject(with: Data(lhs.utf8), options: [.fragmentsAllowed]) as AnyObject
        let rhsObject = try? JSONSerialization.jsonObject(with: Data(rhs.utf8), options: [.fragmentsAllowed]) as AnyObject
        XCTAssertEqual(lhsObject?.isEqual(rhsObject), true, file: file, line: line)
    }

    private func rleEncodedUInt64s(_ values: [UInt64]) -> Data {
        var bytes = [UInt8](repeating: 0, count: values.count * 8)
        for (index, value) in values.enumerated() {
            var remaining = value
            for byteIndex in 0..<8 {
                bytes[index + byteIndex * values.count] = UInt8(remaining & 0xff)
                remaining >>= 8
            }
        }
        return rleEncodedBytes(bytes)
    }

    private func rleEncodedBytes(_ bytes: [UInt8]) -> Data {
        var encoded: [UInt8] = []
        var index = 0
        while index < bytes.count {
            let value = bytes[index]
            var runLength = 1
            while index + runLength < bytes.count, bytes[index + runLength] == value, runLength < 0xff {
                runLength += 1
            }
            if runLength > 1 {
                encoded.append(value)
                encoded.append(value)
                encoded.append(UInt8(runLength))
            } else {
                encoded.append(value)
            }
            index += runLength
        }
        return Data(encoded)
    }

    private func packedColor(r: Int, g: Int, b: Int) -> UInt32 {
        (UInt32(b & 0xff) << 16) | (UInt32(g & 0xff) << 8) | UInt32(r & 0xff)
    }
}

private extension ECTag {
    var intValue: Int {
        if case .uint(let value) = value { return Int(value) }
        return 0
    }

    var stringValue: String? {
        if case .string(let value) = value { return value }
        return nil
    }

    var ipStringValue: String? {
        if case .ipv4(let value) = value {
            return "\(value.octets.0).\(value.octets.1).\(value.octets.2).\(value.octets.3)"
        }
        return nil
    }

    var hashStringValue: String {
        if case .hash16(let data) = value {
            return data.map { String(format: "%02x", $0) }.joined()
        }
        return ""
    }
}
