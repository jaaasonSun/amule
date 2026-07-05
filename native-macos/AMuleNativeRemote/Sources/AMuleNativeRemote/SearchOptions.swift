import Foundation
import AMuleECClient
import SharedModels

struct SearchOptions: Equatable {
    var fileType = ""
    var fileExtension = ""
    var minSizeText = ""
    var maxSizeText = ""
    var availabilityText = ""
    var filterText = ""
    var invertFilter = false
    var hideKnownResults = false
    var categoryID = 0

    func ecRequest(scope: String, query: String) throws -> ECSearchRequest {
        ECSearchRequest(
            scope: scope,
            query: query.trimmingCharacters(in: .whitespacesAndNewlines),
            fileType: fileType.trimmingCharacters(in: .whitespacesAndNewlines),
            extension: fileExtension.trimmingCharacters(in: .whitespacesAndNewlines),
            minSize: try Self.parseUInt64(minSizeText),
            maxSize: try Self.parseUInt64(maxSizeText),
            availability: try Self.parseUInt64(availabilityText)
        )
    }

    func filteredResults(_ results: [SearchResult]) -> [SearchResult] {
        let needle = filterText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return results.filter { result in
            if hideKnownResults, result.alreadyHave {
                return false
            }
            guard !needle.isEmpty else { return true }
            let fileExtension = (result.name as NSString).pathExtension
            let fields = [
                result.name,
                fileExtension,
                result.status,
                result.hash,
                result.sizeDisplay,
                result.alreadyHaveText,
            ]
            let matches = fields.contains { $0.lowercased().contains(needle) }
            return invertFilter ? !matches : matches
        }
    }

    private static func parseUInt64(_ text: String) throws -> UInt64 {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        guard let value = UInt64(trimmed) else {
            throw SearchOptionsError.invalidNumber(trimmed)
        }
        return value
    }
}

enum SearchOptionsError: Error, Equatable {
    case invalidNumber(String)
}
