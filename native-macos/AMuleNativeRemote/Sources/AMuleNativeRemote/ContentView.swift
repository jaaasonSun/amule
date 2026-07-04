import SwiftUI
import AppKit
import SharedViews
import SharedModels
import SharedServices

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @AppStorage("amule.ui.alwaysShowSuggestedFilename") private var alwaysShowSuggestedFilename = false
    @AppStorage(FilenameCleanupPreferences.storageKey) private var filenameCleanupPrefixesRaw = "[]"

    private enum DownloadSidebarFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case downloading = "Downloading"
        case pending = "Pending"
        case paused = "Paused"
        case completed = "Completed"

        var id: String { rawValue }
        var localizedTitle: String { L(rawValue) }

        var symbolName: String {
            switch self {
            case .all: return "tray.full"
            case .downloading: return "arrow.down"
            case .pending: return "clock"
            case .paused: return "pause"
            case .completed: return "checkmark"
            }
        }
    }

    private enum SidebarSelection: Hashable {
        case downloads(DownloadSidebarFilter)
        case search
    }

    @State private var showLoginSheet = false
    @State private var showAddLinksSheet = false
    @State private var showKadSheet = false
    @State private var addLinksDraft = ""
    @State private var kadNodesURL = "http://upd.emule-security.org/nodes.dat"
    @State private var isRefreshingKadStatus = false
    @State private var selectedSidebarSelection: SidebarSelection = .downloads(.all)

    @State private var downloadSortOrder = [KeyPathComparator(\DownloadItem.name, order: .forward)]
    @State private var downloadNameFilterQuery = ""
    @State private var displayedDownloads: [DownloadItem] = []
    @State private var selectedDownloadIDs: Set<DownloadItem.ID> = []
    @State private var showRemoveConfirmation = false
    @State private var pendingRemoveDownloadIDs: Set<DownloadItem.ID> = []

    var body: some View {
        presentedBody
    }

    private var sidebarSelectionBinding: Binding<SidebarSelection?> {
        Binding<SidebarSelection?>(
            get: { selectedSidebarSelection },
            set: { newValue in
                guard let newValue else { return }
                var tx = Transaction()
                tx.animation = nil
                tx.disablesAnimations = true
                withTransaction(tx) {
                    selectedSidebarSelection = newValue
                }
            }
        )
    }

    private var selectedDownload: DownloadItem? {
        displayedDownloads.first(where: { selectedDownloadIDs.contains($0.id) })
    }

    private var selectedDownloads: [DownloadItem] {
        displayedDownloads.filter { selectedDownloadIDs.contains($0.id) }
    }

    private var completedDownloads: [DownloadItem] {
        model.downloads
            .filter(DownloadClassification.isCompleted)
            .sorted {
                if $0.lastSeenComplete != $1.lastSeenComplete {
                    return $0.lastSeenComplete > $1.lastSeenComplete
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private var filenameCleanupPrefixes: [String] {
        FilenameCleanupPreferences.decode(filenameCleanupPrefixesRaw)
    }

    private var activeSidebarFilter: DownloadSidebarFilter {
        if case .downloads(let filter) = selectedSidebarSelection {
            return filter
        }
        return .all
    }

    private var downloadsPageToolbarTitle: String {
        switch activeSidebarFilter {
        case .all:
            return L("Downloads")
        default:
            return activeSidebarFilter.localizedTitle
        }
    }

    private var windowTitleText: String {
        switch selectedSidebarSelection {
        case .downloads:
            return downloadsPageToolbarTitle
        case .search:
            return L("Search")
        }
    }

    private var baseBody: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                List(selection: sidebarSelectionBinding) {
                    ForEach(DownloadSidebarFilter.allCases) { filter in
                        Label(filter.localizedTitle, systemImage: filter.symbolName)
                            .badge(downloadFilterCount(for: filter))
                            .tag(SidebarSelection.downloads(filter))
                    }

                    Label("Search", systemImage: "magnifyingglass")
                        .lineLimit(1)
                        .badge(searchSidebarBadgeText)
                        .tag(SidebarSelection.search)
                }
                .listStyle(.sidebar)
                .navigationSplitViewColumnWidth(min: 150, ideal: 180, max: 220)
            } detail: {
                VStack(spacing: 0) {
                    Group {
                        switch selectedSidebarSelection {
                        case .downloads:
                            downloadsPanel
                        case .search:
                            SearchPanel()
                        }
                    }
                    .padding(.top, 0)
                    if !model.lastError.isEmpty {
                        Divider()
                        Text(model.lastError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                    }
                    Divider()
                    MainFooterBar(showLoginSheet: $showLoginSheet, showKadSheet: $showKadSheet)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .navigationTitle(windowTitleText)
        }
    }

    private var downloadsPanel: some View {
        DownloadsPanel(
            displayedDownloads: displayedDownloads,
            selectedDownloadIDs: $selectedDownloadIDs,
            sortOrder: $downloadSortOrder,
            nameFilterQuery: $downloadNameFilterQuery,
            alwaysShowSuggestedFilename: alwaysShowSuggestedFilename,
            filenameCleanupPrefixes: filenameCleanupPrefixes,
            canRenameDownload: canRenameDownload,
            showDetails: { openDownloadDetailsWindow(for: $0, refreshSources: false) },
            useSuggestedFilename: { item, suggestion in
                model.requestRenameSuggestion(item, suggestion: suggestion)
                openDownloadDetailsWindow(for: item, refreshSources: false)
            },
            copyED2KLink: model.copyDownloadLinkToClipboard,
            pauseDownload: model.pauseDownload,
            resumeDownload: model.resumeDownload,
            removeDownload: { item in
                pendingRemoveDownloadIDs = [item.id]
                showRemoveConfirmation = true
            },
            setPriority: model.setDownloadPriority,
            isBusy: model.isBusy
        )
    }

    private var styledBody: some View {
        baseBody
            .frame(minWidth: 760, minHeight: 420)
    }

    private var lifecycleBody: some View {
        styledBody
            .onAppear {
                model.setDownloadAutoRefreshEnabled(true)
            }
            .onDisappear {
                model.setDownloadAutoRefreshEnabled(false)
            }
            .task {
                await model.refreshBridgeCapabilities(logOutput: false, suppressErrors: true)
                model.startAutoRefresh()
                await model.refreshStatus(logOutput: false, suppressErrors: true)
                model.refreshDownloads()
                model.refreshServers()
                refreshDisplayedDownloads()
                showLoginSheet = !model.isSessionConnected
                model.flushIncomingLinksIfAny()
            }
    }

    private var observedBody: some View {
        lifecycleBody
            .onChange(of: model.isSessionConnected) { _, connected in
                if connected {
                    showLoginSheet = false
                    model.flushIncomingLinksIfAny()
                }
            }
            .onChange(of: model.downloads) { refreshDisplayedDownloads() }
            .onChange(of: downloadSortOrder) { refreshDisplayedDownloads() }
            .onChange(of: downloadNameFilterQuery) { refreshDisplayedDownloads() }
            .onChange(of: selectedSidebarSelection) { refreshDisplayedDownloads() }
            .onChange(of: selectedDownloadIDs) {
                model.selectedDownloadID = selectedDownload?.id
                if let selectedDownload {
                    model.refreshDownloadSources(for: selectedDownload)
                }
            }
            .onChange(of: model.addLinksPanelRequestID) { showAddLinksSheet = true }
            .onReceive(NotificationCenter.default.publisher(for: .amuleIncomingLinksDidChange)) { _ in
                model.flushIncomingLinksIfAny()
            }
    }

    private var presentedBody: some View {
        observedBody
            .animation(.none, value: selectedSidebarSelection)
            .sheet(isPresented: $showLoginSheet) {
                presentationSheet(ConnectionSheet(isPresented: $showLoginSheet))
            }
            .sheet(isPresented: $showAddLinksSheet) {
                presentationSheet(AddLinksSheetView(draft: $addLinksDraft, isPresented: $showAddLinksSheet))
            }
            .sheet(isPresented: $showKadSheet) {
                presentationSheet(KadSheet(isPresented: $showKadSheet, nodesURL: $kadNodesURL, isRefreshingStatus: $isRefreshingKadStatus))
            }
            .toolbar {
                if case .downloads = selectedSidebarSelection {
                    MainToolbar(
                        selectedDownload: selectedDownload,
                        selectedDownloads: selectedDownloads,
                        selectedDownloadIDs: selectedDownloadIDs,
                        completedDownloads: completedDownloads,
                        isBusy: model.isBusy,
                        showDetails: presentSelectedDownloadDetails,
                        resumeDownloads: model.resumeDownloads,
                        pauseDownloads: model.pauseDownloads,
                        requestRemoveDownloads: { ids in
                            pendingRemoveDownloadIDs = ids
                            showRemoveConfirmation = !pendingRemoveDownloadIDs.isEmpty
                        },
                        showAddLinks: { showAddLinksSheet = true },
                        clearCompleted: model.clearCompletedDownloads
                    )
                }
            }
            .alert("Remove Selected Downloads?", isPresented: $showRemoveConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) { removePendingDownloads() }
            } message: {
                Text(LF("This will remove %lld selected download(s). This action cannot be undone.", Int64(pendingRemoveDownloadIDs.count)))
            }
            .overlay {
                if model.showHUD {
                    AddLinksHUD(message: model.hudMessage)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
    }

    @ViewBuilder
    private func presentationSheet<Content: View>(_ content: Content) -> some View {
        if #available(macOS 13.3, *) {
            content.presentationBackground(.clear)
        } else {
            content
        }
    }

    private var searchSidebarBadgeText: String {
        if model.isSearchInProgress { return "…" }
        return String(model.searchResults.count)
    }

    private func downloadFilterCount(for filter: DownloadSidebarFilter) -> Int {
        switch filter {
        case .all: return model.downloads.count
        case .downloading: return model.downloads.filter(DownloadClassification.isDownloading).count
        case .pending: return model.downloads.filter(DownloadClassification.isPending).count
        case .paused: return model.downloads.filter(DownloadClassification.isPaused).count
        case .completed: return model.downloads.filter(DownloadClassification.isCompleted).count
        }
    }

    private func filteredDownloads(_ items: [DownloadItem], for filter: DownloadSidebarFilter) -> [DownloadItem] {
        switch filter {
        case .all: return items
        case .downloading: return items.filter(DownloadClassification.isDownloading)
        case .pending: return items.filter(DownloadClassification.isPending)
        case .paused: return items.filter(DownloadClassification.isPaused)
        case .completed: return items.filter(DownloadClassification.isCompleted)
        }
    }

    private func refreshDisplayedDownloads() {
        let scoped = filteredDownloads(model.downloads, for: activeSidebarFilter)
        let filtered = filterDownloadsByName(scoped, query: downloadNameFilterQuery)
        displayedDownloads = filtered.sorted(using: downloadSortOrder)
        selectedDownloadIDs = selectedDownloadIDs.filter { id in
            displayedDownloads.contains(where: { $0.id == id })
        }
        model.selectedDownloadID = selectedDownload?.id
    }

    private func filterDownloadsByName(_ items: [DownloadItem], query: String) -> [DownloadItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        return items.filter { matchesDownloadNameFilter($0.name, query: trimmed) }
    }

    private func matchesDownloadNameFilter(_ name: String, query: String) -> Bool {
        let haystack = normalizedFuzzySearchString(name)
        let compactHaystack = haystack.replacingOccurrences(of: " ", with: "")
        let tokens = normalizedFuzzySearchString(query)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return true }
        return tokens.allSatisfy {
            haystack.contains($0) || compactHaystack.contains($0)
                || fuzzySubsequenceMatch(needle: $0, in: haystack)
                || fuzzySubsequenceMatch(needle: $0, in: compactHaystack)
        }
    }

    private func normalizedFuzzySearchString(_ raw: String) -> String {
        let folded = raw.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
        let mapped = folded.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) || CharacterSet.nonBaseCharacters.contains(scalar) {
                return Character(scalar)
            }
            return " "
        }
        return String(mapped)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func fuzzySubsequenceMatch(needle: String, in haystack: String) -> Bool {
        guard !needle.isEmpty else { return true }
        if needle.count == 1 { return haystack.contains(needle) }
        var haystackIndex = haystack.startIndex
        for needleChar in needle {
            var found = false
            while haystackIndex < haystack.endIndex {
                if haystack[haystackIndex] == needleChar {
                    found = true
                    haystack.formIndex(after: &haystackIndex)
                    break
                }
                haystack.formIndex(after: &haystackIndex)
            }
            if !found { return false }
        }
        return true
    }

    private func removePendingDownloads() {
        let items = displayedDownloads.filter { pendingRemoveDownloadIDs.contains($0.id) }
        pendingRemoveDownloadIDs.removeAll()
        model.removeDownloads(items)
    }

    private func presentSelectedDownloadDetails() {
        openDownloadDetailsWindow(for: selectedDownload, refreshSources: true)
    }

    private func openDownloadDetailsWindow(for item: DownloadItem?, refreshSources: Bool) {
        if let item {
            selectedDownloadIDs = [item.id]
            model.selectedDownloadID = item.id
            if refreshSources {
                model.refreshDownloadSources(for: item)
            }
        } else {
            model.selectedDownloadID = selectedDownload?.id
        }
        openWindow(id: "download-details-window")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func canRenameDownload(_ item: DownloadItem) -> Bool {
        !item.isCompletedLike
    }
}

#if DEBUG
#Preview("Disconnected") {
    ContentView()
        .environmentObject(AppModel.previewDisconnected())
}

#Preview("Connected with Downloads") {
    ContentView()
        .environmentObject(AppModel.previewWithDownloads())
}
#endif
