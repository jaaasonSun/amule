import Foundation

public enum FileNameSuggestionPolicy {
    public static func suggestion(
        currentName: String,
        providedSuggestion: String? = nil,
        prefixes: [String] = []
    ) -> String? {
        let current = currentName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !current.isEmpty else { return nil }

        let provided = meaningfulProvidedSuggestion(providedSuggestion, currentName: current)
        let repaired = FileNameEncodingRepair.repairedSuggestion(for: current)
        let candidate = provided ?? repaired

        if let candidate {
            return meaningful(cleaned(candidate, prefixes: prefixes), currentName: current)
        }

        return meaningful(cleaned(current, prefixes: prefixes), currentName: current)
    }

    private static func meaningfulProvidedSuggestion(_ suggestion: String?, currentName: String) -> String? {
        guard let suggestion else { return nil }
        let trimmed = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != currentName else { return nil }
        return trimmed
    }

    private static func cleaned(_ name: String, prefixes: [String]) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let prefix = longestMatchingPrefix(in: trimmed, prefixes: prefixes) else {
            return trimmed
        }

        let end = trimmed.index(trimmed.startIndex, offsetBy: prefix.count)
        return String(trimmed[end...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func longestMatchingPrefix(in name: String, prefixes: [String]) -> String? {
        prefixes
            .filter { !$0.isEmpty && name.count >= $0.count && hasCaseInsensitivePrefix(name, $0) }
            .max { $0.count < $1.count }
    }

    private static func hasCaseInsensitivePrefix(_ name: String, _ prefix: String) -> Bool {
        let end = name.index(name.startIndex, offsetBy: prefix.count)
        let candidatePrefix = String(name[..<end])
        return candidatePrefix.compare(prefix, options: [.caseInsensitive, .literal]) == .orderedSame
    }

    private static func meaningful(_ suggestion: String, currentName: String) -> String? {
        guard !suggestion.isEmpty, suggestion != currentName else { return nil }
        return suggestion
    }
}
