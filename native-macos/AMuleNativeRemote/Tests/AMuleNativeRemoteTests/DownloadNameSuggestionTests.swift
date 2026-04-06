import XCTest

@testable import AMuleNativeRemote

final class DownloadNameSuggestionTests: XCTestCase {
    func testDecodeDownloadEnvelopeWithoutSuggestionFields() throws {
        let json = #"{"ok":true,"downloads":[{"ecid":1,"hash":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA","name":"Original.iso","size":123,"done":0,"transferred":0,"progress":0,"sources_current":0,"sources_total":0,"sources_transferring":0,"sources_a4af":0,"status_code":0,"is_completed":false,"status":"Waiting","speed":0,"priority":0,"category":0,"part_met":"001.part.met","last_seen_complete":0,"last_received":0,"active_seconds":0,"available_parts":0,"shared":false,"alternative_names":[],"progress_colors":[]}]}"#
        let data = try XCTUnwrap(json.data(using: .utf8))

        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        let downloads = try XCTUnwrap(decoded.downloads)
        XCTAssertEqual(downloads.count, 1)
        XCTAssertEqual(downloads[0].name, "Original.iso")
        XCTAssertFalse(downloads[0].nameEncodingSuspect)
        XCTAssertNil(downloads[0].nameEncodingSuggestion)
    }

    func testDecodeDownloadSuggestionEnvelope() throws {
        let json = #"{"ok":true,"downloads":[{"ecid":1,"hash":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA","name":"FranÃ§ais.iso","name_encoding_suspect":true,"name_encoding_suggestion":"Français.iso","size":123,"done":0,"transferred":0,"progress":0,"sources_current":0,"sources_total":0,"sources_transferring":0,"sources_a4af":0,"status_code":0,"is_completed":false,"status":"Waiting","speed":0,"priority":0,"category":0,"part_met":"001.part.met","last_seen_complete":0,"last_received":0,"active_seconds":0,"available_parts":0,"shared":false,"alternative_names":[],"progress_colors":[]}]}"#
        let data = try XCTUnwrap(json.data(using: .utf8))

        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        let downloads = try XCTUnwrap(decoded.downloads)
        XCTAssertEqual(downloads.count, 1)
        XCTAssertEqual(downloads[0].name, "FranÃ§ais.iso")
        XCTAssertTrue(downloads[0].nameEncodingSuspect)
        XCTAssertEqual(downloads[0].nameEncodingSuggestion, "Français.iso")
    }

    func testDownloadItemPreservesOriginalNameAndSuggestion() throws {
        let json = #"{"ok":true,"downloads":[{"ecid":1,"hash":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA","name":"FranÃ§ais.iso","name_encoding_suspect":true,"name_encoding_suggestion":"Français.iso","size":123,"done":0,"transferred":0,"progress":0,"sources_current":0,"sources_total":0,"sources_transferring":0,"sources_a4af":0,"status_code":0,"is_completed":false,"status":"Waiting","speed":0,"priority":0,"category":0,"part_met":"001.part.met","last_seen_complete":0,"last_received":0,"active_seconds":0,"available_parts":0,"shared":false,"alternative_names":[],"progress_colors":[]}]}"#
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        let item = try XCTUnwrap(DownloadItem.fromBridge(try XCTUnwrap(decoded.downloads)).first)

        XCTAssertEqual(item.name, "FranÃ§ais.iso")
        XCTAssertTrue(item.nameEncodingSuspect)
        XCTAssertEqual(item.nameEncodingSuggestion, "Français.iso")
    }

    func testMeaningfulSuggestionIgnoresIdenticalName() throws {
        let json = #"{"ok":true,"downloads":[{"ecid":1,"hash":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA","name":"Original.iso","name_encoding_suspect":true,"name_encoding_suggestion":"Original.iso","size":123,"done":0,"transferred":0,"progress":0,"sources_current":0,"sources_total":0,"sources_transferring":0,"sources_a4af":0,"status_code":0,"is_completed":false,"status":"Waiting","speed":0,"priority":0,"category":0,"part_met":"001.part.met","last_seen_complete":0,"last_received":0,"active_seconds":0,"available_parts":0,"shared":false,"alternative_names":[],"progress_colors":[]}]}"#
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        let item = try XCTUnwrap(DownloadItem.fromBridge(try XCTUnwrap(decoded.downloads)).first)

        XCTAssertNil(item.meaningfulNameEncodingSuggestion)
        XCTAssertFalse(item.hasMeaningfulNameEncodingSuggestion)
    }

    func testMeaningfulSuggestionReturnsDistinctSuggestion() throws {
        let json = #"{"ok":true,"downloads":[{"ecid":1,"hash":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA","name":"FranÃ§ais.iso","name_encoding_suspect":true,"name_encoding_suggestion":"Français.iso","size":123,"done":0,"transferred":0,"progress":0,"sources_current":0,"sources_total":0,"sources_transferring":0,"sources_a4af":0,"status_code":0,"is_completed":false,"status":"Waiting","speed":0,"priority":0,"category":0,"part_met":"001.part.met","last_seen_complete":0,"last_received":0,"active_seconds":0,"available_parts":0,"shared":false,"alternative_names":[],"progress_colors":[]}]}"#
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        let item = try XCTUnwrap(DownloadItem.fromBridge(try XCTUnwrap(decoded.downloads)).first)

        XCTAssertEqual(item.meaningfulNameEncodingSuggestion, "Français.iso")
        XCTAssertTrue(item.hasMeaningfulNameEncodingSuggestion)
    }

    func testMeaningfulSuggestionTrimsWhitespace() throws {
        let json = #"{"ok":true,"downloads":[{"ecid":1,"hash":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA","name":"Original.iso","name_encoding_suspect":false,"name_encoding_suggestion":"  Français.iso  ","size":123,"done":0,"transferred":0,"progress":0,"sources_current":0,"sources_total":0,"sources_transferring":0,"sources_a4af":0,"status_code":0,"is_completed":false,"status":"Waiting","speed":0,"priority":0,"category":0,"part_met":"001.part.met","last_seen_complete":0,"last_received":0,"active_seconds":0,"available_parts":0,"shared":false,"alternative_names":[],"progress_colors":[]}]}"#
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        let item = try XCTUnwrap(DownloadItem.fromBridge(try XCTUnwrap(decoded.downloads)).first)

        XCTAssertEqual(item.meaningfulNameEncodingSuggestion, "Français.iso")
        XCTAssertTrue(item.hasMeaningfulNameEncodingSuggestion)
    }

    func testMeaningfulSuggestionIgnoresWhitespaceOnlySuggestion() throws {
        let json = #"{"ok":true,"downloads":[{"ecid":1,"hash":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA","name":"Original.iso","name_encoding_suspect":true,"name_encoding_suggestion":"   ","size":123,"done":0,"transferred":0,"progress":0,"sources_current":0,"sources_total":0,"sources_transferring":0,"sources_a4af":0,"status_code":0,"is_completed":false,"status":"Waiting","speed":0,"priority":0,"category":0,"part_met":"001.part.met","last_seen_complete":0,"last_received":0,"active_seconds":0,"available_parts":0,"shared":false,"alternative_names":[],"progress_colors":[]}]}"#
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        let item = try XCTUnwrap(DownloadItem.fromBridge(try XCTUnwrap(decoded.downloads)).first)

        XCTAssertNil(item.meaningfulNameEncodingSuggestion)
        XCTAssertFalse(item.hasMeaningfulNameEncodingSuggestion)
    }

    func testDisplayedNameEncodingValueFallsBackToOriginalNameWhenDiagnosticEnabled() throws {
        let json = #"{"ok":true,"downloads":[{"ecid":1,"hash":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA","name":"Original.iso","name_encoding_suspect":false,"size":123,"done":0,"transferred":0,"progress":0,"sources_current":0,"sources_total":0,"sources_transferring":0,"sources_a4af":0,"status_code":0,"is_completed":false,"status":"Waiting","speed":0,"priority":0,"category":0,"part_met":"001.part.met","last_seen_complete":0,"last_received":0,"active_seconds":0,"available_parts":0,"shared":false,"alternative_names":[],"progress_colors":[]}]}"#
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        let item = try XCTUnwrap(DownloadItem.fromBridge(try XCTUnwrap(decoded.downloads)).first)

        XCTAssertNil(item.meaningfulNameEncodingSuggestion)
        XCTAssertEqual(item.displayedNameEncodingValue(alwaysShowDiagnostic: true), "Original.iso")
        XCTAssertTrue(item.usesDiagnosticNameEncodingFallback(alwaysShowDiagnostic: true))
        XCTAssertTrue(item.hasDisplayedNameEncodingValue(alwaysShowDiagnostic: true))
    }

    func testDisplayedNameEncodingValueStaysHiddenWithoutDiagnosticToggle() throws {
        let json = #"{"ok":true,"downloads":[{"ecid":1,"hash":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA","name":"Original.iso","name_encoding_suspect":false,"size":123,"done":0,"transferred":0,"progress":0,"sources_current":0,"sources_total":0,"sources_transferring":0,"sources_a4af":0,"status_code":0,"is_completed":false,"status":"Waiting","speed":0,"priority":0,"category":0,"part_met":"001.part.met","last_seen_complete":0,"last_received":0,"active_seconds":0,"available_parts":0,"shared":false,"alternative_names":[],"progress_colors":[]}]}"#
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        let item = try XCTUnwrap(DownloadItem.fromBridge(try XCTUnwrap(decoded.downloads)).first)

        XCTAssertNil(item.displayedNameEncodingValue(alwaysShowDiagnostic: false))
        XCTAssertFalse(item.usesDiagnosticNameEncodingFallback(alwaysShowDiagnostic: false))
        XCTAssertFalse(item.hasDisplayedNameEncodingValue(alwaysShowDiagnostic: false))
    }

    func testDisplayedNameEncodingValuePrefersMeaningfulSuggestionOverDiagnosticFallback() throws {
        let json = #"{"ok":true,"downloads":[{"ecid":1,"hash":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA","name":"FranÃ§ais.iso","name_encoding_suspect":true,"name_encoding_suggestion":"Français.iso","size":123,"done":0,"transferred":0,"progress":0,"sources_current":0,"sources_total":0,"sources_transferring":0,"sources_a4af":0,"status_code":0,"is_completed":false,"status":"Waiting","speed":0,"priority":0,"category":0,"part_met":"001.part.met","last_seen_complete":0,"last_received":0,"active_seconds":0,"available_parts":0,"shared":false,"alternative_names":[],"progress_colors":[]}]}"#
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        let item = try XCTUnwrap(DownloadItem.fromBridge(try XCTUnwrap(decoded.downloads)).first)

        XCTAssertEqual(item.displayedNameEncodingValue(alwaysShowDiagnostic: true), "Français.iso")
        XCTAssertFalse(item.usesDiagnosticNameEncodingFallback(alwaysShowDiagnostic: true))
        XCTAssertTrue(item.hasDisplayedNameEncodingValue(alwaysShowDiagnostic: true))
    }
}
