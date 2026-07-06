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

    func testParsesFilesPreferencesGroupFromPrefsPacket() throws {
        let prefs = try ECResponseParser.parseConnectionPrefs(ECPacket(opcode: 0x40, tags: [
            ECTag(name: 0x1800, type: .custom, children: [
                ECTag(name: 0x1803, type: .unknown),
                ECTag(name: 0x1804, type: .unknown),
                .integer(name: 0x1805, value: 0),
                ECTag(name: 0x1806, type: .unknown),
                ECTag(name: 0x180A, type: .unknown),
                .integer(name: 0x180B, value: 0),
                ECTag(name: 0x180C, type: .unknown),
                ECTag(name: 0x180D, type: .unknown),
                .integer(name: 0x180E, value: 512),
                .integer(name: 0x180F, value: 0),
            ]),
        ]))

        XCTAssertEqual(prefs.newFilesPaused, true)
        XCTAssertEqual(prefs.autoDownloadPriority, true)
        XCTAssertEqual(prefs.previewPriority, false)
        XCTAssertEqual(prefs.autoUploadPriority, true)
        XCTAssertEqual(prefs.saveSources, true)
        XCTAssertEqual(prefs.extractMetadata, false)
        XCTAssertEqual(prefs.allocateFullFileSize, true)
        XCTAssertEqual(prefs.checkFreeSpace, true)
        XCTAssertEqual(prefs.minFreeDiskSpaceMB, 512)
        XCTAssertEqual(prefs.createSparseFiles, true)
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
        XCTAssertEqual(packet.tags.first { $0.name == 0x0004 }?.value, .uint(0x02))
        XCTAssertEqual(packet.tags.first { $0.name == 0x1000 }?.value, .uint(0x00000004))
        let group = try XCTUnwrap(packet.tags.first { $0.name == 0x1300 })
        XCTAssertEqual(group.children.map(\.name), [0x1303, 0x1304, 0x1306, 0x1307, 0x1308, 0x130D, 0x130E])
        XCTAssertEqual(group.children.first { $0.name == 0x1308 }?.value, .uint(1))
        XCTAssertEqual(group.children.first { $0.name == 0x130D }?.value, .uint(1))
        XCTAssertEqual(group.children.first { $0.name == 0x130E }?.value, .uint(0))
    }

    func testBuildsConnectionSetPacketThatCanTurnConnectionBooleansOff() throws {
        let prefs = ECConnectionPrefs(maxDownload: 1024, maxUpload: 128, tcpPort: 4662, udpPort: 4672, udpEnabled: true, ed2kEnabled: false, kadEnabled: false)
        let packet = try ECOperations.prefsConnectionSet(prefs: prefs, group: .connection)
        let group = try XCTUnwrap(packet.tags.first { $0.name == 0x1300 })

        XCTAssertEqual(packet.tags.first { $0.name == 0x0004 }?.value, .uint(0x02))
        XCTAssertEqual(packet.tags.first { $0.name == 0x1000 }?.value, .uint(0x00000004))
        XCTAssertEqual(group.children.first { $0.name == 0x1308 }?.value, .uint(0))
        XCTAssertEqual(group.children.first { $0.name == 0x130D }?.value, .uint(0))
        XCTAssertEqual(group.children.first { $0.name == 0x130E }?.value, .uint(0))
    }

    func testBuildsServerSetPacketThatCanTurnBooleansOff() throws {
        let prefs = ECConnectionPrefs(
            maxDownload: 0,
            maxUpload: 0,
            serverUpdateURL: "https://example.test/server.met",
            removeDeadServers: false,
            deadServerRetries: 2,
            autoUpdateServers: false,
            addServersFromServer: false,
            addServersFromClient: false,
            useServerPrioritySystem: false,
            smartIdCheck: false,
            safeServerConnect: false,
            autoConnectStaticOnly: false,
            manualHighPriority: false
        )
        let packet = try ECOperations.prefsConnectionSet(prefs: prefs, group: .servers)
        let group = try XCTUnwrap(packet.tags.first { $0.name == 0x1700 })

        XCTAssertEqual(packet.tags.first { $0.name == 0x0004 }?.value, .uint(0x02))
        XCTAssertEqual(packet.tags.first { $0.name == 0x1000 }?.value, .uint(0x00000040))
        for tagName in [0x1701, 0x1703, 0x1705, 0x1706, 0x1707, 0x1708, 0x1709, 0x170A, 0x170B] as [UInt16] {
            XCTAssertEqual(group.children.first { $0.name == tagName }?.value, .uint(0), "Missing explicit false value for \(String(tagName, radix: 16))")
        }
    }

    func testBuildsSecuritySetPacketThatCanTurnBooleansOff() throws {
        let prefs = ECConnectionPrefs(
            maxDownload: 0,
            maxUpload: 0,
            ipFilterLevel: 127,
            filterClients: false,
            filterServers: false,
            ipFilterAutoUpdate: false,
            ipFilterUpdateURL: "https://example.test/ipfilter.dat",
            filterLanIPs: false,
            secureIdentEnabled: false,
            obfuscationSupported: false,
            obfuscationRequested: false,
            obfuscationRequired: false
        )
        let packet = try ECOperations.prefsConnectionSet(prefs: prefs, group: .security)
        let group = try XCTUnwrap(packet.tags.first { $0.name == 0x1C00 })

        XCTAssertEqual(packet.tags.first { $0.name == 0x0004 }?.value, .uint(0x02))
        XCTAssertEqual(packet.tags.first { $0.name == 0x1000 }?.value, .uint(0x00000800))
        for tagName in [0x1C02, 0x1C03, 0x1C04, 0x1C07, 0x1C08, 0x1C09, 0x1C0A, 0x1C0B] as [UInt16] {
            XCTAssertEqual(group.children.first { $0.name == tagName }?.value, .uint(0), "Missing explicit false value for \(String(tagName, radix: 16))")
        }
    }

    func testBuildsRemoteControlSetPacketThatCanTurnBooleansOff() throws {
        let prefs = ECConnectionPrefs(
            maxDownload: 0,
            maxUpload: 0,
            webServerEnabled: false,
            webServerPort: 4711,
            webServerGuestEnabled: false,
            webServerUseGzip: false,
            webServerRefreshSeconds: 120,
            webServerTemplate: "default"
        )
        let packet = try ECOperations.prefsConnectionSet(prefs: prefs, group: .remoteControls)
        let group = try XCTUnwrap(packet.tags.first { $0.name == 0x1500 })

        XCTAssertEqual(packet.tags.first { $0.name == 0x0004 }?.value, .uint(0x02))
        XCTAssertEqual(packet.tags.first { $0.name == 0x1000 }?.value, .uint(0x00000010))
        for tagName in [0x1501, 0x1503, 0x1504] as [UInt16] {
            XCTAssertEqual(group.children.first { $0.name == tagName }?.value, .uint(0), "Missing explicit false value for \(String(tagName, radix: 16))")
        }
    }

    func testBuildsFilesSetPacketWithExplicitBooleanValues() throws {
        let prefs = ECConnectionPrefs(
            maxDownload: 0,
            maxUpload: 0,
            newFilesPaused: false,
            autoDownloadPriority: false,
            previewPriority: false,
            autoUploadPriority: false,
            saveSources: false,
            extractMetadata: false,
            allocateFullFileSize: false,
            checkFreeSpace: false,
            minFreeDiskSpaceMB: 256,
            createSparseFiles: true
        )
        let packet = try ECOperations.prefsConnectionSet(prefs: prefs, group: .files)
        let group = try XCTUnwrap(packet.tags.first { $0.name == 0x1800 })

        XCTAssertEqual(packet.tags.first { $0.name == 0x0004 }?.value, .uint(0x02))
        XCTAssertEqual(packet.tags.first { $0.name == 0x1000 }?.value, .uint(0x00000080))
        for tagName in [0x1803, 0x1804, 0x1805, 0x1806, 0x180A, 0x180B, 0x180C, 0x180D, 0x180F] as [UInt16] {
            XCTAssertEqual(group.children.first { $0.name == tagName }?.value, .uint(0), "Missing explicit false value for \(String(tagName, radix: 16))")
        }
        XCTAssertEqual(group.children.first { $0.name == 0x180E }?.value, .uint(256))
    }

    func testDocumentsIntentionallyOmittedRemoteFilePreferenceTags() throws {
        let omissions = ECOperations.omittedRemoteFilePreferenceTags

        XCTAssertEqual(omissions.map(\.tag), [0x1801, 0x1802, 0x1807, 0x1808, 0x1809])
        XCTAssertEqual(omissions.map(\.symbol), [
            "EC_TAG_FILES_ICH_ENABLED",
            "EC_TAG_FILES_AICH_TRUST",
            "EC_TAG_FILES_UL_FULL_CHUNKS",
            "EC_TAG_FILES_START_NEXT_PAUSED",
            "EC_TAG_FILES_RESUME_SAME_CAT",
        ])
        XCTAssertTrue(omissions.allSatisfy { !$0.rationale.isEmpty })

        let prefs = ECConnectionPrefs(
            maxDownload: 0,
            maxUpload: 0,
            newFilesPaused: true,
            autoDownloadPriority: true,
            previewPriority: true,
            autoUploadPriority: true,
            saveSources: true,
            extractMetadata: true,
            allocateFullFileSize: true,
            checkFreeSpace: true,
            minFreeDiskSpaceMB: 256,
            createSparseFiles: false
        )
        let packet = try ECOperations.prefsConnectionSet(prefs: prefs, group: .files)
        let group = try XCTUnwrap(packet.tags.first { $0.name == 0x1800 })
        let emittedTags = Set(group.children.map(\.name))

        XCTAssertTrue(Set(omissions.map(\.tag)).isDisjoint(with: emittedTags))
    }
}
