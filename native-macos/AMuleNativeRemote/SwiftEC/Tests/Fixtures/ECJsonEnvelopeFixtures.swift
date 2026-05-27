import Foundation
import AMuleECProtocol

/// Golden JSON envelope examples matching `src/AMuleECBridge.cpp`, `AMuleECBridgeCore.cpp`,
/// and `AMuleECBridgeJson.h` output patterns. These are daemon-free fixtures; values are
/// representative but field names/order follow the C++ stream output.
public enum ECJsonEnvelopeFixtures {
    public static let messageByOperation: [String: String] = [
        "pause": "{\"ok\":true,\"message\":\"Action completed\"}",
        "resume": "{\"ok\":true,\"message\":\"Action completed\"}",
        "cancel": "{\"ok\":true,\"message\":\"Cancel requested\"}",
        "priority": "{\"ok\":true,\"message\":\"Priority changed\"}",
        "clear-completed": "{\"ok\":true,\"message\":\"Completed downloads cleared\"}",
        "server-connect": "{\"ok\":true,\"message\":\"Server connect requested\"}",
        "server-disconnect": "{\"ok\":true,\"message\":\"Server disconnect requested\"}",
        "server-add": "{\"ok\":true,\"message\":\"Server add requested\"}",
        "server-remove": "{\"ok\":true,\"message\":\"Server remove requested\"}",
        "server-update-from-url": "{\"ok\":true,\"message\":\"Server list update requested\"}",
        "prefs-connection-set": "{\"ok\":true,\"message\":\"Connection speed limits updated\"}",
        "category-create": "{\"ok\":true,\"message\":\"Category create requested\"}",
        "category-delete": "{\"ok\":true,\"message\":\"Category delete requested\"}",
        "rename": "{\"ok\":true,\"message\":\"Rename requested\"}"
    ]

    public static let capabilities = """
    {"ok":true,"schema_version":1,"capabilities":{"bridge_version":"GIT","client_name":"aMuleNativeBridge","default_host":"127.0.0.1","default_port":4712,"ops":["capabilities","status","downloads","sources","search","search-stop","download","add-link","rename","connect","disconnect","pause","resume","cancel","priority","clear-completed","servers","server-connect","server-disconnect","server-add","server-remove","server-update-from-url","kad-update-from-url","prefs-connection-get","prefs-connection-set"]}}
    """

    public static let error = """
    {"ok":false,"error":"Missing --password"}
    """

    public static let message = """
    {"ok":true,"message":"Download request accepted"}
    """

    public static let status = """
    {"ok":true,"status":{"connected":true,"ed2k":"Connected to ExampleServer [1.2.3.4:4662] HighID","kad":"Connected (ok)","download_speed":12345,"upload_speed":678,"queue":9,"sources":42}}
    """

    public static let downloads = """
    {"ok":true,"downloads":[{"ecid":1001,"hash":"00112233445566778899aabbccddeeff","name":"fixture.iso","name_encoding_suspect":false,"name_encoding_suggestion":null,"size":1048576,"done":524288,"transferred":600000,"progress":50,"sources_current":3,"sources_total":5,"sources_transferring":1,"sources_a4af":0,"status_code":7,"is_completed":false,"status":"Downloading","speed":12345,"priority":2,"category":0,"part_met":"001.part.met","last_seen_complete":1710000000,"last_received":1710000300,"active_seconds":3600,"available_parts":4,"shared":false,"alternative_names":[{"name":"fixture-alt.iso","count":2}],"progress_colors":[6842472,6842472,53503,13683968]}]}
    """

    public static let sources = """
    {"ok":true,"sources":[{"client_id":501,"request_file_id":1001,"client_name":"peer","user_ip":"10.0.0.2","user_port":4662,"server_name":"ExampleServer","server_ip":"1.2.3.4","server_port":4661,"software":"9","software_version":"2.3.3","download_state":3,"download_state_text":"Downloading","source_from":2,"source_from_text":"Kad","down_speed_kbps":12.5,"available_parts":8,"remote_queue_rank":12,"obfuscation_status":1,"extended_protocol":true,"remote_filename":"fixture.iso"}]}
    """

    public static let search = """
    {"ok":true,"progress":100,"results":[{"id":77,"hash":"ffeeddccbbaa99887766554433221100","name":"fixture-search.iso","size":2048,"sources":12,"complete_sources":3,"status_code":0,"status":"New","parent_id":0,"already_have":false}]}
    """

    public static let servers = """
    {"ok":true,"servers":[{"id":1,"name":"ExampleServer","description":"Fixture server","version":"17.15","address":"1.2.3.4:4661","ip":"1.2.3.4","port":4661,"users":1000,"max_users":5000,"files":250000,"ping":42,"failed":0,"priority":0,"is_static":false}]}
    """

    public static let prefsConnection = """
    {"ok":true,"prefs_connection":{"max_dl":1024,"max_ul":256}}
    """

    public static let categories = """
    {"ok":true,"categories":[{"id":7,"title":"Linux ISO","path":"/downloads/linux","comment":"Fixture category","color":16711935,"priority":2}]}
    """

    public static let friends = """
    {"ok":true,"friends":[{"id":11,"name":"alice","hash":"00112233445566778899aabbccddeeff","ip":"5.6.7.8","port":4662,"client":"9","friend_slot":true}]}
    """

    public static let unsupportedPause = """
    {"ok":false,"error":"Unsupported operation: pause"}
    """

    public static let allJSONEnvelopes: [String: String] = [
        "capabilities": capabilities,
        "error": error,
        "message": message,
        "status": status,
        "downloads": downloads,
        "sources": sources,
        "search": search,
        "servers": servers,
        "prefs_connection": prefsConnection,
        "categories": categories,
        "friends": friends,
        "unsupported_pause": unsupportedPause,
    ]

    public enum TwoRefreshCorruption {
        public static let completedName = "Finished Movie.mkv"
        public static let unrelatedSharedName = "Shared Row.bin"

        public static let refreshTwoPacket: ECPacket = try! ECPacket(opcode: 0x1F, tags: [
            malformedBlankPartFile(ecid: 4101),
            malformedMissingHashPartFile(ecid: 4102, name: unrelatedSharedName),
            completedPartFile(ecid: 4103, hash: "00112233445566778899aabbccddeeff", name: completedName),
        ])

        private static func malformedBlankPartFile(ecid: Int) throws -> ECTag {
            try completedPartFile(ecid: ecid, hash: "11112222333344445555666677778888", name: "")
        }

        private static func malformedMissingHashPartFile(ecid: Int, name: String) -> ECTag {
            ECTag.integer(name: 0x0300, value: UInt64(ecid), children: [
                ECTag(name: 0x0301, type: .string, value: .string(name)),
                ECTag.integer(name: 0x0303, value: 128),
                ECTag.integer(name: 0x0306, value: 128),
                ECTag.integer(name: 0x0308, value: 9),
            ])
        }

        private static func completedPartFile(ecid: Int, hash: String, name: String) throws -> ECTag {
            guard let hashData = Data(hex: hash) else {
                throw FixtureError.invalidHex(hash)
            }
            return ECTag.integer(name: 0x0300, value: UInt64(ecid), children: [
                ECTag(name: 0x0301, type: .string, value: .string(name)),
                ECTag.integer(name: 0x0303, value: 128),
                ECTag.integer(name: 0x0306, value: 128),
                ECTag.integer(name: 0x0308, value: 9),
                ECTag(name: 0x031E, type: .hash16, value: .hash16(hashData)),
            ])
        }
    }
}

private enum FixtureError: Error {
    case invalidHex(String)
}

private extension Data {
    init?(hex: String) {
        self.init()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            append(byte)
            index = next
        }
    }
}
