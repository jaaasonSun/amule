import Foundation

struct SearchResult: Identifiable, Hashable {
    let id: Int
    let name: String
    let sizeMB: String
    let sources: Int
}

struct DownloadItem: Identifiable, Hashable {
    let id: String
    let name: String
    let progress: String
    let progressValue: Double
    let sources: String
    let sourceCurrent: Int
    let sourceTotal: Int
    let status: String
    let speed: String
}

enum CommandOutputParser {
    static func parseSearchResults(_ output: String) -> [SearchResult] {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
        var resultsByID: [Int: SearchResult] = [:]

        for lineSub in lines {
            let line = normalizedPromptLine(String(lineSub))
            guard let id = parseLeadingIndex(line) else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let withoutPrefix = trimmed.replacingOccurrences(of: "\(id).", with: "", options: [.anchored])
                .trimmingCharacters(in: .whitespaces)

            guard let sources = trailingInteger(withoutPrefix) else { continue }
            var body = withoutPrefix
            if let range = body.range(of: "\(sources)", options: [.backwards, .anchored]) {
                body.removeSubrange(range)
            }
            body = body.trimmingCharacters(in: .whitespaces)

            let tokens = body.split(whereSeparator: { $0.isWhitespace })
            guard !tokens.isEmpty else { continue }

            // Size is rendered near the end as e.g. 123.456 (MB.KB)
            let sizeToken = tokens.last(where: { $0.contains(".") && $0.allSatisfy({ $0.isNumber || $0 == "." }) })
            let size = sizeToken.map(String.init) ?? "-"

            var name = body
            if size != "-", let sizeRange = body.range(of: size, options: [.backwards]) {
                name = String(body[..<sizeRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            }

            resultsByID[id] = .init(id: id, name: name, sizeMB: size, sources: sources)
        }

        return resultsByID.values.sorted { $0.id < $1.id }
    }

    static func parseDownloads(_ output: String) -> [DownloadItem] {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var items: [DownloadItem] = []
        var pendingHash = ""
        var pendingName = ""

        for line in lines {
            let normalized = normalizedPromptLine(line)

            if let (hash, name) = parseHashHeader(normalized) {
                pendingHash = hash
                pendingName = name
                continue
            }

            guard !pendingHash.isEmpty else {
                continue
            }

            let trimmed = normalized.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("[") else {
                continue
            }

            let progress = firstMatch(in: normalized, pattern: #"\[(\d+(?:\.\d+)?)%\]"#, group: 1) ?? "0.0"
            let speed = trailingSpeed(in: normalized)
            let parts = normalized.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
            let status = parts.indices.contains(1) ? parts[1] : ""
            let sourcesRaw = firstMatch(in: normalized, pattern: #"\]\s*([0-9]+\s*/\s*[0-9]+)"#, group: 1) ?? "-"
            let sources = sourcesRaw.replacingOccurrences(of: " ", with: "")
            let sourceParts = sources.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true)
            let sourceCurrent = sourceParts.isEmpty ? 0 : Int(sourceParts[0]) ?? 0
            let sourceTotal = sourceParts.count < 2 ? 0 : Int(sourceParts[1]) ?? 0

            items.append(.init(
                id: pendingHash,
                name: pendingName,
                progress: progress,
                progressValue: Double(progress) ?? 0,
                sources: sources,
                sourceCurrent: sourceCurrent,
                sourceTotal: sourceTotal,
                status: status,
                speed: speed
            ))

            pendingHash = ""
            pendingName = ""
        }

        return items
    }

    private static func parseLeadingIndex(_ line: String) -> Int? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let dotIndex = trimmed.firstIndex(of: ".") else { return nil }
        let prefix = trimmed[..<dotIndex]
        return Int(prefix)
    }

    private static func trailingInteger(_ text: String) -> Int? {
        let parts = text.split(whereSeparator: { $0.isWhitespace })
        guard let last = parts.last else { return nil }
        return Int(last)
    }

    private static func parseHashHeader(_ line: String) -> (String, String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let tokens = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard tokens.count == 2 else { return nil }
        let hash = String(tokens[0])
        guard hash.count == 32, hash.allSatisfy({ $0.isHexDigit }) else { return nil }
        return (hash, String(tokens[1]))
    }

    private static func firstMatch(in text: String, pattern: String, group: Int) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let foundRange = Range(match.range(at: group), in: text) else {
            return nil
        }
        return String(text[foundRange])
    }

    private static func trailingSpeed(in line: String) -> String {
        let parts = line.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
        return parts.last(where: { $0.contains("B/s") }) ?? ""
    }

    private static func normalizedPromptLine(_ line: String) -> String {
        var text = line.trimmingCharacters(in: .whitespaces)
        while text.hasPrefix(">") || text.hasPrefix("?") {
            text.removeFirst()
            text = text.trimmingCharacters(in: .whitespaces)
        }
        return text
    }
}
