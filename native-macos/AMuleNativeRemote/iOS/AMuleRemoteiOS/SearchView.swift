#if canImport(UIKit)
import SwiftUI
import AMuleRemoteIOSShared
import SharedUI

struct SearchView: View {
    @ObservedObject var model: IOSAppModel
    @State private var searchQuery = ""

    var body: some View {
        List {
            Section {
                Picker(L("Search Scope"), selection: $model.searchScope) {
                    Text(L("Kad")).tag("kad")
                    Text(L("Global")).tag("global")
                    Text(L("Server")).tag("local")
                }
                .pickerStyle(.segmented)
                .disabled(model.isSearchInProgress)
            } header: {
                Text(L("Search Scope"))
            }

            if model.searchResults.isEmpty && !model.isSearchInProgress {
                ContentUnavailableView(
                    "Search",
                    systemImage: "magnifyingglass",
                    description: Text(model.isSessionConnected
                        ? L("Enter a search query to find files on the eD2k network.")
                        : L("Connect to an aMule server to search."))
                )
            } else {
                ForEach(model.searchResults) { result in
                    SearchResultRow(result: result, model: model)
                }
            }
        }
        .searchable(text: $searchQuery, prompt: Text("Search files"))
        .onSubmit(of: .search) {
            model.performSearch(query: searchQuery)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if model.isSearchInProgress {
                    ProgressView()
                        .controlSize(.small)
                } else if !model.searchResults.isEmpty {
                    Button {
                        model.searchResults = []
                        searchQuery = ""
                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                    }
                }
            }
        }
    }
}

private struct SearchResultRow: View {
    let result: SearchResult
    @ObservedObject var model: IOSAppModel
    @State private var isDownloading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: statusIcon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(result.name)
                    .font(.body)
                    .lineLimit(2)
                    .truncationMode(.middle)
                Spacer()
                Text(result.sizeDisplay)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text(LF("%lld sources", result.sources))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(LF("%lld complete", result.completeSources))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if result.alreadyHave {
                    Text("Already have")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing) {
            Button {
                downloadIfNeeded()
            } label: {
                Label("Download", systemImage: "arrow.down.circle")
            }
            .tint(.blue)
            .disabled(isDownloading)
        }
    }

    private func downloadIfNeeded() {
        guard !isDownloading else { return }
        isDownloading = true
        model.downloadSearchResult(result)
    }

    private var statusIcon: String {
        switch result.statusCode {
        case 1: return "checkmark.circle"
        case 2: return "arrow.down.circle"
        case 3: return "xmark.circle"
        case 4: return "arrow.down.circle.badge.xmark"
        default: return "circle"
        }
    }
}

#Preview {
    NavigationStack {
        SearchView(model: IOSAppModel())
    }
}

#endif
