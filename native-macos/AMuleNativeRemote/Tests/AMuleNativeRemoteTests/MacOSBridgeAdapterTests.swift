import Foundation
import XCTest

@testable import AMuleNativeRemote

final class MacOSBridgeAdapterTests: XCTestCase {
    func testPlatformDefaultBridgeAdapterUsesSwiftECOnMacOS() {
        XCTAssertEqual(String(describing: type(of: platformDefaultBridgeAdapter())), "MacOSPersistentSwiftECBridgeAdapter")
    }

    func testMacOSBridgeAdapterPreservesOperationArguments() async throws {
        let fixture = try BridgeScriptFixture()
        let adapter = MacOSBridgeAdapter()
        let config = fixture.config()

        _ = try await adapter.capabilities(config: config)
        _ = try await adapter.status(config: config)
        _ = try await adapter.downloads(config: config)
        _ = try await adapter.search(scope: "global", query: "ubuntu iso", polls: 0, pollIntervalMs: 1, config: config)
        _ = try await adapter.addLink(link: "ed2k://|file|alpha.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/", config: config)
        _ = try await adapter.rename(hash: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", name: "renamed.bin", config: config)
        _ = try await adapter.pause(hash: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", config: config)
        _ = try await adapter.resume(hash: "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB", config: config)
        _ = try await adapter.cancel(hash: "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC", config: config)
        _ = try await adapter.servers(config: config)
        _ = try await adapter.serverConnect(ip: "1.2.3.4", port: 4661, config: config)
        _ = try await adapter.serverDisconnect(config: config)
        _ = try await adapter.serverAdd(address: "5.6.7.8:4661", name: "Example", config: config)
        _ = try await adapter.serverRemove(ip: "5.6.7.8", port: 4661, config: config)
        _ = try await adapter.serverUpdateFromURL(url: "https://example.invalid/server.met", config: config)
        _ = try await adapter.sources(hash: "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD", config: config)
        _ = try await adapter.prefsConnectionGet(config: config)
        _ = try await adapter.prefsConnectionSet(maxDownload: 1024, maxUpload: 128, config: config)

        XCTAssertEqual(try fixture.recordedArgumentLines(), [
            "--host 127.0.0.1 --port 4712 --password secret --op capabilities",
            "--host 127.0.0.1 --port 4712 --password secret --op status",
            "--host 127.0.0.1 --port 4712 --password secret --op downloads",
            "--host 127.0.0.1 --port 4712 --password secret --op search --scope global --query ubuntu iso --polls 1 --poll-interval-ms 100",
            "--host 127.0.0.1 --port 4712 --password secret --op add-link --link ed2k://|file|alpha.bin|1|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|/",
            "--host 127.0.0.1 --port 4712 --password secret --op rename --hash AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA --name renamed.bin",
            "--host 127.0.0.1 --port 4712 --password secret --op pause --hash AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
            "--host 127.0.0.1 --port 4712 --password secret --op resume --hash BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
            "--host 127.0.0.1 --port 4712 --password secret --op cancel --hash CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC",
            "--host 127.0.0.1 --port 4712 --password secret --op servers",
            "--host 127.0.0.1 --port 4712 --password secret --op server-connect --server-ip 1.2.3.4 --server-port 4661",
            "--host 127.0.0.1 --port 4712 --password secret --op server-disconnect",
            "--host 127.0.0.1 --port 4712 --password secret --op server-add --server-address 5.6.7.8:4661 --server-name Example",
            "--host 127.0.0.1 --port 4712 --password secret --op server-remove --server-ip 5.6.7.8 --server-port 4661",
            "--host 127.0.0.1 --port 4712 --password secret --op server-update-from-url --server-url https://example.invalid/server.met",
            "--host 127.0.0.1 --port 4712 --password secret --op sources --hash DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD",
            "--host 127.0.0.1 --port 4712 --password secret --op prefs-connection-get",
            "--host 127.0.0.1 --port 4712 --password secret --op prefs-connection-set --max-dl 1024 --max-ul 128"
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
          prefs-connection-get)
            printf '%s\n' '{"ok":true,"prefs_connection":{"max_dl":0,"max_ul":0}}'
            ;;
          *)
            printf '%s\n' '{"ok":true,"message":"ok"}'
            ;;
        esac
        """#.replacingOccurrences(of: "__RECORDS_PATH__", with: recordsPath)
    }
}
