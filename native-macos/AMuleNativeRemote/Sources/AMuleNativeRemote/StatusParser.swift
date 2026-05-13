import Foundation

extension Notification.Name {
    static let amuleIncomingLinksDidChange = Notification.Name("AMuleIncomingLinksDidChange")
}

enum LinkImportSupport {
    static func parseLinks(from text: String) -> [String] {
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

    static func normalizeLink(_ link: String) -> String {
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

    static func extractEd2kHash(from link: String) -> String? {
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

    static func isValidEd2kHash(_ hash: String) -> Bool {
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

@MainActor
final class PendingIncomingLinkInbox {
    static let shared = PendingIncomingLinkInbox()

    private var links: [String] = []
    private var knownLinks = Set<String>()

    var hasPendingLinks: Bool {
        !links.isEmpty
    }

    func enqueue(_ rawInput: String) {
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

    func drain() -> [String] {
        let drained = links
        links.removeAll()
        knownLinks.removeAll()
        return drained
    }
}


enum BridgeCapabilityGate {
    static func isSupported(_ op: String, by supportedOps: Set<String>) -> Bool {
        supportedOps.isEmpty || supportedOps.contains(op)
    }
}


struct StatusSnapshot {
    var connected: Bool = false
    var ed2k: String = "Unknown"
    var kad: String = "Unknown"
    var downloadBytesPerSecond: Int? = nil
    var uploadBytesPerSecond: Int? = nil
    var queueCount: Int? = nil
    var sourcesCount: Int? = nil

    var downloadSpeed: String {
        guard let downloadBytesPerSecond else { return "-" }
        return AMuleFormatter.speed(bytesPerSecond: downloadBytesPerSecond)
    }

    var uploadSpeed: String {
        guard let uploadBytesPerSecond else { return "-" }
        return AMuleFormatter.speed(bytesPerSecond: uploadBytesPerSecond)
    }

    var queue: String {
        guard let queueCount else { return "-" }
        return String(queueCount)
    }

    var sources: String {
        guard let sourcesCount else { return "-" }
        return String(sourcesCount)
    }

    var looksConnected: Bool {
        connected
    }

    static func fromBridge(_ payload: BridgeStatusPayload) -> StatusSnapshot {
        StatusSnapshot(
            connected: payload.connected,
            ed2k: payload.ed2k,
            kad: payload.kad,
            downloadBytesPerSecond: payload.downloadSpeed,
            uploadBytesPerSecond: payload.uploadSpeed,
            queueCount: payload.queue,
            sourcesCount: payload.sources
        )
    }
}
