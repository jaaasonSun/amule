import Foundation

struct StatusSnapshot {
    var ed2k: String = "Unknown"
    var kad: String = "Unknown"
    var downloadSpeed: String = "-"
    var uploadSpeed: String = "-"
    var queue: String = "-"
    var sources: String = "-"

    static func fromOutput(_ output: String) -> StatusSnapshot {
        var snapshot = StatusSnapshot()
        for raw in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = normalizedPromptLine(String(raw))
            if let value = valueAfterLabel(in: line, label: "eD2k:") {
                snapshot.ed2k = value
            } else if let value = valueAfterLabel(in: line, label: "Kad:") {
                snapshot.kad = value
            } else if let value = valueAfterLabel(in: line, label: "Download:") {
                snapshot.downloadSpeed = value
            } else if let value = valueAfterLabel(in: line, label: "Upload:") {
                snapshot.uploadSpeed = value
            } else if let value = valueAfterLabel(in: line, label: "Clients in queue:") {
                snapshot.queue = value
            } else if let value = valueAfterLabel(in: line, label: "Total sources:") {
                snapshot.sources = value
            }
        }
        return snapshot
    }

    private static func valueAfterLabel(in line: String, label: String) -> String? {
        guard let range = line.range(of: label) else { return nil }
        return String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
    }

    private static func normalizedPromptLine(_ line: String) -> String {
        var text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        while text.hasPrefix(">") || text.hasPrefix("?") {
            text.removeFirst()
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }
}
