import XCTest
@testable import AMuleECClient

final class FileNameEncodingRepairTests: XCTestCase {
    func testRepairsSinglePassWesternMojibake() {
        XCTAssertEqual(FileNameEncodingRepair.repairedSuggestion(for: "FranÃ§ais.iso"), "Français.iso")
        XCTAssertEqual(FileNameEncodingRepair.repairedSuggestion(for: "GrÃ¶ÃŸe.mkv"), "Größe.mkv")
    }

    func testRepairsRepeatedMojibakePasses() {
        XCTAssertEqual(FileNameEncodingRepair.repairedSuggestion(for: "FranÃƒÂ§ais.iso"), "Français.iso")
    }

    func testRepairsNonLatinUtf8DecodedAsWindows1252() {
        XCTAssertEqual(FileNameEncodingRepair.repairedSuggestion(for: "ä¸­æ\u{0096}\u{0087}.avi"), "中文.avi")
        XCTAssertEqual(FileNameEncodingRepair.repairedSuggestion(for: "Ð¤Ð¸Ð»ÑŒÐ¼.mkv"), "Фильм.mkv")
    }

    func testRepairsPercentEncodedFileNames() {
        XCTAssertEqual(FileNameEncodingRepair.repairedSuggestion(for: "%E4%B8%AD%E6%96%87.avi"), "中文.avi")
    }

    func testRepairsRepeatedHtmlEntities() {
        XCTAssertEqual(FileNameEncodingRepair.repairedSuggestion(for: "Rock &amp;amp; Roll.mkv"), "Rock & Roll.mkv")
        XCTAssertEqual(FileNameEncodingRepair.repairedSuggestion(for: "Tom &amp; Jerry.mkv"), "Tom & Jerry.mkv")
    }

    func testRepairsNumericHtmlEntities() {
        XCTAssertEqual(FileNameEncodingRepair.repairedSuggestion(for: "Rock &#38; Roll.mkv"), "Rock & Roll.mkv")
        XCTAssertEqual(FileNameEncodingRepair.repairedSuggestion(for: "Caf&#xE9;.mp3"), "Café.mp3")
    }

    func testRepairsMixedEscapingAndMojibake() {
        XCTAssertEqual(
            FileNameEncodingRepair.repairedSuggestion(for: "Fran%C3%83%C2%A7ais%20&amp;amp;%20Caf%C3%A9.iso"),
            "Français & Café.iso"
        )
    }

    func testLeavesCleanNamesAlone() {
        XCTAssertNil(FileNameEncodingRepair.repairedSuggestion(for: "Français.iso"))
        XCTAssertNil(FileNameEncodingRepair.repairedSuggestion(for: "中文.avi"))
        XCTAssertNil(FileNameEncodingRepair.repairedSuggestion(for: "Ubuntu 24.04.iso"))
        XCTAssertNil(FileNameEncodingRepair.repairedSuggestion(for: "AT&T Documentary.mkv"))
    }
}
