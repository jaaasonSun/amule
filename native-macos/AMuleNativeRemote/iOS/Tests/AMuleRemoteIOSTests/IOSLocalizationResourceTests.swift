import XCTest

final class IOSLocalizationResourceTests: XCTestCase {
    func testChineseLocalizationResourcesIncludeMacOSAndIOSKeys() throws {
        let localization = try loadLocalization(locale: "zh-Hans")

        XCTAssertEqual(localization["Downloads"], "下载")
        XCTAssertEqual(localization["Connect"], "连接")
        XCTAssertEqual(localization["Filter Downloads"], "筛选下载")
        XCTAssertEqual(localization["Search files"], "搜索文件")
        XCTAssertEqual(localization["No Matching Downloads"], "没有匹配的下载")
        XCTAssertEqual(localization["Connection Status"], "连接状态")
    }

    func testChineseLocalizationResourcesIncludeDetailAndSettingsKeys() throws {
        let requiredKeys = [
            "About",
            "Filter",
            "Showing %@",
            "Sorted by %@, %@",
            "KB/s",
            "Invalid download speed limit. Use a non-negative integer.",
            "Invalid upload speed limit. Use a non-negative integer.",
            "None",
            "Ready",
            "Empty",
            "Waiting for hash",
            "Hashing",
            "Erroneous",
            "Insufficient disk space",
            "Completing",
            "Complete",
            "Allocating",
            "On queue",
            "No needed parts",
            "Remote queue full",
            "Source exchange",
            "Passive",
            "(unknown client)",
            "Full"
        ]

        for locale in ["zh-Hans", "zh_CN"] {
            let localization = try loadLocalization(locale: locale)
            for key in requiredKeys {
                XCTAssertNotNil(localization[key], "\(locale) is missing \(key)")
            }
        }
    }

    private func loadLocalization(locale: String) throws -> [String: String] {
        let testFile = URL(fileURLWithPath: #filePath)
        let appDirectory = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AMuleRemoteiOS")
        let stringsURL = appDirectory
            .appendingPathComponent("\(locale).lproj")
            .appendingPathComponent("Localizable.strings")
        let data = try Data(contentsOf: stringsURL)
        let propertyList = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(propertyList as? [String: String])
    }
}
