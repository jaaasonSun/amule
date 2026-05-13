import Foundation
import XCTest

@testable import AMuleNativeRemote

final class MacOSBridgeAdapterTests: XCTestCase {
    func testMacOSBridgeAdapterPreservesOperationArguments() async throws {
        let fixture = try BridgeScriptFixture()
        let adapter = MacOSBridgeAdapter()
        let config = fixture.config()

        _ = try await adapter.capabilities(config: config)
        _ = try await adapter.status(config: config)
        _ = try await adapter.downloads(config: config)
        _ = try await adapter.search(scope: "global", query: "ubuntu iso", polls: 0, pollIntervalMs: 1, config: config)
        _ = try await adapter.addLink(link: "ed2k://|file|alpha.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/", config: config)
        _ = try await adapter.pause(hash: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", config: config)
        _ = try await adapter.resume(hash: "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB", config: config)
        _ = try await adapter.serverConnect(ip: "1.2.3.4", port: 4661, config: config)

        XCTAssertEqual(try fixture.recordedArgumentLines(), [
            "--host 127.0.0.1 --port 4712 --password secret --op capabilities",
            "--host 127.0.0.1 --port 4712 --password secret --op status",
            "--host 127.0.0.1 --port 4712 --password secret --op downloads",
            "--host 127.0.0.1 --port 4712 --password secret --op search --scope global --query ubuntu iso --polls 1 --poll-interval-ms 100",
            "--host 127.0.0.1 --port 4712 --password secret --op add-link --link ed2k://|file|alpha.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/",
            "--host 127.0.0.1 --port 4712 --password secret --op pause --hash AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
            "--host 127.0.0.1 --port 4712 --password secret --op resume --hash BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
            "--host 127.0.0.1 --port 4712 --password secret --op server-connect --server-ip 1.2.3.4 --server-port 4661"
        ])
    }

    func testMacOSBridgeAdapterPreservesFallbackRetryBehavior() async throws {
        let fixture = try BridgeScriptFixture(scriptRelativePath: "build/src/amule-ec-bridge")
        let originalDirectory = FileManager.default.currentDirectoryPath
        XCTAssertTrue(FileManager.default.changeCurrentDirectoryPath(fixture.root.path))
        defer { _ = FileManager.default.changeCurrentDirectoryPath(originalDirectory) }

        let adapter = MacOSBridgeAdapter()
        let config = AMuleConnectionConfig(
            bridgePath: fixture.root.appendingPathComponent("missing-primary-bridge").path,
            host: "127.0.0.1",
            port: 4712,
            password: "secret"
        )

        let (schemaVersion, capabilities, _) = try await adapter.capabilities(config: config)

        XCTAssertEqual(schemaVersion, 1)
        XCTAssertTrue(capabilities.ops.contains("capabilities"))
        XCTAssertEqual(try fixture.recordedArgumentLines(), [
            "--host 127.0.0.1 --port 4712 --password secret --op capabilities"
        ])
    }
}

private struct BridgeScriptFixture {
    let root: URL
    let script: URL
    let records: URL

    init(scriptRelativePath: String = "amule-ec-bridge") throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AMuleBridgeAdapterTests-")
            .appendingPathComponent(UUID().uuidString)
        script = root.appendingPathComponent(scriptRelativePath)
        records = root.appendingPathComponent("records.txt")

        try FileManager.default.createDirectory(
            at: script.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try scriptContent(recordsPath: records.path).write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
    }

    func config() -> AMuleConnectionConfig {
        AMuleConnectionConfig(bridgePath: script.path, host: "127.0.0.1", port: 4712, password: "secret")
    }

    func recordedArgumentLines() throws -> [String] {
        guard FileManager.default.fileExists(atPath: records.path) else { return [] }
        return try String(contentsOf: records, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
    }

    private func scriptContent(recordsPath: String) -> String {
        #"""
        #!/bin/sh
        printf '%s\n' "$*" >> "__RECORDS_PATH__"
        op=""
        while [ "$#" -gt 0 ]; do
          if [ "$1" = "--op" ]; then
            shift
            op="$1"
            break
          fi
          shift
        done
        case "$op" in
          capabilities)
            printf '%s\n' '{"ok":true,"schema_version":1,"capabilities":{"bridge_version":"test","client_name":"test","default_host":"127.0.0.1","default_port":4712,"ops":["capabilities","status","downloads","search","add-link","pause","resume","server-connect"]}}'
            ;;
          status)
            printf '%s\n' '{"ok":true,"status":{"connected":true,"ed2k":"Connected","kad":"Connected","download_speed":0,"upload_speed":0,"queue":0,"sources":0}}'
            ;;
          downloads)
            printf '%s\n' '{"ok":true,"downloads":[]}'
            ;;
          search)
            printf '%s\n' '{"ok":true,"progress":100,"results":[]}'
            ;;
          *)
            printf '%s\n' '{"ok":true,"message":"ok"}'
            ;;
        esac
        """#.replacingOccurrences(of: "__RECORDS_PATH__", with: recordsPath)
    }
}
