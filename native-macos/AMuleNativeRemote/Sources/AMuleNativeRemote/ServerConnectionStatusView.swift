import SwiftUI
import SharedModels
import SharedServices

private func L2ServerStatus(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func LF2ServerStatus(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), locale: .current, arguments: args)
}

enum ServerWindowConnectionState2 {
    case connected
    case disconnected
    case transitional
    case unknown
}

func connectionState2(from value: String) -> ServerWindowConnectionState2 {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty || trimmed == "-" { return .unknown }

    let lower = trimmed.lowercased()
    if ["disconnected", "not connected", "offline", "stopped", "off", "断开", "未连接", "離線", "离线", "未連線"]
        .contains(where: { lower.contains($0) }) {
        return .disconnected
    }
    if ["connecting", "starting", "initializing", "pending", "run", "running", "连接中", "正在连接", "連線中", "初始化"]
        .contains(where: { lower.contains($0) }) {
        return .transitional
    }
    if ["connected", "lowid", "highid", "firewalled", "on", "已连接", "已連線", "连接", "連線"]
        .contains(where: { lower.contains($0) }) {
        return .connected
    }
    return .unknown
}

func localizedConnectionStateText2(_ state: ServerWindowConnectionState2) -> String {
    switch state {
    case .connected: return L2ServerStatus("Connected")
    case .disconnected: return L2ServerStatus("Disconnected")
    case .transitional: return L2ServerStatus("Connecting")
    case .unknown: return L2ServerStatus("Unknown")
    }
}

func extractED2kServerName2(from value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let prefixes = ["Connected to ", "Connecting to "]
    guard let prefix = prefixes.first(where: { trimmed.hasPrefix($0) }) else { return nil }

    var rest = String(trimmed.dropFirst(prefix.count))
    if let suffixRange = rest.range(of: #"\s+(LowID|HighID)\s*$"#, options: .regularExpression) {
        rest.removeSubrange(suffixRange)
    }
    if let endpointRange = rest.range(
        of: #"\s+\[?[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(?::[0-9]+)?\]?$"#,
        options: .regularExpression
    ) {
        rest.removeSubrange(endpointRange)
    }
    let name = rest.trimmingCharacters(in: .whitespacesAndNewlines)
    return name.isEmpty ? nil : name
}

func localizedED2kStatusSummary2(_ value: String) -> String {
    let state = connectionState2(from: value)
    switch state {
    case .connected:
        if let name = extractED2kServerName2(from: value) {
            return LF2ServerStatus("Connected to %@", name)
        }
    case .transitional:
        if let name = extractED2kServerName2(from: value) {
            return LF2ServerStatus("Connecting to %@", name)
        }
    case .disconnected, .unknown:
        break
    }
    return localizedConnectionStateText2(state)
}

struct ServerConnectionStatusView: View {
    let statusText: String

    var body: some View {
        Text(localizedED2kStatusSummary2(statusText))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
    }
}
