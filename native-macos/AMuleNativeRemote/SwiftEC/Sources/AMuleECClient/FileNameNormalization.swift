import Foundation

struct FileNameNormalization {
    let suspect: Bool
    let suggestion: String?

    init(name: String, suspect: Bool, suggestion: String?) {
        let repairedName = FileNameEncodingRepair.repairedSuggestion(for: name)
        let trimmedSuggestion = suggestion?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveSuggestion = (trimmedSuggestion?.isEmpty == false && trimmedSuggestion != name)
            ? trimmedSuggestion
            : repairedName

        self.suspect = suspect || effectiveSuggestion != nil
        self.suggestion = effectiveSuggestion
    }
}
