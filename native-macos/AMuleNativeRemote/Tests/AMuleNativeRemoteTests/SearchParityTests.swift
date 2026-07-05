import XCTest
import AMuleECBridgeAdapter
import AMuleECClient
import SharedModels

@testable import AMuleNativeRemote

@MainActor
final class SearchParityTests: XCTestCase {
    func testSearchOptionsBuildExtendedECRequest() throws {
        var options = SearchOptions()
        options.fileType = "Video"
        options.fileExtension = "mkv"
        options.minSizeText = "1000"
        options.maxSizeText = "2000"
        options.availabilityText = "3"

        let request = try options.ecRequest(scope: "global", query: " ubuntu ")

        XCTAssertEqual(request, ECSearchRequest(
            scope: "global",
            query: "ubuntu",
            fileType: "Video",
            extension: "mkv",
            minSize: 1_000,
            maxSize: 2_000,
            availability: 3
        ))
    }

    func testSearchOptionsRejectInvalidNumbers() {
        var options = SearchOptions()
        options.minSizeText = "ten"

        XCTAssertThrowsError(try options.ecRequest(scope: "global", query: "ubuntu")) { error in
            XCTAssertEqual(error as? SearchOptionsError, .invalidNumber("ten"))
        }
    }

    func testSearchOptionsFilterResultsByVisibleFieldsAndKnownState() {
        var options = SearchOptions()
        options.filterText = "mkv"
        options.hideKnownResults = true

        let results = [
            makeSearchResult(index: 1, name: "Ubuntu.iso", alreadyHave: false),
            makeSearchResult(index: 2, name: "Movie.mkv", alreadyHave: true),
            makeSearchResult(index: 3, name: "Clip.MKV", alreadyHave: false),
        ]

        XCTAssertEqual(options.filteredResults(results).map(\.index), [3])

        options.invertFilter = true
        XCTAssertEqual(options.filteredResults(results).map(\.index), [1])
    }

    func testAppModelSearchUsesExtendedRequest() async throws {
        let bridge = FakeBridgeAdapter()
        let model = AppModel(bridge: bridge, credentialStorage: PlatformServiceStubs.Credentials())
        model.searchQuery = " ubuntu "
        model.searchScope = "kad"
        model.searchOptions.fileType = "Archive"
        model.searchOptions.fileExtension = "zip"
        model.searchOptions.minSizeText = "1024"
        model.searchOptions.maxSizeText = "2048"
        model.searchOptions.availabilityText = "5"

        model.performSearch()

        try await waitUntil { bridge.lastSearchRequest != nil && !model.isSearchInProgress }
        XCTAssertEqual(bridge.lastSearchRequest, ECSearchRequest(
            scope: "kad",
            query: "ubuntu",
            fileType: "Archive",
            extension: "zip",
            minSize: 1_024,
            maxSize: 2_048,
            availability: 5
        ))
    }

    private func makeSearchResult(index: Int, name: String, alreadyHave: Bool) -> SearchResult {
        SearchResult(
            index: index,
            hash: "hash-\(index)",
            name: name,
            sizeBytes: 1024,
            sources: index,
            completeSources: 0,
            statusCode: 0,
            status: "Available",
            parentID: 0,
            alreadyHave: alreadyHave
        )
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 2_000_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now.advanced(by: .nanoseconds(Int(timeoutNanoseconds)))
        while ContinuousClock.now < deadline {
            if condition() { return }
            await Task.yield()
        }
        XCTFail("Timed out waiting for condition")
    }
}
