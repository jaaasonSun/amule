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
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("eD2k:") {
                snapshot.ed2k = line.replacingOccurrences(of: "eD2k:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("Kad:") {
                snapshot.kad = line.replacingOccurrences(of: "Kad:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("Download:") {
                snapshot.downloadSpeed = line.replacingOccurrences(of: "Download:\t", with: "")
                    .replacingOccurrences(of: "Download:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("Upload:") {
                snapshot.uploadSpeed = line.replacingOccurrences(of: "Upload:\t", with: "")
                    .replacingOccurrences(of: "Upload:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("Clients in queue:") {
                snapshot.queue = line.replacingOccurrences(of: "Clients in queue:\t", with: "")
                    .replacingOccurrences(of: "Clients in queue:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("Total sources:") {
                snapshot.sources = line.replacingOccurrences(of: "Total sources:\t", with: "")
                    .replacingOccurrences(of: "Total sources:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return snapshot
    }
}
