import Foundation
import SharedModels
import SharedServices
import SharedViews

@available(macOS 13.0, iOS 15.0, *)
public enum DownloadListFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case downloading
    case pending
    case paused
    case completed

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: return "All"
        case .downloading: return "Downloading"
        case .pending: return "Pending"
        case .paused: return "Paused"
        case .completed: return "Completed"
        }
    }

    public var systemImage: String {
        switch self {
        case .all: return DownloadStatusSymbol.allCategorySymbolName
        case .downloading: return DownloadStatusSymbol.downloadingCategorySymbolName
        case .pending: return DownloadStatusSymbol.pendingCategorySymbolName
        case .paused: return DownloadStatusSymbol.pausedCategorySymbolName
        case .completed: return DownloadStatusSymbol.completedCategorySymbolName
        }
    }
}

@available(macOS 13.0, iOS 15.0, *)
public enum DownloadListSort: String, CaseIterable, Identifiable, Sendable {
    case name
    case progress
    case speed
    case size
    case sources
    case status

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .name: return "Name"
        case .progress: return "Progress"
        case .speed: return "Speed"
        case .size: return "Size"
        case .sources: return "Sources"
        case .status: return "Status"
        }
    }
}

@available(macOS 13.0, iOS 15.0, *)
public enum DownloadListPresentation {
    public static func displayedDownloads(
        _ items: [DownloadItem],
        filter: DownloadListFilter,
        query: String,
        sort: DownloadListSort,
        ascending: Bool
    ) -> [DownloadItem] {
        let scoped = items.filter { matchesFilter($0, filter: filter) }
        let searched = scoped.filter { matchesQuery($0, query: query) }
        return searched.sorted { lhs, rhs in
            let result = compare(lhs, rhs, sort: sort)
            if result == .orderedSame {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }
    }

    public static func count(_ items: [DownloadItem], matching filter: DownloadListFilter) -> Int {
        items.filter { matchesFilter($0, filter: filter) }.count
    }

    private static func matchesFilter(_ item: DownloadItem, filter: DownloadListFilter) -> Bool {
        switch filter {
        case .all:
            return true
        case .downloading:
            return DownloadClassification.isDownloading(item)
        case .pending:
            return DownloadClassification.isPending(item)
        case .paused:
            return DownloadClassification.isPaused(item)
        case .completed:
            return DownloadClassification.isCompleted(item)
        }
    }

    private static func matchesQuery(_ item: DownloadItem, query: String) -> Bool {
        let tokens = normalizedSearchText(query)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return true }

        let values = [
            item.name,
            item.trimmedDisplayName ?? "",
            item.meaningfulNameEncodingSuggestion ?? "",
            item.status,
        ]
        let haystack = normalizedSearchText(values.joined(separator: " "))
        let compactHaystack = haystack.replacingOccurrences(of: " ", with: "")
        return tokens.allSatisfy { token in
            haystack.contains(token) || compactHaystack.contains(token)
        }
    }

    private static func normalizedSearchText(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
    }

    private static func compare(_ lhs: DownloadItem, _ rhs: DownloadItem, sort: DownloadListSort) -> ComparisonResult {
        switch sort {
        case .name:
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        case .progress:
            return compare(lhs.progressSortValue, rhs.progressSortValue)
        case .speed:
            return compare(lhs.speedSortValue, rhs.speedSortValue)
        case .size:
            return compare(lhs.sizeBytes, rhs.sizeBytes)
        case .sources:
            return compare(lhs.sourceTotal, rhs.sourceTotal)
        case .status:
            return lhs.status.localizedCaseInsensitiveCompare(rhs.status)
        }
    }

    private static func compare<T: Comparable>(_ lhs: T, _ rhs: T) -> ComparisonResult {
        if lhs < rhs { return .orderedAscending }
        if lhs > rhs { return .orderedDescending }
        return .orderedSame
    }
}
