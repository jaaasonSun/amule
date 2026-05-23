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
