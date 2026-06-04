import Foundation

public enum FilenameCleanupPreferences {
    public static let storageKey = "amule.filenameCleanup.prefixes"

    public static func decode(_ raw: String) -> [String] {
        guard let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return normalized(decoded)
    }

    public static func encode(_ prefixes: [String]) -> String {
        let normalizedPrefixes = normalized(prefixes)
        guard let data = try? JSONEncoder().encode(normalizedPrefixes),
              let encoded = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return encoded
    }

    public static func normalized(_ prefixes: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for prefix in prefixes {
            guard !prefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            guard seen.insert(prefix).inserted else {
                continue
            }
            result.append(prefix)
        }

        return result
    }
}
