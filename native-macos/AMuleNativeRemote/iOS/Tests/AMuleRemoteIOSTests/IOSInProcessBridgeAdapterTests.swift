import XCTest
import AmuleBridgeWrapper
@testable import AMuleRemoteIOSShared

final class IOSInProcessBridgeAdapterTests: XCTestCase {
    func testCapabilitiesEnvelopeMatchesMacOSBridgeFixtureShape() async throws {
        let adapter = IOSInProcessBridgeAdapter(timeoutSeconds: 5)
        let config = AMuleConnectionConfig(bridgePath: "", host: "127.0.0.1", port: 4712, password: "secret")

        let (schemaVersion, capabilities, raw) = try await adapter.capabilities(config: config)
        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: XCTUnwrap(raw.data(using: .utf8)))

        XCTAssertTrue(decoded.ok)
        XCTAssertEqual(schemaVersion, 1)
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertNotNil(decoded.capabilities)
        XCTAssertNil(decoded.status)
        XCTAssertNil(decoded.downloads)
        XCTAssertEqual(capabilities.clientName, "aMuleNativeBridge")
        XCTAssertEqual(capabilities.defaultHost, "127.0.0.1")
        XCTAssertEqual(capabilities.defaultPort, 4712)
        XCTAssertTrue(capabilities.ops.contains("capabilities"))
        XCTAssertTrue(capabilities.ops.contains("status"))
        XCTAssertTrue(capabilities.ops.contains("prefs-connection-get"))
        XCTAssertTrue(capabilities.ops.contains("prefs-connection-set"))
    }

    func testTimeoutCancelsSlowInProcessBridgeOperation() async throws {
        let adapter = IOSInProcessBridgeAdapter(timeoutSeconds: 0.01) { _, _, _ in
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return #"{"ok":true,"schema_version":1,"capabilities":{"bridge_version":"test","client_name":"test","default_host":"127.0.0.1","default_port":4712,"ops":["capabilities"]}}"#
        }
        let config = AMuleConnectionConfig(bridgePath: "", host: "127.0.0.1", port: 4712, password: "secret")

        do {
            _ = try await adapter.capabilities(config: config)
            XCTFail("Expected timeout")
        } catch let error as IOSBridgeTimeoutError {
            XCTAssertEqual(error.seconds, 0.01, accuracy: 0.001)
        }
    }

    func testV1OperationsForwardMacOSCompatibleArguments() async throws {
        actor Calls {
            var values: [(String, [String])] = []
            func append(_ op: String, _ args: [String]) { values.append((op, args)) }
            func snapshot() -> [(String, [String])] { values }
        }
        let calls = Calls()
        let adapter = IOSInProcessBridgeAdapter(timeoutSeconds: 5) { op, args, _ in
            await calls.append(op, args)
            switch op {
            case "status": return #"{"ok":true,"status":{"connected":false,"ed2k":"Not connected","kad":"Not running","download_speed":0,"upload_speed":0,"queue":0,"sources":0}}"#
            case "downloads": return #"{"ok":true,"downloads":[]}"#
            case "search": return #"{"ok":true,"progress":0,"results":[]}"#
            case "servers": return #"{"ok":true,"servers":[]}"#
            case "sources": return #"{"ok":true,"sources":[]}"#
            case "prefs-connection-get": return #"{"ok":true,"prefs_connection":{"max_dl":512,"max_ul":64}}"#
            case "prefs-connection-set": return #"{"ok":true,"message":"Connection speed limits updated"}"#
            default: return #"{"ok":true,"message":"accepted"}"#
            }
        }
        let config = AMuleConnectionConfig(bridgePath: "", host: "127.0.0.1", port: 4712, password: "secret")

        _ = try await adapter.connect(config: config)
        _ = try await adapter.status(config: config)
        _ = try await adapter.downloads(config: config)
        _ = try await adapter.search(scope: "global", query: "ubuntu", polls: 2, pollIntervalMs: 250, config: config)
        _ = try await adapter.addLink(link: "ed2k://|file|a|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/", config: config)
        _ = try await adapter.pause(hash: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", config: config)
        _ = try await adapter.resume(hash: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", config: config)
        _ = try await adapter.cancel(hash: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", config: config)
        _ = try await adapter.servers(config: config)
        _ = try await adapter.serverConnect(ip: "1.2.3.4", port: 4661, config: config)
        _ = try await adapter.serverDisconnect(config: config)
        _ = try await adapter.serverAdd(address: "5.6.7.8:4661", name: "Example", config: config)
        _ = try await adapter.serverRemove(ip: "5.6.7.8", port: 4661, config: config)
        _ = try await adapter.serverUpdateFromURL(url: "https://example.invalid/server.met", config: config)
        _ = try await adapter.sources(hash: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", config: config)
        let (prefs, prefsRaw) = try await adapter.prefsConnectionGet(config: config)
        let setResult = try await adapter.prefsConnectionSet(maxDownload: 1024, maxUpload: 128, config: config)

        let snapshot = await calls.snapshot()
        XCTAssertEqual(snapshot.map(\.0), ["connect", "status", "downloads", "search", "add-link", "pause", "resume", "cancel", "servers", "server-connect", "server-disconnect", "server-add", "server-remove", "server-update-from-url", "sources", "prefs-connection-get", "prefs-connection-set"])
        XCTAssertEqual(snapshot[3].1, ["--scope", "global", "--query", "ubuntu", "--polls", "2", "--poll-interval-ms", "250"])
        XCTAssertEqual(snapshot[4].1.first, "--link")
        XCTAssertEqual(snapshot[5].1, ["--hash", "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"])
        XCTAssertEqual(snapshot[6].1, ["--hash", "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"])
        XCTAssertEqual(snapshot[7].1, ["--hash", "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"])
        XCTAssertEqual(snapshot[9].1, ["--server-ip", "1.2.3.4", "--server-port", "4661"])
        XCTAssertEqual(snapshot[10].1, [])
        XCTAssertEqual(snapshot[11].1, ["--server-address", "5.6.7.8:4661", "--server-name", "Example"])
        XCTAssertEqual(snapshot[12].1, ["--server-ip", "5.6.7.8", "--server-port", "4661"])
        XCTAssertEqual(snapshot[13].1, ["--server-url", "https://example.invalid/server.met"])
        XCTAssertEqual(snapshot[15].1, [])
        XCTAssertEqual(snapshot[16].1, ["--max-dl", "1024", "--max-ul", "128"])
        XCTAssertEqual(prefs.maxDownload, 512)
        XCTAssertEqual(prefs.maxUpload, 64)
        XCTAssertTrue(prefsRaw.contains(#""prefs_connection""#))
        XCTAssertEqual(setResult.message, "Connection speed limits updated")
    }

    func testCancelThrowsBridgeFailureForMissingDownload() async throws {
        let adapter = IOSInProcessBridgeAdapter(timeoutSeconds: 5) { op, _, _ in
            if op == "cancel" {
                return #"{"ok":false,"error":"download not found"}"#
            }
            return #"{"ok":true,"message":"accepted"}"#
        }
        let config = AMuleConnectionConfig(bridgePath: "", host: "127.0.0.1", port: 4712, password: "secret")

        do {
            _ = try await adapter.cancel(hash: "00000000000000000000000000000000", config: config)
            XCTFail("Expected cancel failure for nonexistent download")
        } catch AMuleClientError.bridgeFailure(let message) {
            XCTAssertEqual(message, "download not found")
        }
    }

    func testServerListDecodePreservesDuplicateRemoteEndpoints() async throws {
        let adapter = IOSInProcessBridgeAdapter(timeoutSeconds: 5) { op, _, _ in
            XCTAssertEqual(op, "servers")
            return #"{"ok":true,"servers":[{"id":2,"name":"Second","description":"duplicate endpoint","version":"17.15","address":"1.2.3.4:4661","ip":"1.2.3.4","port":4661,"users":2,"max_users":10,"files":20,"ping":8,"failed":0,"priority":1,"is_static":false},{"id":1,"name":"First","description":"primary","version":"17.15","address":"1.2.3.4:4661","ip":"1.2.3.4","port":4661,"users":1,"max_users":10,"files":10,"ping":7,"failed":0,"priority":0,"is_static":true}]}"#
        }
        let config = AMuleConnectionConfig(bridgePath: "", host: "127.0.0.1", port: 4712, password: "secret")

        let (payloads, raw) = try await adapter.servers(config: config)
        let items = ServerItem.fromBridge(payloads)

        XCTAssertTrue(raw.contains(#""servers""#))
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.map(\.id), [2, 1])
        XCTAssertEqual(Set(items.map(\.endpointText)), ["1.2.3.4:4661"])
        XCTAssertTrue(items[1].isStatic)
    }

    func testServerDisconnectSurfacesUnsupportedOpFallback() async throws {
        let adapter = IOSInProcessBridgeAdapter(timeoutSeconds: 5) { op, _, _ in
            if op == "server-disconnect" {
                return #"{"ok":false,"error":"unsupported operation: server-disconnect"}"#
            }
            return #"{"ok":true,"message":"accepted"}"#
        }
        let config = AMuleConnectionConfig(bridgePath: "", host: "127.0.0.1", port: 4712, password: "secret")

        do {
            _ = try await adapter.serverDisconnect(config: config)
            XCTFail("Expected unsupported operation failure")
        } catch AMuleClientError.bridgeFailure(let message) {
            XCTAssertEqual(message, "unsupported operation: server-disconnect")
        }
    }

    func testInProcessWrapperReturnsJsonErrorEnvelopeForConnectionRefused() throws {
        let operations = ["connect", "status", "downloads", "search", "add-link", "pause", "resume", "cancel", "servers", "server-connect", "server-disconnect", "server-add", "server-remove", "server-update-from-url", "sources", "prefs-connection-get", "prefs-connection-set"]
        for operation in operations {
            let raw = callWrapper(for: operation)
            let json = try XCTUnwrap(raw)
            defer { AMuleBridgeWrapperFreeString(json) }
            let data = try XCTUnwrap(String(cString: json).data(using: .utf8))
            let envelope = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
            XCTAssertFalse(envelope.ok, operation)
            XCTAssertNotNil(envelope.error, operation)
        }
    }

    private func arguments(for operation: String) -> [String] {
        switch operation {
        case "search": return ["--scope", "kad", "--query", "ubuntu", "--polls", "1", "--poll-interval-ms", "100"]
        case "add-link": return ["--link", "ed2k://|file|a|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/"]
        case "pause", "resume", "cancel": return ["--hash", "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"]
        case "server-connect": return ["--server-ip", "1.2.3.4", "--server-port", "4661"]
        case "server-add": return ["--server-address", "1.2.3.4:4661", "--server-name", "Test"]
        case "server-remove": return ["--server-ip", "1.2.3.4", "--server-port", "4661"]
        case "server-update-from-url": return ["--server-url", "https://example.invalid/server.met"]
        case "sources": return ["--hash", "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"]
        case "prefs-connection-set": return ["--max-dl", "1024", "--max-ul", "128"]
        default: return []
        }
    }

    private func callWrapper(for operation: String) -> UnsafePointer<CChar>? {
        switch operation {
        case "connect":
            return AMuleBridgeWrapperCopyConnectJSON("127.0.0.1", 1, "wrong")
        case "status":
            return AMuleBridgeWrapperCopyStatusJSON("127.0.0.1", 1, "wrong")
        case "downloads":
            return AMuleBridgeWrapperCopyDownloadsJSON("127.0.0.1", 1, "wrong")
        case "search":
            let args = arguments(for: operation)
            return AMuleBridgeWrapperCopySearchJSON("127.0.0.1", 1, "wrong", args[1], args[3], Int32(args[5]) ?? 1, Int32(args[7]) ?? 100)
        case "add-link":
            return AMuleBridgeWrapperCopyAddLinkJSON("127.0.0.1", 1, "wrong", arguments(for: operation)[1])
        case "pause":
            return AMuleBridgeWrapperCopyPauseJSON("127.0.0.1", 1, "wrong", arguments(for: operation)[1])
        case "resume":
            return AMuleBridgeWrapperCopyResumeJSON("127.0.0.1", 1, "wrong", arguments(for: operation)[1])
        case "cancel":
            return AMuleBridgeWrapperCopyCancelJSON("127.0.0.1", 1, "wrong", arguments(for: operation)[1])
        case "servers":
            return AMuleBridgeWrapperCopyServersJSON("127.0.0.1", 1, "wrong")
        case "server-connect":
            let args = arguments(for: operation)
            return AMuleBridgeWrapperCopyServerConnectJSON("127.0.0.1", 1, "wrong", args[1], Int32(args[3]) ?? 0)
        case "server-disconnect":
            return AMuleBridgeWrapperCopyServerDisconnectJSON("127.0.0.1", 1, "wrong")
        case "server-add":
            let args = arguments(for: operation)
            return AMuleBridgeWrapperCopyServerAddJSON("127.0.0.1", 1, "wrong", args[1], args[3])
        case "server-remove":
            let args = arguments(for: operation)
            return AMuleBridgeWrapperCopyServerRemoveJSON("127.0.0.1", 1, "wrong", args[1], Int32(args[3]) ?? 0)
        case "server-update-from-url":
            return AMuleBridgeWrapperCopyServerUpdateFromURLJSON("127.0.0.1", 1, "wrong", arguments(for: operation)[1])
        case "sources":
            let args = arguments(for: operation)
            return AMuleBridgeWrapperCopySourcesJSON("127.0.0.1", 1, "wrong", args[1])
        case "prefs-connection-get":
            return AMuleBridgeWrapperCopyPrefsConnectionGetJSON("127.0.0.1", 1, "wrong")
        case "prefs-connection-set":
            return AMuleBridgeWrapperCopyPrefsConnectionSetJSON("127.0.0.1", 1, "wrong", 1024, 128)
        default:
            return nil
        }
    }

    func testPrefsConnectionSetRejectsNegativeLimitsBeforeConnecting() throws {
        let raw = AMuleBridgeWrapperCopyPrefsConnectionSetJSON("127.0.0.1", 1, "wrong", -1, 128)
        let json = try XCTUnwrap(raw)
        defer { AMuleBridgeWrapperFreeString(json) }
        let data = try XCTUnwrap(String(cString: json).data(using: .utf8))
        let envelope = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        XCTAssertFalse(envelope.ok)
        XCTAssertEqual(envelope.error, "--max-dl must be non-negative")
    }
}
