import Foundation

public extension Notification.Name {
    static let amuleIncomingLinksDidChange = Notification.Name("AMuleIncomingLinksDidChange")
}

public enum LinkImportSupport {
    public static func parseLinks(from text: String) -> [String] {
        var unique = Set<String>()
        var ordered: [String] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            guard line.lowercased().hasPrefix("ed2k://") || line.lowercased().hasPrefix("magnet:?") else { continue }
            if unique.insert(line).inserted {
                ordered.append(line)
            }
        }

        return ordered
    }

    public static func normalizeLink(_ link: String) -> String {
        var normalized = link
        let lower = normalized.lowercased()

        if lower.hasPrefix("ed2k://%7c") {
            normalized = normalized.replacingOccurrences(of: "%7C", with: "|", options: .caseInsensitive)
        }

        if lower.hasPrefix("ed2k://"),
           normalized.contains("|h="),
           !normalized.contains("|/|h=") {
            normalized = normalized.replacingOccurrences(of: "|h=", with: "|/|h=")
        }

        return normalized
    }

    public static func extractEd2kHash(from link: String) -> String? {
        let normalized = link.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            return nil
        }

        if normalized.lowercased().hasPrefix("magnet:?"),
           let components = URLComponents(string: normalized) {
            for item in components.queryItems ?? [] where item.name.lowercased() == "xt" {
                guard let value = item.value else { continue }
                let lower = value.lowercased()
                if lower.hasPrefix("urn:ed2k:") {
                    let hash = String(value.dropFirst("urn:ed2k:".count))
                    if isValidEd2kHash(hash) {
                        return hash.uppercased()
                    }
                }
            }
        }

        let decoded = normalized.removingPercentEncoding ?? normalized
        if let range = decoded.range(of: #"[0-9A-Fa-f]{32}"#, options: .regularExpression) {
            let hash = String(decoded[range])
            if isValidEd2kHash(hash) {
                return hash.uppercased()
            }
        }

        return nil
    }

    public static func isValidEd2kHash(_ hash: String) -> Bool {
        guard hash.count == 32 else { return false }
        return hash.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 48...57, 65...70, 97...102:
                return true
            default:
                return false
            }
        }
    }
}

public enum LinkImportDiagnosticKind: String, Equatable, Sendable {
    case validNormalizedLink
    case ignoredUnsupportedLine
    case duplicateNormalizedLink
    case malformedHash
    case failedLink
    case alreadyPresentOrSkipped
    case acceptedButNotVisible
    case unverifiable
}

public struct LinkImportDiagnosticItem: Equatable, Sendable {
    public let kind: LinkImportDiagnosticKind
    public let line: String
    public let detail: String?

    public init(kind: LinkImportDiagnosticKind, line: String, detail: String?) {
        self.kind = kind
        self.line = line
        self.detail = detail
    }
}

public struct LinkImportDiagnostics: Equatable, Sendable {
    public let items: [LinkImportDiagnosticItem]

    public init(items: [LinkImportDiagnosticItem]) {
        self.items = items
    }

    public var validNormalizedLinks: [String] {
        items.compactMap { $0.kind == .validNormalizedLink ? $0.line : nil }
    }

    public static func analyze(rawInput: String) -> LinkImportDiagnostics {
        var items: [LinkImportDiagnosticItem] = []
        var seen = Set<String>()

        for rawLine in rawInput.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            let lower = line.lowercased()
            guard lower.hasPrefix("ed2k://") || lower.hasPrefix("magnet:?") else {
                items.append(.init(kind: .ignoredUnsupportedLine, line: line, detail: nil))
                continue
            }

            let normalized = LinkImportSupport.normalizeLink(line)
            let hash = LinkImportSupport.extractEd2kHash(from: normalized)
            let normalizedKey = normalized.lowercased()

            if lower.hasPrefix("magnet:?") {
                if normalized.lowercased().contains("urn:ed2k:") && hash == nil {
                    items.append(.init(kind: .malformedHash, line: line, detail: "invalid ED2K hash"))
                    continue
                }
                if hash == nil {
                    items.append(.init(kind: .unverifiable, line: line, detail: "could not verify link"))
                    continue
                }
            } else if normalized.lowercased().contains("|h=") && hash == nil {
                items.append(.init(kind: .malformedHash, line: line, detail: "invalid ED2K hash"))
                continue
            } else if isMalformedEd2kFileLink(normalized) && hash == nil {
                items.append(.init(kind: .malformedHash, line: line, detail: "invalid ED2K hash"))
                continue
            }

            if !seen.insert(normalizedKey).inserted {
                items.append(.init(kind: .duplicateNormalizedLink, line: normalized, detail: nil))
                continue
            }

            items.append(.init(kind: .validNormalizedLink, line: normalized, detail: nil))
        }

        return LinkImportDiagnostics(items: items)
    }

    private static func isMalformedEd2kFileLink(_ link: String) -> Bool {
        let lower = link.lowercased()
        guard lower.hasPrefix("ed2k://") else { return false }
        let decoded = link.removingPercentEncoding ?? link
        let parts = decoded.split(separator: "|")
        guard parts.count >= 5 else { return false }
        guard parts.first?.lowercased().hasPrefix("ed2k://") == true else { return false }
        return !LinkImportSupport.isValidEd2kHash(String(parts[4]))
    }
}

public struct LinkImportDiagnosticsPresentation: Equatable, Sendable {
    public let summaryText: String
    public let detailLines: [String]

    public init(summaryText: String, detailLines: [String]) {
        self.summaryText = summaryText
        self.detailLines = detailLines
    }
}

public enum LinkImportDiagnosticsFormatter {
    public static func format(diagnostics: LinkImportDiagnostics) -> LinkImportDiagnosticsPresentation {
        let counts = diagnostics.items.reduce(into: [LinkImportDiagnosticKind: Int]()) { partial, item in
            partial[item.kind, default: 0] += 1
        }

        let summaryParts: [String] = [
            counts[.validNormalizedLink, default: 0].mapCount("valid"),
            counts[.ignoredUnsupportedLine, default: 0].mapCount("ignored"),
            counts[.duplicateNormalizedLink, default: 0].mapCount("duplicate"),
            counts[.malformedHash, default: 0].mapCount("malformed"),
            counts[.alreadyPresentOrSkipped, default: 0].mapCount("skipped"),
            counts[.acceptedButNotVisible, default: 0].mapCount("invisible"),
            counts[.unverifiable, default: 0].mapCount("unverifiable"),
            counts[.failedLink, default: 0].mapCount("failed")
        ].compactMap { $0 }

        let summaryText = summaryParts.isEmpty ? "No importable links" : summaryParts.joined(separator: ", ")

        var detailLines: [String] = []
        if let added = counts[.validNormalizedLink], added > 0 {
            detailLines.append(added == 1 ? "Added 1 link." : "Added \(added) links.")
        }
        if let ignored = counts[.ignoredUnsupportedLine], ignored > 0 {
            detailLines.append(ignored == 1 ? "Ignored 1 unsupported line." : "Ignored \(ignored) unsupported lines.")
        }
        if let duplicates = counts[.duplicateNormalizedLink], duplicates > 0 {
            detailLines.append(duplicates == 1 ? "1 duplicate link skipped." : "\(duplicates) duplicate links skipped.")
        }
        if let malformed = counts[.malformedHash], malformed > 0 {
            detailLines.append(malformed == 1 ? "1 link has an invalid ED2K hash." : "\(malformed) links have invalid ED2K hashes.")
        }
        if let skipped = counts[.alreadyPresentOrSkipped], skipped > 0 {
            detailLines.append(skipped == 1 ? "1 already present or skipped." : "\(skipped) already present or skipped.")
        }
        if let invisible = counts[.acceptedButNotVisible], invisible > 0 {
            detailLines.append(invisible == 1 ? "1 accepted but not visible." : "\(invisible) accepted but not visible.")
        }
        let hasAnyVerifiedResult = counts[.validNormalizedLink, default: 0] > 0
            || counts[.alreadyPresentOrSkipped, default: 0] > 0
            || counts[.acceptedButNotVisible, default: 0] > 0
            || counts[.failedLink, default: 0] > 0

        if let unverifiable = counts[.unverifiable], unverifiable > 0 {
            if !hasAnyVerifiedResult {
                detailLines.append("This result could not be verified.")
            } else {
                detailLines.append(unverifiable == 1 ? "1 unverifiable." : "\(unverifiable) unverifiable.")
            }
        }

        if let failed = counts[.failedLink], failed > 0 {
            detailLines.append(failed == 1 ? "1 failed." : "\(failed) failed.")
        }

        if detailLines.isEmpty, counts[.unverifiable, default: 0] > 0, !hasAnyVerifiedResult {
            detailLines.append("This result could not be verified.")
        }

        return LinkImportDiagnosticsPresentation(summaryText: summaryText, detailLines: detailLines)
    }
}

private extension Int {
    func mapCount(_ label: String) -> String? {
        guard self > 0 else { return nil }
        return self == 1 ? "1 \(label)" : "\(self) \(label)"
    }
}

public struct LinkImportPlan: Equatable, Sendable {
    public let links: [String]
    public let normalizedLinks: [String]
    public let requestedHashes: Set<String>

    public init?(rawInput: String) {
        let links = LinkImportSupport.parseLinks(from: rawInput)
        guard !links.isEmpty else { return nil }

        self.links = links
        self.normalizedLinks = links.map { LinkImportSupport.normalizeLink($0) }
        self.requestedHashes = Set(normalizedLinks.compactMap { LinkImportSupport.extractEd2kHash(from: $0) })
    }

    public var count: Int {
        links.count
    }
}

public struct LinkImportOutcome: Equatable, Sendable {
    public let successCount: Int
    public let failureCount: Int
    public let displayedAddedCount: Int

    public init(successCount: Int, failureCount: Int, displayedAddedCount: Int? = nil) {
        self.successCount = successCount
        self.failureCount = failureCount
        self.displayedAddedCount = displayedAddedCount ?? successCount
    }

    public var hasFailures: Bool {
        failureCount > 0
    }

    public var hasAnyResult: Bool {
        successCount > 0 || failureCount > 0
    }
}

@MainActor
public final class PendingIncomingLinkInbox {
    public static let shared = PendingIncomingLinkInbox()

    private var links: [String] = []
    private var knownLinks = Set<String>()

    public init() {}

    public var hasPendingLinks: Bool {
        !links.isEmpty
    }

    public func enqueue(_ rawInput: String) {
        let parsed = LinkImportSupport.parseLinks(from: rawInput)
        guard !parsed.isEmpty else { return }

        var didInsert = false
        for link in parsed where knownLinks.insert(link).inserted {
            links.append(link)
            didInsert = true
        }

        if didInsert {
            NotificationCenter.default.post(name: .amuleIncomingLinksDidChange, object: nil)
        }
    }

    public func drain() -> [String] {
        let drained = links
        links.removeAll()
        knownLinks.removeAll()
        return drained
    }
}
