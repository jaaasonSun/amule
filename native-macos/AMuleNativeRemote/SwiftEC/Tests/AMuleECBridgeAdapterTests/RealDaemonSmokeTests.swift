import XCTest
import Foundation
import AMuleECProtocol
import AMuleECClient
@testable import AMuleECBridgeAdapter

@available(macOS 10.15, iOS 13.0, *)
final class RealDaemonSmokeTests: XCTestCase {
    func testRealDaemonAuthenticates() async throws {
        try await withAuthenticatedSession { _, _, result in
            switch result {
            case .accepted(let serverVersion):
                if let serverVersion {
                    XCTAssertFalse(serverVersion.isEmpty)
                }
            }
        }
    }

    func testRealDaemonStatusAndDownloadsSmoke() async throws {
        try await withAuthenticatedSession { session, _, _ in
            let status = try ECResponseParser.parseStatus(try await session.send(try ECOperations.status()))
            XCTAssertGreaterThanOrEqual(status.downloadSpeed, 0)
            XCTAssertGreaterThanOrEqual(status.uploadSpeed, 0)
            XCTAssertGreaterThanOrEqual(status.queue, 0)
            XCTAssertGreaterThanOrEqual(status.sources, 0)

            let downloads = try ECResponseParser.parseDownloads(try await session.send(try ECOperations.downloads()))
            XCTAssertGreaterThanOrEqual(downloads.count, 0)
            if let first = downloads.first {
                XCTAssertFalse(first.hash.isEmpty)
                XCTAssertFalse(first.name.isEmpty)
            }
        }
    }

    func testRealDaemonSourcesOrSearchSmoke() async throws {
        try await withAuthenticatedSession { session, harness, _ in
            let queuePacket = try await session.send(try ECOperations.downloads())
            let downloads = try ECResponseParser.parseDownloads(queuePacket)
            if let first = downloads.first {
                let fileID = try ECResponseParser.parseDownloadFileID(hash: first.hash, in: queuePacket)
                let updatePacket = try await session.send(try ECOperations.sourcesUpdate())
                try ECResponseParser.validateSharedFilesUpdate(updatePacket)
                let sources = try ECResponseParser.parseSources(updatePacket, requestFileID: fileID)
                XCTAssertGreaterThanOrEqual(sources.count, 0)
                if let source = sources.first {
                    XCTAssertEqual(source.requestFileID, fileID)
                }
                return
            }

            let adapter = SwiftECBridgeAdapter(session: session)
            do {
                let search = try await adapter.search(
                    scope: harness.searchScope,
                    query: harness.searchQuery,
                    polls: harness.searchPolls,
                    pollIntervalMs: harness.searchPollIntervalMs,
                    config: harness.connectionConfig
                )
                XCTAssertGreaterThanOrEqual(search.progress, 0)
                XCTAssertLessThanOrEqual(search.progress, 100)
                XCTAssertFalse(search.raw.isEmpty)

                let stop = try await adapter.searchStop(config: harness.connectionConfig)
                XCTAssertEqual(stop.message, "Search stop requested")
                XCTAssertFalse(stop.raw.isEmpty)
            } catch let error as ECResponseParserError {
                if case .operationFailed(let message) = error {
                    throw XCTSkip("Live daemon has no download fixture and search smoke is unavailable: \(message)")
                }
                throw error
            }
        }
    }

    func testRealDaemonSafeMutationSmoke() async throws {
        try await withAuthenticatedSession { session, harness, _ in
            let adapter = SwiftECBridgeAdapter(session: session)
            if let rename = harness.renameFixture {
                let acknowledgement = try await adapter.rename(
                    hash: rename.hash,
                    name: rename.name,
                    config: harness.connectionConfig
                )
                switch acknowledgement {
                case .success(let message, let raw),
                     .disconnectedAfterSend(let message, let raw),
                     .timeout(let message, let raw),
                     .requested(let message, let raw):
                    XCTAssertEqual(message, "Rename requested")
                    XCTAssertFalse(raw.isEmpty)
                case .failure(let message, _):
                    XCTFail("Configured smoke rename fixture failed: \(message)")
                }
                return
            }

            do {
                let stop = try await adapter.searchStop(config: harness.connectionConfig)
                XCTAssertEqual(stop.message, "Search stop requested")
                XCTAssertFalse(stop.raw.isEmpty)
            } catch let error as ECResponseParserError {
                if case .operationFailed(let message) = error {
                    throw XCTSkip("Live daemon has no safe no-op mutation fixture: \(message)")
                }
                throw error
            }
        }
    }

    private func withAuthenticatedSession<T>(
        _ body: @escaping (ECSession, SmokeHarness, ECAuthResult) async throws -> T
    ) async throws -> T {
        let harness = try smokeHarness()
        let session = ECSession(configuration: harness.sessionConfiguration)
        do {
            let authResult = try await session.connectAndAuthenticate()
            let result = try await body(session, harness, authResult)
            await session.disconnect()
            return result
        } catch {
            await session.disconnect()
            throw error
        }
    }

    private func smokeHarness() throws -> SmokeHarness {
        let environment = ProcessInfo.processInfo.environment

        guard let host = environment[SmokeHarness.hostKey],
              let portString = environment[SmokeHarness.portKey],
              let password = environment[SmokeHarness.passwordKey],
              !host.isEmpty,
              !portString.isEmpty,
              !password.isEmpty else {
            throw XCTSkip(
                "Set \(SmokeHarness.hostKey), \(SmokeHarness.portKey), and \(SmokeHarness.passwordKey) to run live SwiftEC smoke tests."
            )
        }

        guard let port = Int(portString), (1...65535).contains(port) else {
            throw XCTSkip("\(SmokeHarness.portKey) must be a valid TCP port.")
        }

        let renameHash = environment[SmokeHarness.renameHashKey]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let renameName = environment[SmokeHarness.renameNameKey]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let renameFixture: SmokeHarness.RenameFixture?
        if let renameHash, !renameHash.isEmpty, let renameName, !renameName.isEmpty {
            renameFixture = .init(hash: renameHash, name: renameName)
        } else {
            renameFixture = nil
        }

        return SmokeHarness(
            host: host,
            port: port,
            password: password,
            searchScope: environment[SmokeHarness.searchScopeKey] ?? "global",
            searchQuery: environment[SmokeHarness.searchQueryKey] ?? "ubuntu",
            searchPolls: Int(environment[SmokeHarness.searchPollsKey] ?? "2") ?? 2,
            searchPollIntervalMs: Int(environment[SmokeHarness.searchPollIntervalKey] ?? "250") ?? 250,
            renameFixture: renameFixture
        )
    }
}

@available(macOS 10.15, iOS 13.0, *)
private struct SmokeHarness {
    static let hostKey = "AMULE_EC_HOST"
    static let portKey = "AMULE_EC_PORT"
    static let passwordKey = "AMULE_EC_PASSWORD"
    static let searchScopeKey = "AMULE_EC_SMOKE_SEARCH_SCOPE"
    static let searchQueryKey = "AMULE_EC_SMOKE_SEARCH_QUERY"
    static let searchPollsKey = "AMULE_EC_SMOKE_SEARCH_POLLS"
    static let searchPollIntervalKey = "AMULE_EC_SMOKE_SEARCH_POLL_INTERVAL_MS"
    static let renameHashKey = "AMULE_EC_SMOKE_RENAME_HASH"
    static let renameNameKey = "AMULE_EC_SMOKE_RENAME_NAME"

    struct RenameFixture: Sendable {
        let hash: String
        let name: String
    }

    let host: String
    let port: Int
    let password: String
    let searchScope: String
    let searchQuery: String
    let searchPolls: Int
    let searchPollIntervalMs: Int
    let renameFixture: RenameFixture?

    var sessionConfiguration: ECSession.Configuration {
        .init(host: host, port: UInt16(clamping: port), password: password, automaticReconnect: false)
    }

    var connectionConfig: AMuleConnectionConfig {
        .init(host: host, port: port, password: password)
    }
}
