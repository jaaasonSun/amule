import XCTest
@testable import AMuleECClient

final class FileNameEncodingRepairTests: XCTestCase {
    private struct RepairFixture {
        let input: String
        let expected: String?
    }

    private struct NormalizationFixture {
        let name: String
        let suspect: Bool
        let suggestion: String?
        let expectedSuspect: Bool
        let expectedSuggestion: String?
    }

    func testRepairsSinglePassWesternMojibake() {
        assertRepairs([
            .init(input: "FranÃ§ais.iso", expected: "Français.iso"),
            .init(input: "GrÃ¶ÃŸe.mkv", expected: "Größe.mkv"),
        ])
    }

    func testRepairsRepeatedMojibakePasses() {
        XCTAssertEqual(FileNameEncodingRepair.repairedSuggestion(for: "FranÃƒÂ§ais.iso"), "Français.iso")
    }

    func testRepairsNonLatinUtf8DecodedAsWindows1252() {
        assertRepairs([
            .init(input: "ä¸­æ\u{0096}\u{0087}.avi", expected: "中文.avi"),
            .init(input: "Ð¤Ð¸Ð»ÑŒÐ¼.mkv", expected: "Фильм.mkv"),
        ])
    }

    func testRepairsLongCJKMojibakeDespiteLargeLengthReduction() {
        XCTAssertEqual(
            FileNameEncodingRepair.repairedSuggestion(
                for: "FC2 PPV 4897221 ã´ãªãããã§éæVSå¾¹éã¬ã¹ãªã³ã°ãã«ãã©å¯¾æ±ºï¼éæãçå ãä½æ ¼å·®éäº¤å°¾é ä¸æ±ºæ¦ï¼ç¹å¸æ åããï¼.mp4"
            ),
            "FC2 PPV 4897221 ゴリマッチョ雄星VS徹郎レスリングデカマラ対決！雄星が生堀り体格差雄交尾頂上決戦！特典映像あり！.mp4"
        )
    }

    func testRepairsPercentEncodedFileNames() {
        assertRepairs([
            .init(input: "%E4%B8%AD%E6%96%87.avi", expected: "中文.avi"),
        ])
    }

    func testRepairsRepeatedHtmlEntities() {
        assertRepairs([
            .init(input: "Rock &amp;amp; Roll.mkv", expected: "Rock & Roll.mkv"),
            .init(input: "Tom &amp; Jerry.mkv", expected: "Tom & Jerry.mkv"),
        ])
    }

    func testRepairsNumericHtmlEntities() {
        assertRepairs([
            .init(input: "Rock &#38; Roll.mkv", expected: "Rock & Roll.mkv"),
            .init(input: "Caf&#xE9;.mp3", expected: "Café.mp3"),
        ])
    }

    func testRepairsMixedEscapingAndMojibake() {
        XCTAssertEqual(
            FileNameEncodingRepair.repairedSuggestion(for: "Fran%C3%83%C2%A7ais%20&amp;amp;%20Caf%C3%A9.iso"),
            "Français & Café.iso"
        )
    }

    func testLeavesCleanNamesAlone() {
        assertRepairs([
            .init(input: "Français.iso", expected: nil),
            .init(input: "中文.avi", expected: nil),
            .init(input: "Ubuntu 24.04.iso", expected: nil),
            .init(input: "AT&T Documentary.mkv", expected: nil),
            .init(input: "", expected: nil),
            .init(input: "   ", expected: nil),
        ])
    }

    func testRepairsPathSeparatedNames() {
        assertRepairs([
            .init(input: "Season 1/FranÃ§ais.srt", expected: "Season 1/Français.srt"),
            .init(input: "Movies/%E4%B8%AD%E6%96%87.avi", expected: "Movies/中文.avi"),
        ])
    }

    func testFilenameSuggestionPolicyRemovesLiteralPrefixesCaseInsensitively() {
        XCTAssertEqual(
            FileNameSuggestionPolicy.suggestion(
                currentName: "ABCDED - Movie.mkv",
                prefixes: ["ABCDED - "]
            ),
            "Movie.mkv"
        )
        XCTAssertEqual(
            FileNameSuggestionPolicy.suggestion(
                currentName: "abcded - Movie.mkv",
                prefixes: ["ABCDED - "]
            ),
            "Movie.mkv"
        )
        XCTAssertNil(
            FileNameSuggestionPolicy.suggestion(
                currentName: "ABCDED- Movie.mkv",
                prefixes: ["ABCDED - "]
            )
        )
    }

    func testFilenameSuggestionPolicyAppliesEncodingRepairBeforePrefixCleanup() {
        XCTAssertEqual(
            FileNameSuggestionPolicy.suggestion(
                currentName: "ABCDED - FranÃ§ais.mkv",
                prefixes: ["ABCDED - "]
            ),
            "Français.mkv"
        )
    }

    func testFilenameSuggestionPolicyUsesLongestMatchingPrefixAndFiltersEmptyResults() {
        XCTAssertEqual(
            FileNameSuggestionPolicy.suggestion(
                currentName: "ABCDED Extended - Movie.mkv",
                prefixes: ["ABCDED ", "ABCDED Extended - "]
            ),
            "Movie.mkv"
        )
        XCTAssertNil(
            FileNameSuggestionPolicy.suggestion(
                currentName: "ABCDED - ",
                prefixes: ["ABCDED - "]
            )
        )
    }

    func testFilenameSuggestionPolicyCleansProvidedSuggestionBeforeCurrentName() {
        XCTAssertEqual(
            FileNameSuggestionPolicy.suggestion(
                currentName: "Original.mkv",
                providedSuggestion: "ABCDED - Better.mkv",
                prefixes: ["ABCDED - "]
            ),
            "Better.mkv"
        )
    }

    func testDownloadInitAndDecoderShareNormalizationFixtures() throws {
        let fixtures: [NormalizationFixture] = [
            .init(
                name: "FranÃ§ais.iso",
                suspect: false,
                suggestion: nil,
                expectedSuspect: true,
                expectedSuggestion: "Français.iso"
            ),
            .init(
                name: "Original.iso",
                suspect: false,
                suggestion: "  Corrected 中文.mkv  ",
                expectedSuspect: true,
                expectedSuggestion: "Corrected 中文.mkv"
            ),
            .init(
                name: "Original.iso",
                suspect: true,
                suggestion: "Original.iso",
                expectedSuspect: true,
                expectedSuggestion: nil
            ),
            .init(
                name: "Original.iso",
                suspect: false,
                suggestion: "   ",
                expectedSuspect: false,
                expectedSuggestion: nil
            ),
            .init(
                name: "Season 1/FranÃ§ais.srt",
                suspect: false,
                suggestion: nil,
                expectedSuspect: true,
                expectedSuggestion: "Season 1/Français.srt"
            ),
            .init(
                name: "FC2 PPV 4897221 ã´ãªãããã§éæVSå¾¹éã¬ã¹ãªã³ã°ãã«ãã©å¯¾æ±ºï¼éæãçå ãä½æ ¼å·®éäº¤å°¾é ä¸æ±ºæ¦ï¼ç¹å¸æ åããï¼.mp4",
                suspect: false,
                suggestion: nil,
                expectedSuspect: true,
                expectedSuggestion: "FC2 PPV 4897221 ゴリマッチョ雄星VS徹郎レスリングデカマラ対決！雄星が生堀り体格差雄交尾頂上決戦！特典映像あり！.mp4"
            ),
            .init(
                name: "   ",
                suspect: false,
                suggestion: nil,
                expectedSuspect: false,
                expectedSuggestion: nil
            ),
        ]

        for fixture in fixtures {
            let initDownload = makeDownload(
                name: fixture.name,
                suspect: fixture.suspect,
                suggestion: fixture.suggestion
            )
            XCTAssertEqual(initDownload.nameEncodingSuspect, fixture.expectedSuspect, "init suspect for \(fixture.name)")
            XCTAssertEqual(initDownload.nameEncodingSuggestion, fixture.expectedSuggestion, "init suggestion for \(fixture.name)")

            let decodedDownload = try decodeDownload(
                name: fixture.name,
                suspect: fixture.suspect,
                suggestion: fixture.suggestion
            )
            XCTAssertEqual(decodedDownload.nameEncodingSuspect, fixture.expectedSuspect, "decode suspect for \(fixture.name)")
            XCTAssertEqual(decodedDownload.nameEncodingSuggestion, fixture.expectedSuggestion, "decode suggestion for \(fixture.name)")
        }
    }

    private func assertRepairs(_ fixtures: [RepairFixture], file: StaticString = #filePath, line: UInt = #line) {
        for fixture in fixtures {
            XCTAssertEqual(
                FileNameEncodingRepair.repairedSuggestion(for: fixture.input),
                fixture.expected,
                "repair fixture for \(fixture.input)",
                file: file,
                line: line
            )
        }
    }

    private func makeDownload(name: String, suspect: Bool, suggestion: String?) -> ECDownload {
        ECDownload(
            ecid: 1,
            hash: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
            name: name,
            nameEncodingSuspect: suspect,
            nameEncodingSuggestion: suggestion,
            size: 123,
            done: 0,
            transferred: 0,
            progress: 0,
            sourcesCurrent: 0,
            sourcesTotal: 0,
            sourcesTransferring: 0,
            sourcesA4AF: 0,
            statusCode: 0,
            isCompleted: false,
            status: "Waiting",
            speed: 0,
            priority: 0,
            category: 0,
            partMet: "001.part.met",
            lastSeenComplete: 0,
            lastReceived: 0,
            activeSeconds: 0,
            availableParts: 0,
            shared: false
        )
    }

    private func decodeDownload(name: String, suspect: Bool, suggestion: String?) throws -> ECDownload {
        var payload: [String: Any] = [
            "ecid": 1,
            "hash": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
            "name": name,
            "size": 123,
            "done": 0,
            "transferred": 0,
            "progress": 0,
            "sources_current": 0,
            "sources_total": 0,
            "sources_transferring": 0,
            "sources_a4af": 0,
            "status_code": 0,
            "is_completed": false,
            "status": "Waiting",
            "speed": 0,
            "priority": 0,
            "category": 0,
            "part_met": "001.part.met",
            "last_seen_complete": 0,
            "last_received": 0,
            "active_seconds": 0,
            "available_parts": 0,
            "shared": false,
            "alternative_names": [],
            "progress_colors": [],
        ]
        payload["name_encoding_suspect"] = suspect
        if let suggestion {
            payload["name_encoding_suggestion"] = suggestion
        }

        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        return try JSONDecoder().decode(ECDownload.self, from: data)
    }
}
