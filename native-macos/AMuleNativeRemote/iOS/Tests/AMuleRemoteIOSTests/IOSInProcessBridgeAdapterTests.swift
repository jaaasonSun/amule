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
            case "sources": return #"{"ok":true,"sources":[]}"#
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
        _ = try await adapter.serverConnect(ip: "1.2.3.4", port: 4661, config: config)
        _ = try await adapter.sources(hash: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", config: config)

        let snapshot = await calls.snapshot()
        XCTAssertEqual(snapshot.map(\.0), ["connect", "status", "downloads", "search", "add-link", "pause", "resume", "cancel", "server-connect", "sources"])
        XCTAssertEqual(snapshot[3].1, ["--scope", "global", "--query", "ubuntu", "--polls", "2", "--poll-interval-ms", "250"])
        XCTAssertEqual(snapshot[4].1.first, "--link")
        XCTAssertEqual(snapshot[5].1, ["--hash", "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"])
        XCTAssertEqual(snapshot[6].1, ["--hash", "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"])
        XCTAssertEqual(snapshot[7].1, ["--hash", "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"])
        XCTAssertEqual(snapshot[8].1, ["--server-ip", "1.2.3.4", "--server-port", "4661"])
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

    func testInProcessWrapperReturnsJsonErrorEnvelopeForConnectionRefused() throws {
        let operations = ["connect", "status", "downloads", "search", "add-link", "pause", "resume", "cancel", "server-connect", "sources"]
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
        case "sources": return ["--hash", "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"]
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
        case "server-connect":
            let args = arguments(for: operation)
            return AMuleBridgeWrapperCopyServerConnectJSON("127.0.0.1", 1, "wrong", args[1], Int32(args[3]) ?? 0)
        case "sources":
            let args = arguments(for: operation)
            return AMuleBridgeWrapperCopySourcesJSON("127.0.0.1", 1, "wrong", args[1])
        default:
            return nil
        }
    }
}
