import XCTest
import Foundation
import AMuleECProtocol
import AMuleECClient

@available(macOS 10.15, iOS 13.0, *)
final class RealDaemonSmokeTests: XCTestCase {
    func testRealDaemonAuthenticates() async throws {
        try await withAuthenticatedSession { _, result in
            switch result {
            case .accepted(let serverVersion):
                if let serverVersion {
                    XCTAssertFalse(serverVersion.isEmpty)
                }
            }
        }
    }

    func testRealDaemonStatusAndDownloadsSmoke() async throws {
        try await withAuthenticatedSession { session, _ in
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

    func testRealDaemonSourcesSmoke() async throws {
        try await withAuthenticatedSession { session, _ in
            let queuePacket = try await session.send(try ECOperations.downloads())
            let downloads = try ECResponseParser.parseDownloads(queuePacket)
            guard let first = downloads.first else {
                throw XCTSkip("Live daemon has no download fixture for read-only sources smoke.")
            }

            let fileID = try ECResponseParser.parseDownloadFileID(hash: first.hash, in: queuePacket)
            let updatePacket = try await session.send(try ECOperations.sourcesUpdate())
            try ECResponseParser.validateSharedFilesUpdate(updatePacket)
            let sources = try ECResponseParser.parseSources(updatePacket, requestFileID: fileID)
            XCTAssertGreaterThanOrEqual(sources.count, 0)
            if let source = sources.first {
                XCTAssertEqual(source.requestFileID, fileID)
            }
        }
    }

    private func withAuthenticatedSession<T>(
        _ body: @escaping (ECSession, ECAuthResult) async throws -> T
    ) async throws -> T {
        let harness = try smokeHarness()
        let session = ECSession(configuration: harness.sessionConfiguration)
        do {
            let authResult = try await session.connectAndAuthenticate()
            let result = try await body(session, authResult)
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

        return SmokeHarness(
            host: host,
            port: port,
            password: password
        )
    }
}

@available(macOS 10.15, iOS 13.0, *)
private struct SmokeHarness {
    static let hostKey = "AMULE_EC_HOST"
    static let portKey = "AMULE_EC_PORT"
    static let passwordKey = "AMULE_EC_PASSWORD"

    let host: String
    let port: Int
    let password: String

    var sessionConfiguration: ECSession.Configuration {
        .init(host: host, port: UInt16(clamping: port), password: password, automaticReconnect: false)
    }
}
