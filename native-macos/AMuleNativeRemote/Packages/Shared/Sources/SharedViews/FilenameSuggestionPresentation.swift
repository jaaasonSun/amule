import Foundation

public enum FilenameSuggestionPresentation {
    public static func renameDraft(from suggestion: String, currentName: String) -> String? {
        let trimmed = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != currentName else { return nil }
        return trimmed
    }
}
