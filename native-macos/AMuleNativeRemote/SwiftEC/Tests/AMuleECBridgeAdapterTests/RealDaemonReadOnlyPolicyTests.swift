import XCTest

final class RealDaemonReadOnlyPolicyTests: XCTestCase {
    func testRealDaemonSmokeTestsDoNotContainMutationOperations() throws {
        for url in try realDaemonTestFiles() {
            let source = try String(contentsOf: url, encoding: .utf8)
            try assertReadOnly(source: source, file: url.lastPathComponent)
        }
    }

    private func assertReadOnly(source: String, file: String, line: UInt = #line) throws {
        for forbidden in [
            ".search(",
            ".searchStop(",
            ".download(",
            ".addLink(",
            ".rename(",
            ".pause(",
            ".resume(",
            ".stop(",
            ".serverConnect(",
            ".serverDisconnect(",
            ".serverAdd(",
            ".serverRemove(",
            ".prefsConnectionSet(",
            ".sharedFilesReload(",
            ".categoryCreate(",
            ".categoryUpdate(",
            ".categoryDelete(",
            ".ipfilterReload(",
            ".ipfilterUpdate(",
            ".friendRemove(",
            ".friendAdd(",
            ".friendSlot(",
            ".clearCompleted(",
            ".priority(",
            ".downloadSetCategory(",
            ".sharedFilePriority(",
            ".sharedFileCommentRating(",
        ] {
            XCTAssertFalse(source.contains(forbidden), "\(file) must stay read-only and not call \(forbidden).", line: line)
        }
    }

    private func realDaemonTestFiles() throws -> [URL] {
        let testFile = URL(fileURLWithPath: #filePath)
        let testDirectory = testFile.deletingLastPathComponent()
        return try FileManager.default
            .contentsOfDirectory(at: testDirectory, includingPropertiesForKeys: nil)
            .filter { url in
                url.lastPathComponent.hasPrefix("RealDaemon") &&
                    url.lastPathComponent.hasSuffix("Tests.swift") &&
                    url.lastPathComponent != "RealDaemonReadOnlyPolicyTests.swift"
            }
    }
}
