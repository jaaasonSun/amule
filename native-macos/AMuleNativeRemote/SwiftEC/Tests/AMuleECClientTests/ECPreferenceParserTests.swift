import XCTest
import AMuleECProtocol
@testable import AMuleECClient

final class ECPreferencesParserTests: XCTestCase {
    func testParsesConnectionPreferencesGroupFromPrefsPacket() throws {
        let prefs = try ECResponseParser.parseConnectionPrefs(ECPacket(opcode: 0x40, tags: [
            ECTag(name: 0x1300, type: .custom, children: [
                .integer(name: 0x1303, value: 512),
                .integer(name: 0x1304, value: 64),
                .integer(name: 0x1306, value: 4662),
                .integer(name: 0x1307, value: 4672),
                ECTag(name: 0x130D, type: .unknown),
            ]),
        ]))

        XCTAssertEqual(prefs.maxDownload, 512)
        XCTAssertEqual(prefs.maxUpload, 64)
        XCTAssertEqual(prefs.tcpPort, 4662)
        XCTAssertEqual(prefs.udpPort, 4672)
        XCTAssertEqual(prefs.udpEnabled, true)
        XCTAssertEqual(prefs.ed2kEnabled, true)
        XCTAssertEqual(prefs.kadEnabled, false)
    }

    func testParsesDirectoriesPreferencesGroupFromPrefsPacket() throws {
        let prefs = try ECResponseParser.parseConnectionPrefs(ECPacket(opcode: 0x40, tags: [
            ECTag(name: 0x1A00, type: .custom, children: [
                ECTag(name: 0x1A01, type: .string, value: .string("/incoming")),
                ECTag(name: 0x1A02, type: .string, value: .string("/temp")),
                ECTag.integer(name: 0x1A03, value: 2, children: [
                    ECTag(name: 0x0000, type: .string, value: .string("/shared/a")),
                    ECTag(name: 0x0000, type: .string, value: .string("/shared/b")),
                ]),
                .integer(name: 0x1A04, value: 1),
            ]),
        ]))

        XCTAssertEqual(prefs.incomingDirectory, "/incoming")
        XCTAssertEqual(prefs.tempDirectory, "/temp")
        XCTAssertEqual(prefs.sharedDirectories, ["/shared/a", "/shared/b"])
        XCTAssertEqual(prefs.shareHiddenFiles, true)
    }

    func testParsesServersPreferencesGroupFromPrefsPacket() throws {
        let prefs = try ECResponseParser.parseConnectionPrefs(ECPacket(opcode: 0x40, tags: [
            ECTag(name: 0x1700, type: .custom, children: [
                ECTag(name: 0x1701, type: .unknown),
                .integer(name: 0x1702, value: 3),
                ECTag(name: 0x1703, type: .unknown),
                ECTag(name: 0x170C, type: .string, value: .string("https://example.test/server.met")),
            ]),
        ]))

        XCTAssertEqual(prefs.removeDeadServers, true)
        XCTAssertEqual(prefs.deadServerRetries, 3)
        XCTAssertEqual(prefs.autoUpdateServers, true)
        XCTAssertEqual(prefs.serverUpdateURL, "https://example.test/server.met")
    }

    func testParsesSecurityPreferencesGroupFromPrefsPacket() throws {
        let prefs = try ECResponseParser.parseConnectionPrefs(ECPacket(opcode: 0x40, tags: [
            ECTag(name: 0x1C00, type: .custom, children: [
                ECTag(name: 0x1C02, type: .unknown),
                ECTag(name: 0x1C03, type: .unknown),
                .integer(name: 0x1C06, value: 127),
                ECTag(name: 0x1C09, type: .unknown),
                ECTag(name: 0x1C0A, type: .unknown),
            ]),
        ]))

        XCTAssertEqual(prefs.filterClients, true)
        XCTAssertEqual(prefs.filterServers, true)
        XCTAssertEqual(prefs.ipFilterLevel, 127)
        XCTAssertEqual(prefs.obfuscationSupported, true)
        XCTAssertEqual(prefs.obfuscationRequested, true)
        XCTAssertEqual(prefs.obfuscationRequired, false)
    }

    func testParsesRemoteControlsPreferencesGroupFromPrefsPacketWithoutPasswordHashes() throws {
        let prefs = try ECResponseParser.parseConnectionPrefs(ECPacket(opcode: 0x40, tags: [
            ECTag(name: 0x1500, type: .custom, children: [
                ECTag(name: 0x1501, type: .unknown),
                .integer(name: 0x1502, value: 4711),
                ECTag(name: 0x1503, type: .unknown),
                ECTag(name: 0x1504, type: .unknown),
                .integer(name: 0x1505, value: 120),
                ECTag(name: 0x1506, type: .string, value: .string("default")),
            ]),
        ]))

        XCTAssertEqual(prefs.webServerEnabled, true)
        XCTAssertEqual(prefs.webServerPort, 4711)
        XCTAssertEqual(prefs.webServerGuestEnabled, true)
        XCTAssertEqual(prefs.webServerUseGzip, true)
        XCTAssertEqual(prefs.webServerRefreshSeconds, 120)
        XCTAssertEqual(prefs.webServerTemplate, "default")
        XCTAssertNil(prefs.remoteAuthMetadata)
    }

    func testParsesStatisticsPreferencesGroupAsUnsupportedWhenPrefsPacketHasNoValues() throws {
        let prefs = try ECResponseParser.parseConnectionPrefs(ECPacket(opcode: 0x40, tags: [
            ECTag(name: 0x1B00, type: .custom, children: []),
        ]))

        XCTAssertEqual(prefs.statisticsSupported, false)
        XCTAssertNil(prefs.statsGraphUpdateInterval)
        XCTAssertNil(prefs.statsDisplayLimit)
    }

    func testBuildsGroupLimitedPreferencesSetPackets() throws {
        let prefs = ECConnectionPrefs(maxDownload: 1024, maxUpload: 128, tcpPort: 4662, udpPort: 4672, udpEnabled: false, ed2kEnabled: true, kadEnabled: false)
        let packet = try ECOperations.prefsConnectionSet(prefs: prefs, group: .connection)

        XCTAssertEqual(packet.opcode, 0x40)
        XCTAssertEqual(packet.tags.first { $0.name == 0x1000 }?.value, .uint(0x00000004))
        let group = try XCTUnwrap(packet.tags.first { $0.name == 0x1300 })
        XCTAssertEqual(group.children.map(\.name), [0x1303, 0x1304, 0x1306, 0x1307, 0x1308, 0x130D])
    }
}
