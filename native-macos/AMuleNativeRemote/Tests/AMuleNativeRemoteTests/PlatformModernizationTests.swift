import XCTest

final class PlatformModernizationTests: XCTestCase {
    private var packageRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.lastPathComponent != "AMuleNativeRemote" {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path {
                XCTFail("Could not locate AMuleNativeRemote package root from \(#filePath)")
                return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            }
            url = parent
        }
        return url
    }

    func testNativeAppleTargetsDeclareVersion27Minimums() throws {
        let files = [
            "Package.swift",
            "Packages/Shared/Package.swift",
            "SwiftEC/Package.swift",
            "AMuleNativeRemote.xcodeproj/project.pbxproj",
            "AMuleRemoteiOS.xcodeproj/project.pbxproj",
            "README.md",
        ]

        for file in files {
            let text = try read(file)
            XCTAssertFalse(text.contains(".v26"), "\(file) still declares a SwiftPM v26 platform")
            XCTAssertFalse(text.contains("MACOSX_DEPLOYMENT_TARGET = 26.0"), "\(file) still declares macOS 26")
            XCTAssertFalse(text.contains("IPHONEOS_DEPLOYMENT_TARGET = 26.0"), "\(file) still declares iOS 26")
            XCTAssertFalse(text.contains("default `26.0`"), "\(file) still documents a 26.0 default")
        }
    }

    func testAvailabilityAndWarningChecksStayEnabled() throws {
        let files = [
            "AMuleNativeRemote.xcodeproj/project.pbxproj",
            "AMuleRemoteiOS.xcodeproj/project.pbxproj",
        ]

        for file in files {
            let text = try read(file)
            XCTAssertFalse(text.contains("-disable-availability-checking"), "\(file) disables availability checking")
            XCTAssertFalse(text.contains("SWIFT_SUPPRESS_WARNINGS = YES"), "\(file) suppresses Swift warnings")
            XCTAssertFalse(text.contains("SWIFT_STRICT_CONCURRENCY = minimal"), "\(file) uses minimal concurrency checking")
        }
    }

    func testWindowGlassUsesPublicAPIsOnly() throws {
        let text = try read("Sources/AMuleNativeRemote/WindowVisualStyle.swift")
        XCTAssertFalse(text.contains("NSClassFromString(\"NSGlassEffectView\")"))
        XCTAssertFalse(text.contains("NSSelectorFromString(\"setState:\")"))
        XCTAssertFalse(text.contains("NSSelectorFromString(\"setInteractive:\")"))
        XCTAssertFalse(text.contains("setValue(1, forKey: \"state\")"))
        XCTAssertFalse(text.contains("setValue(true, forKey: \"interactive\")"))
    }

    private func read(_ relativePath: String) throws -> String {
        let url = packageRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
