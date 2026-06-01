import XCTest
import SharedViews
@testable import AMuleRemoteiOS

final class FilenameSuggestionPresentationTests: XCTestCase {
    func testSuggestionBecomesRenameDraftWhenDifferentFromCurrentName() {
        XCTAssertEqual(
            FilenameSuggestionPresentation.renameDraft(
                from: "  Corrected 中文.mkv  ",
                currentName: "Mojibake.mkv"
            ),
            "Corrected 中文.mkv"
        )
    }

    func testSuggestionDoesNotBecomeDraftWhenEmptyOrUnchanged() {
        XCTAssertNil(FilenameSuggestionPresentation.renameDraft(from: "   ", currentName: "Mojibake.mkv"))
        XCTAssertNil(FilenameSuggestionPresentation.renameDraft(from: "Mojibake.mkv", currentName: "Mojibake.mkv"))
    }
}
