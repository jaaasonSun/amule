import Foundation

public enum ConnectionState: Sendable, Equatable {
    case connected
    case disconnected
    case transitional
    case unknown
}

public enum ConnectionStateParser {
    public static func parse(_ value: String) -> ConnectionState {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "-" {
            return .unknown
        }

        let lower = trimmed.lowercased()

        let disconnectedTokens = [
            "disconnected", "not connected", "offline", "stopped", "off",
            "断开", "未连接", "離線", "离线", "未連線"
        ]
        if disconnectedTokens.contains(where: { lower.contains($0) }) {
            return .disconnected
        }

        let transitionalTokens = [
            "connecting", "starting", "initializing", "pending", "run", "running",
            "连接中", "正在连接", "連線中", "初始化"
        ]
        if transitionalTokens.contains(where: { lower.contains($0) }) {
            return .transitional
        }

        let connectedTokens = [
            "connected", "lowid", "highid", "firewalled", "on",
            "已连接", "已連線", "连接", "連線"
        ]
        if connectedTokens.contains(where: { lower.contains($0) }) {
            return .connected
        }

        if lower.contains("unknown") || lower.contains("未知") {
            return .unknown
        }

        return .unknown
    }
}

public enum ConnectionStateLocalizer {
    public static func localizedText(for state: ConnectionState) -> String {
        switch state {
        case .connected: return NSLocalizedString("Connected", comment: "")
        case .disconnected: return NSLocalizedString("Disconnected", comment: "")
        case .transitional: return NSLocalizedString("Connecting", comment: "")
        case .unknown: return NSLocalizedString("Unknown", comment: "")
        }
    }

    public static func compactText(for state: ConnectionState) -> String {
        switch state {
        case .connected: return NSLocalizedString("On", comment: "")
        case .disconnected: return NSLocalizedString("Off", comment: "")
        case .transitional: return NSLocalizedString("Run", comment: "")
        case .unknown: return "?"
        }
    }
}

public enum ED2kBadgeFormatter {
    public static func compactBadgeValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = ["Connected to ", "Connecting to "]
        guard let prefix = prefixes.first(where: { trimmed.hasPrefix($0) }) else {
            return ConnectionStateLocalizer.compactText(for: ConnectionStateParser.parse(value))
        }

        var rest = String(trimmed.dropFirst(prefix.count))
        if rest.hasSuffix(" LowID") {
            rest.removeLast(6)
        } else if rest.hasSuffix(" HighID") {
            rest.removeLast(7)
        }
        rest = rest.trimmingCharacters(in: .whitespacesAndNewlines)

        if let endpointRange = rest.range(
            of: #"\s+\[?[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(?::[0-9]+)?\]?$"#,
            options: .regularExpression
        ) {
            let name = String(rest[..<endpointRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                return name
            }
        }

        return rest.isEmpty ? ConnectionStateLocalizer.compactText(for: ConnectionStateParser.parse(value)) : rest
    }
}