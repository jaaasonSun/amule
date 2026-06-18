#if canImport(UIKit)
import SwiftUI
import SharedModels
import SharedViews

struct DownloadsView: View {
    @ObservedObject var model: IOSAppModel
    var presentation: DownloadsViewPresentation = .phone
    var onShowConnection: () -> Void = {}

    @State private var selectedFilter: DownloadListFilter = .all
    @AppStorage("downloads.sort") private var selectedSortRaw = DownloadListSort.name.rawValue
    @AppStorage("downloads.sortAscending") private var sortAscending = true
    @State private var searchQuery = ""
    @State private var addLinksDraft = ""
    @State private var showAddLinksSheet = false
    @State private var suggestedRenameRequest: SuggestedRenameRequest?
    @AppStorage(FilenameCleanupPreferences.storageKey) private var filenameCleanupPrefixesRaw = "[]"

    private var filenameCleanupPrefixes: [String] {
        FilenameCleanupPreferences.decode(filenameCleanupPrefixesRaw)
    }

    private var selectedSort: DownloadListSort {
        DownloadListSort(rawValue: selectedSortRaw) ?? .name
    }

    private var selectedSortBinding: Binding<DownloadListSort> {
        Binding(
            get: { selectedSort },
            set: { selectedSortRaw = $0.rawValue }
        )
    }

    private var displayedDownloads: [DownloadItem] {
        DownloadListPresentation.displayedDownloads(
            model.downloads,
            filter: selectedFilter,
            query: searchQuery,
            sort: selectedSort,
            ascending: sortAscending
        )
    }

    private var completedDownloads: [DownloadItem] {
        model.downloads.filter(\.isCompletedLike)
    }

    var body: some View {
        downloadsList
            .listStyle(.plain)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    connectionStatusIndicator
                }

                if presentation == .phone {
                    phoneToolbarItems
                } else {
                    padToolbarItems
                }
            }
            .searchable(
                text: $searchQuery,
                placement: presentation == .pad ? .toolbar : .navigationBarDrawer(displayMode: .automatic),
                prompt: Text(searchPlaceholder)
            )
            .sheet(isPresented: $showAddLinksSheet) {
                AddLinksSheet(model: model, draft: $addLinksDraft)
            }
            .sheet(item: $suggestedRenameRequest) { request in
                RenameSuggestionSheet(model: model, request: request)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .task {
                if model.isSessionConnected {
                    model.refreshDownloads()
                }
            }
    }

    private var downloadsList: some View {
        List {
            if displayedDownloads.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: model.isSessionConnected ? selectedFilter.systemImage : "wifi.slash",
                    description: Text(emptyDescription)
                )
            } else {
                ForEach(displayedDownloads) { item in
                    NavigationLink {
                        DownloadDetailView(model: model, item: item)
                    } label: {
                        DownloadRow(item: item, filenameCleanupPrefixes: filenameCleanupPrefixes)
                    }
                    .contextMenu {
                        if let suggestion = item.meaningfulFilenameSuggestion(prefixes: filenameCleanupPrefixes) {
                            Button {
                                if let draft = FilenameSuggestionPresentation.renameDraft(from: suggestion, currentName: item.name) {
                                    suggestedRenameRequest = SuggestedRenameRequest(item: item, suggestion: draft)
                                }
                            } label: {
                                Label("Use Suggested Filename", systemImage: "wand.and.stars")
                            }
                            .disabled(!canRename(item))

                            Divider()
                        }

                        Button {
                            model.copyDownloadLinkToClipboard(item)
                        } label: {
                            Label("Copy Link", systemImage: "doc.on.doc")
                        }

                        Button {
                            model.shareDownloadLink(item)
                        } label: {
                            Label("Share Link", systemImage: "square.and.arrow.up")
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            model.removeDownload(item)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        if DownloadClassification.isPaused(item) || item.statusCode == 7 {
                            Button {
                                model.resumeDownload(item)
                            } label: {
                                Label("Resume", systemImage: "play.fill")
                            }
                        } else if DownloadClassification.isDownloading(item) {
                            Button {
                                model.pauseDownload(item)
                            } label: {
                                Label("Pause", systemImage: "pause.fill")
                            }
                        }
                    }
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var phoneToolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            filterMenu
            sortMenu
            addLinksButton

            Button {
                model.clearCompletedDownloads(completedDownloads)
            } label: {
                Label("Clear Completed", systemImage: "checkmark")
            }
            .disabled(completedDownloads.isEmpty || model.isBusy || !model.isSessionConnected)
        }
    }

    @ToolbarContentBuilder
    private var padToolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            filterMenu
            sortMenu
            addLinksButton

            Button {
                model.clearCompletedDownloads(completedDownloads)
            } label: {
                Label("Clear Completed", systemImage: "checkmark")
            }
            .disabled(completedDownloads.isEmpty || model.isBusy || !model.isSessionConnected)
        }
    }

    private var addLinksButton: some View {
        Button {
            showAddLinksSheet = true
        } label: {
            Label("Add Links", systemImage: "plus")
        }
        .disabled(!model.isSessionConnected || model.isBusy)
    }

    private var connectionStatusIndicator: some View {
        Button(action: onShowConnection) {
            Label(connectionStatusTitle, systemImage: connectionStatusSystemImage)
                .labelStyle(.iconOnly)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(connectionStatusColor)
        }
        .accessibilityLabel("Connection")
        .accessibilityValue(connectionStatusTitle)
    }

    private var connectionStatusTitle: String {
        if model.isSessionConnected {
            return L("Connected")
        }
        if model.isBusy {
            return L("Connecting")
        }
        return L("Disconnected")
    }

    private var connectionStatusSystemImage: String {
        if model.isSessionConnected {
            return "wifi"
        }
        if model.isBusy {
            return "arrow.triangle.2.circlepath"
        }
        return "wifi.slash"
    }

    private var connectionStatusColor: Color {
        if model.isSessionConnected {
            return .green
        }
        if model.isBusy {
            return .orange
        }
        return .secondary
    }

    private var filterMenu: some View {
        Menu {
            Text(LF("Showing %@", L(selectedFilter.title)))
                .foregroundStyle(.secondary)

            Picker("Filter", selection: $selectedFilter) {
                ForEach(DownloadListFilter.allCases) { filter in
                    Label("\(L(filter.title)) \(filterCount(for: filter))", systemImage: filter.systemImage)
                        .tag(filter)
                }
            }
        } label: {
            Label("Filter", systemImage: selectedFilter == .all ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                .labelStyle(.iconOnly)
                .foregroundStyle(selectedFilter == .all ? Color.primary : Color.accentColor)
        }
        .buttonStyle(.glass)
        .accessibilityLabel("Filter Downloads")
        .accessibilityValue(L(selectedFilter.title))
    }

    private var sortMenu: some View {
        Menu {
            Text(LF("Sorted by %@, %@", L(selectedSort.title), sortAscending ? L("ascending") : L("descending")))
                .foregroundStyle(.secondary)

            Picker("Sort By", selection: selectedSortBinding) {
                ForEach(DownloadListSort.allCases) { sort in
                    Text(L(sort.title)).tag(sort)
                }
            }

            Divider()

            Button {
                sortAscending.toggle()
            } label: {
                Label(sortAscending ? L("Ascending") : L("Descending"), systemImage: sortAscending ? "arrow.up" : "arrow.down")
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
                .labelStyle(.iconOnly)
                .foregroundStyle(selectedSort == .name && sortAscending ? Color.primary : Color.accentColor)
        }
        .buttonStyle(.glass)
        .accessibilityLabel("Sort Downloads")
        .accessibilityValue("\(L(selectedSort.title)), \(sortAscending ? L("ascending") : L("descending"))")
    }

    private var searchPlaceholder: String {
        selectedFilter == .all ? L("Search") : LF("Search %@", L(selectedFilter.title))
    }

    private var emptyTitle: String {
        if !model.isSessionConnected {
            return L("Not Connected")
        }
        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return L("No Matching Downloads")
        }
        return selectedFilter == .all ? L("No Downloads") : LF("No %@ Downloads", L(selectedFilter.title))
    }

    private var emptyDescription: String {
        if !model.isSessionConnected {
            return L("Connect to an aMule server to see downloads.")
        }
        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return L("Try a different search or download filter.")
        }
        return selectedFilter == .all
            ? L("Downloads will appear here when active.")
            : L("Switch to All to see the full download queue.")
    }

}

#Preview("Disconnected") {
    NavigationStack {
        DownloadsView(model: IOSAppModel.previewDisconnected())
    }
}

#Preview("Empty Connected") {
    NavigationStack {
        DownloadsView(model: IOSAppModel.previewConnectedEmpty())
    }
}

#Preview("Active Downloads") {
    NavigationStack {
        DownloadsView(model: IOSAppModel.previewWithDownloads())
    }
}

#Preview("Completed Downloads") {
    NavigationStack {
        DownloadsView(model: IOSAppModel.previewWithCompletedDownloads())
    }
}

#Preview("iPad") {
    NavigationStack {
        DownloadsView(model: IOSAppModel.previewWithDownloads(), presentation: .pad)
    }
}

#endif
