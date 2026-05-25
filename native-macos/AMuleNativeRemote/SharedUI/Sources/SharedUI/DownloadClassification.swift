import Foundation

public enum DownloadClassification {
    public static func isCompleted(_ item: DownloadClassifiable) -> Bool {
        if item.isCompleted || item.statusCode == 9 {
            return true
        }
        if item.sizeBytes > 0 && item.doneBytes >= item.sizeBytes {
            return true
        }
        let lower = item.status.lowercased()
        if lower.contains("complete") || lower.contains("completed") {
            return true
        }
        if item.status.contains("完成") {
            return true
        }
        return false
    }

    public static func isPaused(_ item: DownloadClassifiable) -> Bool {
        if item.statusCode == 7 || item.statusCode == 5 {
            return true
        }
        let lower = item.status.lowercased()
        if lower.contains("paused") || lower.contains("insufficient") {
            return true
        }
        if item.status.contains("暂停") || item.status.contains("磁盘空间不足") {
            return true
        }
        return false
    }

    public static func isDownloading(_ item: DownloadClassifiable) -> Bool {
        if isCompleted(item) || isPaused(item) {
            return false
        }
        if item.statusCode == 8 ||
            item.statusCode == 2 ||
            item.statusCode == 3 ||
            item.statusCode == 10 ||
            item.statusCode == 4 ||
            item.statusCode == 5 {
            return false
        }
        if item.speedBytes > 0 {
            return true
        }
        if item.sourceTransferring > 0 {
            return true
        }
        let lower = item.status.lowercased()
        if lower.contains("downloading") {
            return true
        }
        if item.status.contains("下载") && !item.status.contains("等待") && !item.status.contains("暂停") {
            return true
        }
        return false
    }

    public static func isPending(_ item: DownloadClassifiable) -> Bool {
        if isCompleted(item) || isPaused(item) || isDownloading(item) {
            return false
        }
        return true
    }
}

public protocol DownloadClassifiable {
    var statusCode: Int { get }
    var status: String { get }
    var isCompleted: Bool { get }
    var sizeBytes: UInt64 { get }
    var doneBytes: UInt64 { get }
    var speedBytes: Int { get }
    var sourceTransferring: Int { get }
}

public enum DownloadStatusSymbol {
    public static let allCategorySymbolName = "tray.full"
    public static let downloadingCategorySymbolName = "arrow.down.circle"
    public static let pendingCategorySymbolName = "clock"
    public static let pausedCategorySymbolName = "pause.circle"
    public static let completedCategorySymbolName = "checkmark.circle"

    public static func categorySymbolName(for item: DownloadClassifiable) -> String {
        if DownloadClassification.isCompleted(item) {
            return completedCategorySymbolName
        }
        if DownloadClassification.isPaused(item) {
            return pausedCategorySymbolName
        }
        if DownloadClassification.isDownloading(item) {
            return downloadingCategorySymbolName
        }
        return pendingCategorySymbolName
    }

    public static func symbolName(for status: String) -> String {
        let raw = status.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercase = raw.lowercased()

        func hasAny(_ haystack: String, _ tokens: [String]) -> Bool {
            tokens.contains { haystack.contains($0) }
        }

        if hasAny(lowercase, ["error", "erroneous", "failed", "corrupt"]) || hasAny(raw, ["错误", "故障", "失败"]) {
            return "xmark.circle"
        }
        if hasAny(lowercase, ["complete", "completed"]) || hasAny(raw, ["完成", "已完成"]) {
            return "checkmark.circle"
        }
        if hasAny(lowercase, ["paused"]) || hasAny(raw, ["暂停"]) {
            return "pause.circle"
        }
        if hasAny(lowercase, ["hashing", "allocat", "completing"]) || hasAny(raw, ["哈希", "分配", "完成中"]) {
            return "progress.indicator"
        }
        if hasAny(lowercase, ["downloading"]) || hasAny(raw, ["下载"]) {
            return "arrow.down.circle"
        }
        if hasAny(lowercase, ["waiting", "ready", "empty"]) || hasAny(raw, ["等待"]) {
            return "clock"
        }
        return "questionmark.circle"
    }

    public static func circleSymbolName(for status: String) -> String {
        symbolName(for: status)
    }
}

public enum ConnectionStateSymbol {
    public static func symbolName(for state: ConnectionState) -> String {
        switch state {
        case .connected: return "checkmark.circle"
        case .disconnected: return "xmark.circle"
        case .transitional: return "arrow.2.circlepath"
        case .unknown: return "questionmark.circle"
        }
    }
}
