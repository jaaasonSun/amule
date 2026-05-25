import XCTest

final class BridgeProtocolParityTests: XCTestCase {
    func testIOSBridgeProtocolMethodsAreSubsetOfMacOSBridgeProtocolMethods() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let macOSProtocolURL = packageRoot.appendingPathComponent("Sources/AMuleNativeRemote/BridgeProtocol.swift")
        let iOSProtocolURL = packageRoot.appendingPathComponent("iOS/Sources/AMuleRemoteIOSShared/BridgeProtocol.swift")

        let macOSMethods = try bridgeProtocolMethods(in: macOSProtocolURL)
        let iOSMethods = try bridgeProtocolMethods(in: iOSProtocolURL)

        XCTAssertEqual(macOSMethods.count, 43, "Update this guardrail when the macOS bridge contract intentionally changes.")
        XCTAssertEqual(iOSMethods.count, 22, "Update this guardrail when the iOS bridge contract intentionally changes.")

        let missingMethods = iOSMethods.filter { !macOSMethods.contains($0) }
        XCTAssertTrue(
            missingMethods.isEmpty,
            """
            iOS BridgeProtocol must remain a subset of macOS BridgeProtocol.

            Missing from macOS:
            \(missingMethods.joined(separator: "\n"))

            macOS methods:
            \(macOSMethods.joined(separator: "\n"))

            iOS methods:
            \(iOSMethods.joined(separator: "\n"))
            """
        )
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
