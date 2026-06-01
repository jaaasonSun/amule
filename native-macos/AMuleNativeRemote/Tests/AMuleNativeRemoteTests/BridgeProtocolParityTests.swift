import XCTest
@testable import SharedCore

final class BridgeProtocolParityTests: XCTestCase {
    func testSharedCoreBridgeProtocolHasExpectedMethods() throws {
        let mirror = Mirror(reflecting: BridgeProtocol.self)
        XCTAssertEqual(mirror.children.count, 0, "BridgeProtocol is a protocol, not a value type")

        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sharedCoreProtocolURL = packageRoot.appendingPathComponent("SharedCore/Sources/SharedCore/BridgeProtocol.swift")

        let methods = try bridgeProtocolMethods(in: sharedCoreProtocolURL)
        XCTAssertEqual(methods.count, 43, "Update this guardrail when the shared bridge contract intentionally changes.")
        XCTAssertFalse(methods.isEmpty, "SharedCore BridgeProtocol should have methods")
    }

    private func bridgeProtocolMethods(in url: URL) throws -> [String] {
        let source = try String(contentsOf: url, encoding: .utf8)
        var methods: [String] = []
        var isInsideBridgeProtocol = false
        var braceDepth = 0

        for line in source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("protocol BridgeProtocol") {
                isInsideBridgeProtocol = true
            }

            guard isInsideBridgeProtocol else { continue }

            if trimmed.hasPrefix("func ") || trimmed.hasPrefix("public func ") {
                methods.append(trimmed.replacingOccurrences(of: "public ", with: ""))
            }

            braceDepth += line.filter { $0 == "{" }.count
            braceDepth -= line.filter { $0 == "}" }.count

            if braceDepth == 0, trimmed == "}" {
                break
            }
        }

        XCTAssertFalse(methods.isEmpty, "No BridgeProtocol methods found in \(url.path)")
        return methods
    }
}
