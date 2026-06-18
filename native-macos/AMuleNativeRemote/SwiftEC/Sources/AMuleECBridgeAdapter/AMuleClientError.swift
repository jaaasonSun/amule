import Foundation

public enum AMuleClientError: LocalizedError, Sendable {
    case invalidResponse(String)
    case bridgeFailure(String)
    case downloadNotFound(String)

    public var isDownloadNotFound: Bool {
        if case .downloadNotFound = self {
            return true
        }
        return false
    }

    public var errorDescription: String? {
        switch self {
        case .invalidResponse(let output):
            return "Invalid bridge response.\n\(output)"
        case .bridgeFailure(let message):
            return message
        case .downloadNotFound(let hash):
            return "File not found in download queue: \(hash)"
        }
    }
}
