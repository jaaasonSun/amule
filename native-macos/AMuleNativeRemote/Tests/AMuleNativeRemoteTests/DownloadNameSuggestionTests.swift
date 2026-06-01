import XCTest
import SharedCore
import SharedUI

@testable import AMuleNativeRemote

final class DownloadNameSuggestionTests: XCTestCase {
    private struct MeaningfulSuggestionFixture {
        let name: String
        let suspect: Bool
        let suggestion: String?
        let expectedMeaningfulSuggestion: String?
        let expectedHasMeaningfulSuggestion: Bool
    }

    func testFilenameSuggestionPresentationMatchesIOSRenameDraftBehavior() {
        XCTAssertEqual(
            FilenameSuggestionPresentation.renameDraft(
                from: "  Corrected 中文.mkv  ",
                currentName: "Mojibake.mkv"
            ),
            "Corrected 中文.mkv"
        )
        XCTAssertNil(FilenameSuggestionPresentation.renameDraft(from: "   ", currentName: "Mojibake.mkv"))
        XCTAssertNil(FilenameSuggestionPresentation.renameDraft(from: "Mojibake.mkv", currentName: "Mojibake.mkv"))
    }

    func testDecodeDownloadEnvelopeWithoutSuggestionFields() throws {
        let json = try BridgeEnvelopeFixtures.downloadEnvelope(downloads: [
            BridgeEnvelopeFixtures.download(
                ecid: 1,
                hash: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
                name: "Original.iso",
                size: 123,
                done: 0,
                transferred: 0,
                progress: 0,
                sourcesCurrent: 0,
                sourcesTotal: 0,
                sourcesTransferring: 0,
                statusCode: 0,
                isCompleted: false,
                status: "Waiting",
                speed: 0,
                partMet: "001.part.met",
                shared: false
            ),
        ])
        let data = try XCTUnwrap(json.data(using: .utf8))

        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        let downloads = try XCTUnwrap(decoded.downloads)
        XCTAssertEqual(downloads.count, 1)
        XCTAssertEqual(downloads[0].name, "Original.iso")
        XCTAssertFalse(downloads[0].nameEncodingSuspect)
        XCTAssertNil(downloads[0].nameEncodingSuggestion)
    }

    func testDecodeDownloadSuggestionEnvelope() throws {
        let json = try BridgeEnvelopeFixtures.downloadEnvelope(downloads: [
            BridgeEnvelopeFixtures.download(
                ecid: 1,
                hash: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
                name: "FranÃ§ais.iso",
                size: 123,
                done: 0,
                transferred: 0,
                progress: 0,
                sourcesCurrent: 0,
                sourcesTotal: 0,
                sourcesTransferring: 0,
                statusCode: 0,
                isCompleted: false,
                status: "Waiting",
                speed: 0,
                partMet: "001.part.met",
                shared: false,
                nameEncodingSuspect: true,
                nameEncodingSuggestion: "Français.iso"
            ),
        ])
        let data = try XCTUnwrap(json.data(using: .utf8))

        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        let downloads = try XCTUnwrap(decoded.downloads)
        XCTAssertEqual(downloads.count, 1)
        XCTAssertEqual(downloads[0].name, "FranÃ§ais.iso")
        XCTAssertTrue(downloads[0].nameEncodingSuspect)
        XCTAssertEqual(downloads[0].nameEncodingSuggestion, "Français.iso")
    }

    func testDownloadItemPreservesOriginalNameAndSuggestion() throws {
        let json = try BridgeEnvelopeFixtures.downloadEnvelope(downloads: [
            BridgeEnvelopeFixtures.download(
                ecid: 1,
                hash: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
                name: "FranÃ§ais.iso",
                size: 123,
                done: 0,
                transferred: 0,
                progress: 0,
                sourcesCurrent: 0,
                sourcesTotal: 0,
                sourcesTransferring: 0,
                statusCode: 0,
                isCompleted: false,
                status: "Waiting",
                speed: 0,
                partMet: "001.part.met",
                shared: false,
                nameEncodingSuspect: true,
                nameEncodingSuggestion: "Français.iso"
            ),
        ])
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        let item = try XCTUnwrap(DownloadItem.fromBridge(try XCTUnwrap(decoded.downloads)).first)

        XCTAssertEqual(item.name, "FranÃ§ais.iso")
        XCTAssertTrue(item.nameEncodingSuspect)
        XCTAssertEqual(item.nameEncodingSuggestion, "Français.iso")
    }

    func testDownloadItemComputesRepeatedEncodingSuggestionWhenBridgeDoesNotProvideOne() throws {
        let json = #"{"ok":true,"downloads":[{"ecid":1,"hash":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA","name":"FranÃƒÂ§ais.iso","size":123,"done":0,"transferred":0,"progress":0,"sources_current":0,"sources_total":0,"sources_transferring":0,"sources_a4af":0,"status_code":0,"is_completed":false,"status":"Waiting","speed":0,"priority":0,"category":0,"part_met":"001.part.met","last_seen_complete":0,"last_received":0,"active_seconds":0,"available_parts":0,"shared":false,"alternative_names":[],"progress_colors":[]}]}"#
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        let item = try XCTUnwrap(DownloadItem.fromBridge(try XCTUnwrap(decoded.downloads)).first)

        XCTAssertEqual(item.name, "FranÃƒÂ§ais.iso")
        XCTAssertTrue(item.nameEncodingSuspect)
        XCTAssertEqual(item.nameEncodingSuggestion, "Français.iso")
    }

    func testAlternativeNameComputesEncodingSuggestion() {
        let alt = DownloadAlternativeName(name: "ä¸­æ\u{0096}\u{0087}.avi", count: 3)
        XCTAssertEqual(alt.meaningfulNameEncodingSuggestion, "中文.avi")
    }

    func testMeaningfulSuggestionIgnoresIdenticalName() throws {
        try assertMeaningfulSuggestionFixtures([
            .init(
                name: "Original.iso",
                suspect: true,
                suggestion: "Original.iso",
                expectedMeaningfulSuggestion: nil,
                expectedHasMeaningfulSuggestion: false
            ),
        ])
    }

    func testMeaningfulSuggestionReturnsDistinctSuggestion() throws {
        try assertMeaningfulSuggestionFixtures([
            .init(
                name: "FranÃ§ais.iso",
                suspect: true,
                suggestion: "Français.iso",
                expectedMeaningfulSuggestion: "Français.iso",
                expectedHasMeaningfulSuggestion: true
            ),
        ])
    }

    func testMeaningfulSuggestionTrimsWhitespace() throws {
        try assertMeaningfulSuggestionFixtures([
            .init(
                name: "Original.iso",
                suspect: false,
                suggestion: "  Français.iso  ",
                expectedMeaningfulSuggestion: "Français.iso",
                expectedHasMeaningfulSuggestion: true
            ),
        ])
    }

    func testMeaningfulSuggestionIgnoresWhitespaceOnlySuggestion() throws {
        try assertMeaningfulSuggestionFixtures([
            .init(
                name: "Original.iso",
                suspect: true,
                suggestion: "   ",
                expectedMeaningfulSuggestion: nil,
                expectedHasMeaningfulSuggestion: false
            ),
            .init(
                name: "   ",
                suspect: false,
                suggestion: nil,
                expectedMeaningfulSuggestion: nil,
                expectedHasMeaningfulSuggestion: false
            ),
        ])
    }

    func testMeaningfulSuggestionHandlesPathSeparatorsAndEquivalentDuplicates() throws {
        try assertMeaningfulSuggestionFixtures([
            .init(
                name: "Season 1/FranÃ§ais.srt",
                suspect: false,
                suggestion: nil,
                expectedMeaningfulSuggestion: "Season 1/Français.srt",
                expectedHasMeaningfulSuggestion: true
            ),
            .init(
                name: "Episode 01.mkv",
                suspect: false,
                suggestion: "  Episode 01.mkv  ",
                expectedMeaningfulSuggestion: nil,
                expectedHasMeaningfulSuggestion: false
            ),
        ])
    }

    func testDisplayedNameEncodingValueFallsBackToOriginalNameWhenDiagnosticEnabled() throws {
        let json = try BridgeEnvelopeFixtures.downloadEnvelope(downloads: [
            BridgeEnvelopeFixtures.download(
                ecid: 1,
                hash: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
                name: "Original.iso",
                size: 123,
                done: 0,
                transferred: 0,
                progress: 0,
                sourcesCurrent: 0,
                sourcesTotal: 0,
                sourcesTransferring: 0,
                statusCode: 0,
                isCompleted: false,
                status: "Waiting",
                speed: 0,
                partMet: "001.part.met",
                shared: false,
                nameEncodingSuspect: false
            ),
        ])
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        let item = try XCTUnwrap(DownloadItem.fromBridge(try XCTUnwrap(decoded.downloads)).first)

        XCTAssertNil(item.meaningfulNameEncodingSuggestion)
        XCTAssertEqual(item.displayedNameEncodingValue(alwaysShowDiagnostic: true), "Original.iso")
        XCTAssertTrue(item.usesDiagnosticNameEncodingFallback(alwaysShowDiagnostic: true))
        XCTAssertTrue(item.hasDisplayedNameEncodingValue(alwaysShowDiagnostic: true))
    }

    func testDisplayedNameEncodingValueStaysHiddenWithoutDiagnosticToggle() throws {
        let json = try BridgeEnvelopeFixtures.downloadEnvelope(downloads: [
            BridgeEnvelopeFixtures.download(
                ecid: 1,
                hash: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
                name: "Original.iso",
                size: 123,
                done: 0,
                transferred: 0,
                progress: 0,
                sourcesCurrent: 0,
                sourcesTotal: 0,
                sourcesTransferring: 0,
                statusCode: 0,
                isCompleted: false,
                status: "Waiting",
                speed: 0,
                partMet: "001.part.met",
                shared: false,
                nameEncodingSuspect: false
            ),
        ])
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        let item = try XCTUnwrap(DownloadItem.fromBridge(try XCTUnwrap(decoded.downloads)).first)

        XCTAssertNil(item.displayedNameEncodingValue(alwaysShowDiagnostic: false))
        XCTAssertFalse(item.usesDiagnosticNameEncodingFallback(alwaysShowDiagnostic: false))
        XCTAssertFalse(item.hasDisplayedNameEncodingValue(alwaysShowDiagnostic: false))
    }

    func testDisplayedNameEncodingValuePrefersMeaningfulSuggestionOverDiagnosticFallback() throws {
        let json = try BridgeEnvelopeFixtures.downloadEnvelope(downloads: [
            BridgeEnvelopeFixtures.download(
                ecid: 1,
                hash: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
                name: "FranÃ§ais.iso",
                size: 123,
                done: 0,
                transferred: 0,
                progress: 0,
                sourcesCurrent: 0,
                sourcesTotal: 0,
                sourcesTransferring: 0,
                statusCode: 0,
                isCompleted: false,
                status: "Waiting",
                speed: 0,
                partMet: "001.part.met",
                shared: false,
                nameEncodingSuspect: true,
                nameEncodingSuggestion: "Français.iso"
            ),
        ])
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        let item = try XCTUnwrap(DownloadItem.fromBridge(try XCTUnwrap(decoded.downloads)).first)

        XCTAssertEqual(item.displayedNameEncodingValue(alwaysShowDiagnostic: true), "Français.iso")
        XCTAssertFalse(item.usesDiagnosticNameEncodingFallback(alwaysShowDiagnostic: true))
        XCTAssertTrue(item.hasDisplayedNameEncodingValue(alwaysShowDiagnostic: true))
    }

    func testFilenameSuggestionCharacterizationKeepsWhitespaceTrimmingBeforeRenameDraft() throws {
        let json = try BridgeEnvelopeFixtures.downloadEnvelope(downloads: [
            BridgeEnvelopeFixtures.download(
                ecid: 1,
                hash: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
                name: "Mojibake.mkv",
                size: 123,
                done: 0,
                transferred: 0,
                progress: 0,
                sourcesCurrent: 0,
                sourcesTotal: 0,
                sourcesTransferring: 0,
                statusCode: 0,
                isCompleted: false,
                status: "Waiting",
                speed: 0,
                partMet: "001.part.met",
                shared: false,
                nameEncodingSuspect: true,
                nameEncodingSuggestion: "  Corrected 中文.mkv  "
            ),
        ])
        let item = try XCTUnwrap(DownloadItem.fromBridge(decodeDownloads(from: json)).first)

        XCTAssertEqual(item.meaningfulNameEncodingSuggestion, "Corrected 中文.mkv")
        XCTAssertEqual(
            FilenameSuggestionPresentation.renameDraft(
                from: try XCTUnwrap(item.displayedNameEncodingValue(alwaysShowDiagnostic: true)),
                currentName: item.name
            ),
            "Corrected 中文.mkv"
        )
    }

    private func decodeDownloads(from json: String) throws -> [BridgeDownloadPayload] {
        let data = try XCTUnwrap(json.data(using: .utf8))
        return try XCTUnwrap(JSONDecoder().decode(BridgeEnvelope.self, from: data).downloads)
    }

    private func assertMeaningfulSuggestionFixtures(_ fixtures: [MeaningfulSuggestionFixture], file: StaticString = #filePath, line: UInt = #line) throws {
        for fixture in fixtures {
            let item = try XCTUnwrap(
                DownloadItem.fromBridge([
                    makeDownloadPayload(
                        name: fixture.name,
                        suspect: fixture.suspect,
                        suggestion: fixture.suggestion
                    )
                ]).first,
                file: file,
                line: line
            )

            XCTAssertEqual(item.meaningfulNameEncodingSuggestion, fixture.expectedMeaningfulSuggestion, file: file, line: line)
            XCTAssertEqual(item.hasMeaningfulNameEncodingSuggestion, fixture.expectedHasMeaningfulSuggestion, file: file, line: line)
        }
    }

    private func makeDownloadPayload(name: String, suspect: Bool, suggestion: String?) -> BridgeDownloadPayload {
        BridgeDownloadPayload(
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
            shared: false,
            alternativeNames: [],
            progressColors: []
        )
    }
}
