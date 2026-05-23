import Foundation

@available(macOS 13.0, iOS 15.0, *)
public enum FilenameSuggestionPresentation {
    public static func renameDraft(from suggestion: String, currentName: String) -> String? {
        let trimmed = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != currentName else { return nil }
        return trimmed
    }
}
