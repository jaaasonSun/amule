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
    @AppStorage("amule.ui.showCategoriesPage") private var showCategoriesPage = true
    @AppStorage("amule.ui.showFriendsPage") private var showFriendsPage = true
    @AppStorage("amule.ui.showUploadsPage") private var showUploadsPage = true
    @AppStorage(DownloadTableSortPersistence.sortOrderDefaultsKey)
    private var downloadSortOrderRaw = DownloadTableSortPersistence.defaultRawValue

    enum DownloadStatusFilter: String, CaseIterable, Identifiable {
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

    @State private var showLoginSheet = false
    @State private var showAddLinksSheet = false
    @State private var showKadSheet = false
    @State private var addLinksDraft = ""
    @State private var kadNodesURL = "http://upd.emule-security.org/nodes.dat"
    @State private var isRefreshingKadStatus = false
    @State private var selectedDownloadStatusFilter = DownloadStatusFilter.all

    @State private var downloadNameFilterQuery = ""
    @State private var displayedDownloads: [DownloadItem] = []
    @State private var selectedDownloadIDs: Set<DownloadItem.ID> = []
    @State private var showRemoveConfirmation = false
    @State private var pendingRemoveDownloadIDs: Set<DownloadItem.ID> = []

    var body: some View {
        presentedBody
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

    private var windowTitleText: String {
        if selectedDownloadStatusFilter == .all {
            return L("Downloads")
        }
        return "\(L("Downloads")) — \(selectedDownloadStatusFilter.localizedTitle)"
    }

    private var baseBody: some View {
        VStack(spacing: 0) {
            downloadsPanel
                .padding(.top, 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .layoutPriority(1)

            if !model.lastError.isEmpty {
                Divider()
                GlobalErrorBanner(
                    message: model.lastError,
                    activePaneTitle: windowTitleText,
                    dismiss: { model.lastError = "" }
                )
            }

            Divider()
            MainWindowStatusFooter(
                summary: NetworkStatusSummary(status: model.status),
                status: model.status,
                isSessionConnected: model.isSessionConnected,
                openConnectionSettings: {
                    model.requestConnectionSheet()
                },
                openED2KServersWindow: {
                    openWindow(id: "servers-window")
                    NSApp.activate(ignoringOtherApps: true)
                },
                openKadServersWindow: {
                    openWindow(id: "servers-window")
                    NSApp.activate(ignoringOtherApps: true)
                },
                openDownloadStatisticsWindow: {
                    openWindow(id: "statistics-window")
                    NSApp.activate(ignoringOtherApps: true)
                },
                openUploadStatisticsWindow: {
                    openWindow(id: "statistics-window")
                    NSApp.activate(ignoringOtherApps: true)
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle(windowTitleText)
    }

    private var downloadsPanel: some View {
        DownloadsPanel(
            displayedDownloads: displayedDownloads,
            selectedDownloadIDs: $selectedDownloadIDs,
            sortOrder: downloadSortOrderBinding,
            nameFilterQuery: $downloadNameFilterQuery,
            alwaysShowSuggestedFilename: alwaysShowSuggestedFilename,
            filenameCleanupPrefixes: filenameCleanupPrefixes,
            canRenameDownload: canRenameDownload,
            showDetails: { openDownloadDetailsWindow(for: $0) },
            useSuggestedFilename: { item, suggestion in
                model.requestRenameSuggestion(item, suggestion: suggestion)
                openDownloadDetailsWindow(for: item)
            },
            copyED2KLink: model.copyDownloadLinkToClipboard,
            pauseDownload: model.pauseDownload,
            resumeDownload: model.resumeDownload,
            stopDownload: model.stopDownload,
            removeDownload: { item in
                pendingRemoveDownloadIDs = [item.id]
                showRemoveConfirmation = true
            },
            setPriority: model.setDownloadPriority,
            setCategory: model.setDownloadCategory,
            categories: model.categories.map { category in
                DownloadCategoryMenuItem(id: category.id, title: category.title)
            },
            isDownloadStopSupported: model.isBridgeOpSupported("download-stop"),
            isDownloadSetCategorySupported: model.isBridgeOpSupported("download-set-category"),
            isDownloadSetPrioritySupported: model.isBridgeOpSupported("priority"),
            isBusy: model.isBusy
        )
    }

    private var downloadSortOrder: [KeyPathComparator<DownloadItem>] {
        DownloadTableSortPersistence.comparators(from: downloadSortOrderRaw)
    }

    private var downloadSortOrderBinding: Binding<[KeyPathComparator<DownloadItem>]> {
        Binding(
            get: { downloadSortOrder },
            set: { downloadSortOrderRaw = DownloadTableSortPersistence.rawValue(for: $0) }
        )
    }

    private var lifecycleBody: some View {
        baseBody
            .frame(minWidth: 760, minHeight: 420)
            .onAppear {
                model.setDownloadAutoRefreshEnabled(true)
            }
            .onDisappear {
                model.setDownloadAutoRefreshEnabled(false)
            }
            .task {
                await model.refreshBridgeCapabilitiesAndPreloadCategories(logOutput: false, suppressErrors: true)
                await model.refreshStatus(logOutput: false, suppressErrors: true)
                model.startAutoRefresh()
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
            .onChange(of: downloadSortOrderRaw) { refreshDisplayedDownloads() }
            .onChange(of: downloadNameFilterQuery) { refreshDisplayedDownloads() }
            .onChange(of: selectedDownloadStatusFilter) { refreshDisplayedDownloads() }
            .onChange(of: selectedDownloadIDs) {
                if let selectedDownload {
                    model.selectedDownloadID = selectedDownload.id
                } else {
                    model.selectedDownloadID = nil
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .amulePauseSelectedDownloads)) { _ in
                model.pauseDownloads(selectedDownloads)
            }
            .onReceive(NotificationCenter.default.publisher(for: .amuleResumeSelectedDownloads)) { _ in
                model.resumeDownloads(selectedDownloads)
            }
            .onReceive(NotificationCenter.default.publisher(for: .amuleRemoveSelectedDownloads)) { _ in
                pendingRemoveDownloadIDs = selectedDownloadIDs
                showRemoveConfirmation = !pendingRemoveDownloadIDs.isEmpty
            }
            .onChange(of: model.addLinksPanelRequestID) { showAddLinksSheet = true }
            .onChange(of: model.connectionSheetRequestID) { showLoginSheet = true }
            .onReceive(NotificationCenter.default.publisher(for: .amuleIncomingLinksDidChange)) { _ in
                model.flushIncomingLinksIfAny()
            }
    }

    private var presentedBody: some View {
        observedBody
            .animation(.none, value: selectedDownloadStatusFilter)
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
                MainToolbar(
                    selectedDownloadStatusFilter: $selectedDownloadStatusFilter,
                    downloadStatusFilterCounts: downloadStatusFilterCounts,
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
                    showSearchNetwork: {
                        openWindow(id: "search-window")
                        NSApp.activate(ignoringOtherApps: true)
                    },
                    clearCompleted: model.clearCompletedDownloads
                )
            }
            .alert(L("Remove Selected Downloads?"), isPresented: $showRemoveConfirmation) {
                Button(L("Cancel"), role: .cancel) {}
                Button(L("Remove"), role: .destructive) { removePendingDownloads() }
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
        content
    }

    private var downloadStatusFilterCounts: [DownloadStatusFilter: Int] {
        Dictionary(uniqueKeysWithValues: DownloadStatusFilter.allCases.map { filter in
            (filter, downloadFilterCount(for: filter))
        })
    }

    private func downloadFilterCount(for filter: DownloadStatusFilter) -> Int {
        switch filter {
        case .all: return model.downloads.count
        case .downloading: return model.downloads.filter(DownloadClassification.isDownloading).count
        case .pending: return model.downloads.filter(DownloadClassification.isPending).count
        case .paused: return model.downloads.filter(DownloadClassification.isPaused).count
        case .completed: return model.downloads.filter(DownloadClassification.isCompleted).count
        }
    }

    private func filteredDownloads(_ items: [DownloadItem], for filter: DownloadStatusFilter) -> [DownloadItem] {
        switch filter {
        case .all: return items
        case .downloading: return items.filter(DownloadClassification.isDownloading)
        case .pending: return items.filter(DownloadClassification.isPending)
        case .paused: return items.filter(DownloadClassification.isPaused)
        case .completed: return items.filter(DownloadClassification.isCompleted)
        }
    }

    private func refreshDisplayedDownloads() {
        let scoped = filteredDownloads(model.downloads, for: selectedDownloadStatusFilter)
        let filtered = filterDownloadsByName(scoped, query: downloadNameFilterQuery)
        displayedDownloads = filtered.sorted(using: downloadSortOrder)
        selectedDownloadIDs = selectedDownloadIDs.filter { id in
            displayedDownloads.contains(where: { $0.id == id })
        }
        if let selectedDownload {
            model.selectedDownloadID = selectedDownload.id
        } else {
            model.selectedDownloadID = nil
        }
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
        openDownloadDetailsWindow(for: selectedDownload)
    }

    private func openDownloadDetailsWindow(for item: DownloadItem?) {
        if let item {
            selectedDownloadIDs = [item.id]
            model.selectedDownloadID = item.id
        } else {
            model.selectedDownloadID = nil
        }
        openWindow(id: "download-details-window")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func canRenameDownload(_ item: DownloadItem) -> Bool {
        !item.isCompletedLike
    }
}

private struct GlobalErrorBanner: View {
    let message: String
    let activePaneTitle: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(activePaneTitle)
                    .font(.caption.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Button(L("Dismiss")) {
                dismiss()
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(activePaneTitle)
        .accessibilityValue(message)
        .accessibilityHint(L("Dismiss"))
        .onExitCommand(perform: dismiss)
    }
}

private struct MainWindowStatusFooter: View {
    let summary: NetworkStatusSummary
    let status: StatusSnapshot
    let isSessionConnected: Bool
    let openConnectionSettings: () -> Void
    let openED2KServersWindow: () -> Void
    let openKadServersWindow: () -> Void
    let openDownloadStatisticsWindow: () -> Void
    let openUploadStatisticsWindow: () -> Void

    private var sessionStatusText: String {
        isSessionConnected || status.connected ? L("Connected") : L("Disconnected")
    }

    private var ed2kStatusText: String {
        localizedED2KConnectionStatusText(for: summary.ed2k)
    }

    private var kadStatusText: String {
        localizedConnectionStatusText(for: summary.kad)
    }

    private var sessionState: SharedViews.ConnectionState {
        isSessionConnected || status.connected ? .connected : .disconnected
    }

    private var kadState: SharedViews.ConnectionState {
        ConnectionStateParser.parse(summary.kad)
    }

    var body: some View {
        HStack(spacing: 12) {
            FooterControlButton(
                action: openConnectionSettings,
                accessibilityLabel: L("Open Connection Settings"),
                accessibilityValue: sessionStatusText,
                accessibilityHint: L("Opens the connection settings sheet.")
            ) {
                Label("aMule", systemImage: ConnectionStateSymbol.symbolName(for: sessionState))
                    .labelStyle(.titleAndIcon)
            }
            footerDivider
            FooterControlButton(
                action: openED2KServersWindow,
                accessibilityLabel: L("Open Servers"),
                accessibilityValue: ed2kStatusText,
                accessibilityHint: L("Opens the Servers window.")
            ) {
                statusSegment(title: L("eD2K:"), value: compactED2kBadgeValue(summary.ed2k))
            }
            footerDivider
            FooterControlButton(
                action: openKadServersWindow,
                accessibilityLabel: L("Open Servers"),
                accessibilityValue: kadStatusText,
                accessibilityHint: L("Opens the Servers window.")
            ) {
                Label("Kad", systemImage: ConnectionStateSymbol.symbolName(for: kadState))
                    .labelStyle(.titleAndIcon)
            }

            Spacer(minLength: 12)

            FooterControlButton(
                action: openDownloadStatisticsWindow,
                accessibilityLabel: L("Open Statistics"),
                accessibilityValue: status.downloadSpeed,
                accessibilityHint: L("Opens the Statistics window.")
            ) {
                MetricChipView(title: L("Download"), value: status.downloadSpeed)
            }
            FooterControlButton(
                action: openUploadStatisticsWindow,
                accessibilityLabel: L("Open Statistics"),
                accessibilityValue: status.uploadSpeed,
                accessibilityHint: L("Opens the Statistics window.")
            ) {
                MetricChipView(title: L("Upload"), value: status.uploadSpeed)
            }
        }
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var footerDivider: some View {
        Divider()
            .frame(height: 14)
    }

    private func statusSegment(title: String, value: String) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? L("Unknown") : value)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

private struct FooterControlButton<Label: View>: View {
    let action: () -> Void
    let accessibilityLabel: String
    let accessibilityValue: String
    let accessibilityHint: String
    @ViewBuilder let label: () -> Label

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            label()
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .contentShape(Capsule())
        }
        .buttonStyle(FooterControlButtonStyle(isHovering: isHovering))
        .onHover { isHovering = $0 }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(normalizedAccessibilityValue)
        .accessibilityHint(accessibilityHint)
    }

    private var normalizedAccessibilityValue: String {
        let trimmed = accessibilityValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L("Unknown") : trimmed
    }
}

private struct FooterControlButtonStyle: ButtonStyle {
    let isHovering: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                Capsule()
                    .fill(backgroundStyle(isPressed: configuration.isPressed))
            }
            .foregroundStyle(configuration.isPressed ? .primary : .secondary)
    }

    private func backgroundStyle(isPressed: Bool) -> Color {
        if isPressed {
            return Color(nsColor: .selectedControlColor).opacity(0.22)
        }
        if isHovering {
            return Color(nsColor: .separatorColor).opacity(0.22)
        }
        return .clear
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
