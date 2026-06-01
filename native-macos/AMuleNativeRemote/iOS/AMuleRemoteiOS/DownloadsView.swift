#if canImport(UIKit)
import SwiftUI
import AMuleRemoteIOSShared
import SharedViews

struct DownloadsView: View {
    @ObservedObject var model: IOSAppModel
    var presentation: DownloadsViewPresentation = .phone
    var onShowConnection: () -> Void = {}
    var onShowSearch: () -> Void = {}
    var onShowServers: () -> Void = {}
    var onShowSettings: () -> Void = {}

    @State private var selectedFilter: DownloadListFilter = .all
    @AppStorage("downloads.sort") private var selectedSortRaw = DownloadListSort.name.rawValue
    @AppStorage("downloads.sortAscending") private var sortAscending = true
    @State private var searchQuery = ""
    @State private var addLinksDraft = ""
    @State private var showAddLinksSheet = false
    @State private var suggestedRenameRequest: SuggestedRenameRequest?

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

    var body: some View {
        downloadsList
            .listStyle(.plain)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    connectionStatusIndicator
                }

                if presentation == .phone {
                    phoneToolbarItems
                    phoneBottomToolbarItems
                } else {
                    padToolbarItems
                }
            }
            .if(presentation == .pad) { view in
                view.searchable(text: $searchQuery, placement: .toolbar, prompt: Text(searchPlaceholder))
            }
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
                        DownloadRow(item: item)
                    }
                    .contextMenu {
                        if let suggestion = item.meaningfulNameEncodingSuggestion {
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
            Button(action: onShowSearch) {
                Label("Search", systemImage: "magnifyingglass")
            }

            Button(action: onShowServers) {
                Label("Servers", systemImage: "server.rack")
            }

            Button(action: onShowSettings) {
                Label("Settings", systemImage: "gearshape")
            }

            addLinksButton
        }
    }

    @ToolbarContentBuilder
    private var phoneBottomToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .bottomBar) {
            filterMenu
        }

        ToolbarSpacer(.fixed, placement: .bottomBar)

        ToolbarItem(placement: .bottomBar) {
            bottomSearchField
        }

        ToolbarSpacer(.fixed, placement: .bottomBar)

        ToolbarItem(placement: .bottomBar) {
            sortMenu
        }
    }

    @ToolbarContentBuilder
    private var padToolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            filterMenu
            sortMenu
            addLinksButton
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

    private var bottomSearchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(searchPlaceholder, text: $searchQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .lineLimit(1)

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear Search")
            }
        }
        .font(.body)
        .padding(.horizontal)
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

#Preview {
    NavigationStack {
        DownloadsView(model: IOSAppModel())
    }
}

private extension View {
    @ViewBuilder
    func `if`<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
#endif
