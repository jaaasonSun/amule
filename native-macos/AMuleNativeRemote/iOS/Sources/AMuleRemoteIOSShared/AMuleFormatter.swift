import Foundation

@available(macOS 12.0, iOS 15.0, *)
public enum AMuleFormatter {
    public static func speed(bytesPerSecond: Int) -> String {
        guard bytesPerSecond > 0 else {
            return "-"
        }
        let text = ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .binary)
            .replacingOccurrences(of: " bytes", with: " B")
            .replacingOccurrences(of: " byte", with: " B")
        return "\(text)/s"
    }

    public static func fileSize(_ bytes: UInt64) -> String {
        if bytes > UInt64(Int64.max) {
            return ByteCountFormatter.string(fromByteCount: Int64.max, countStyle: .file)
        }
        return fileSize(Int64(bytes))
    }

    public static func fileSize(_ bytes: Int64) -> String {
        guard bytes > 0 else {
            return "-"
        }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    public static func duration(seconds: Int) -> String {
        guard seconds > 0 else {
            return "-"
        }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%02dh %02dm %02ds", hours, minutes, secs)
        }
        return String(format: "%02dm %02ds", minutes, secs)
    }

    @available(macOS 12.0, iOS 15.0, *)
    public static func dateTime(unix: UInt64) -> String {
        guard unix > 0 else {
            return "-"
        }
        let date = Date(timeIntervalSince1970: TimeInterval(unix))
        return date.formatted(date: .numeric, time: .standard)
    }

    public static func priority(_ value: Int) -> String {
        switch value {
        case 0: return "Low"
        case 1: return "Normal"
        case 2: return "High"
        case 10: return "Auto (Low)"
        case 11: return "Auto (Normal)"
        case 12: return "Auto (High)"
        default: return String(value)
        }
    }
}
