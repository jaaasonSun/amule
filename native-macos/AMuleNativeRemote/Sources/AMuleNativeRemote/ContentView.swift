import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    private enum MainTab: String, CaseIterable {
        case search = "Search"
        case downloads = "Downloads"
        case servers = "Servers"
    }

    private enum DiagnosticsTab: String, CaseIterable {
        case log = "Log"
        case downloads = "Raw DL"
        case sources = "Raw Src"
        case search = "Raw Search"
        case servers = "Raw Servers"
    }

    private static let plainPortFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.usesGroupingSeparator = false
        formatter.allowsFloats = false
        return formatter
    }()

    @State private var selectedTab: MainTab = .downloads

    @State private var showLoginSheet = false
    @State private var showDiagnosticsSheet = false
    @State private var showDownloadDetailsSheet = false
    @State private var showAddLinksSheet = false
    @State private var showCompletedDownloadsSheet = false
    @State private var diagnosticsTab: DiagnosticsTab = .log
    @State private var addLinksDraft: String = ""

    @State private var searchSortOrder = [KeyPathComparator(\SearchResult.index, order: .forward)]
    @State private var displayedSearchResults: [SearchResult] = []

    @State private var downloadSortOrder = [KeyPathComparator(\DownloadItem.name, order: .forward)]
    @State private var displayedDownloads: [DownloadItem] = []
    @State private var sourceSortOrder = [KeyPathComparator(\DownloadSourceItem.clientName, order: .forward)]
    @State private var selectedDownloadIDs: Set<DownloadItem.ID> = []
    @State private var downloadRenameDraft: String = ""
    @State private var isEditingDownloadName = false
    @State private var footerDetailsExpanded = false
    @State private var showEd2kStatusPopover = false
    @State private var showRemoveConfirmation = false
    @State private var pendingRemoveDownloadIDs: Set<DownloadItem.ID> = []
    @State private var serverSortOrder = [KeyPathComparator(\ServerItem.name, order: .forward)]
    @State private var displayedServers: [ServerItem] = []
    @State private var selectedServerID: ServerItem.ID? = nil

    private var selectedDownload: DownloadItem? {
        displayedDownloads.first(where: { selectedDownloadIDs.contains($0.id) })
    }

    private var selectedDownloads: [DownloadItem] {
        displayedDownloads.filter { selectedDownloadIDs.contains($0.id) }
    }

    private var selectedServer: ServerItem? {
        guard let selectedServerID else { return nil }
        return displayedServers.first(where: { $0.id == selectedServerID })
    }

    private var selectedDownloadSources: [DownloadSourceItem] {
        model.sources(for: selectedDownload).sorted(using: sourceSortOrder)
    }

    private var completedDownloads: [DownloadItem] {
        model.downloads
            .filter { isCompletedDownload($0) }
            .sorted {
                if $0.lastSeenComplete != $1.lastSeenComplete {
                    return $0.lastSeenComplete > $1.lastSeenComplete
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private var completedDownloadsContentHeight: CGFloat {
        let rowHeight: CGFloat = 32
        let rows = CGFloat(min(max(completedDownloads.count, 1), 10))
        return rows * rowHeight + 4
    }

    var body: some View {
        configuredBody
    }

    private var baseBody: some View {
        VStack(spacing: 6) {
            downloadsPanel
                .padding(.top, 0)
            Divider()
            footerStatusBar
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            if !model.lastError.isEmpty {
                Text(model.lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var configuredBody: some View {
        presentedBody
    }

    private var styledBody: some View {
        baseBody
            .frame(minWidth: 560, minHeight: 420)
            .background(
                GlassEffectBackground(material: .underWindowBackground)
                    .ignoresSafeArea()
            )
            .background(
                WindowAppearanceConfigurator(
                    hideTitle: true,
                    transparentTitlebar: true,
                    fullSizeContentView: true,
                    toolbarStyle: .automatic,
                    showsToolbarBaselineSeparator: false,
                    allowsToolbarCustomization: false,
                    autosavesToolbarConfiguration: false,
                    makeWindowTransparent: true,
                    ensureToolbarWhenTransparentTitlebar: false,
                    toolbarTopGradientOpacity: 0.52
                )
            )
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
                model.ensurePreferredBridgePath()
                model.startAutoRefresh()
                await model.refreshStatus(logOutput: false, suppressErrors: true)
                model.refreshDownloads()
                model.refreshServers()
                refreshDisplayedSearchResults()
                refreshDisplayedDownloads()
                refreshDisplayedServers()
                showLoginSheet = !model.isSessionConnected
            }
    }

    private var observedBody: some View {
        lifecycleBody
            .onChange(of: model.isSessionConnected) { _, connected in
                if connected {
                    showLoginSheet = false
                }
            }
            .onChange(of: model.downloads) {
                refreshDisplayedDownloads()
            }
            .onChange(of: model.searchResults) {
                refreshDisplayedSearchResults()
            }
            .onChange(of: searchSortOrder) {
                refreshDisplayedSearchResults()
            }
            .onChange(of: downloadSortOrder) {
                refreshDisplayedDownloads()
            }
            .onChange(of: selectedDownloadIDs) {
                syncSelectedDownloadDraft()
                isEditingDownloadName = false
                if selectedDownload == nil {
                    showDownloadDetailsSheet = false
                } else if showDownloadDetailsSheet, let selectedDownload {
                    model.refreshDownloadSources(for: selectedDownload)
                }
            }
            .onChange(of: model.servers) {
                refreshDisplayedServers()
            }
            .onChange(of: serverSortOrder) {
                refreshDisplayedServers()
            }
            .onChange(of: model.addLinksPanelRequestID) {
                showAddLinksSheet = true
            }
    }

    private var presentedBody: some View {
        observedBody
            .sheet(isPresented: $showLoginSheet) {
                if #available(macOS 13.3, *) {
                    loginSheet
                        .presentationBackground(.clear)
                } else {
                    loginSheet
                }
            }
            .sheet(isPresented: $showDownloadDetailsSheet) {
                if #available(macOS 13.3, *) {
                    downloadDetailsSheet
                        .presentationBackground(.clear)
                } else {
                    downloadDetailsSheet
                }
            }
            .sheet(isPresented: $showAddLinksSheet) {
                if #available(macOS 13.3, *) {
                    addLinksSheet
                        .presentationBackground(.clear)
                } else {
                    addLinksSheet
                }
            }
            .toolbar { downloadsToolbar }
            .alert("Remove Selected Downloads?", isPresented: $showRemoveConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    removePendingDownloads()
                }
            } message: {
                Text("This will remove \(pendingRemoveDownloadIDs.count) selected download(s). This action cannot be undone.")
            }
            .overlay {
                if model.showHUD {
                    AddLinksHUD(message: model.hudMessage)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
    }

    @ToolbarContentBuilder
    private var downloadsToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            ControlGroup {
                Button {
                    syncSelectedDownloadDraft()
                    showDownloadDetailsSheet = true
                } label: {
                    Label("Details", systemImage: "info.circle")
                }
                .help("Show Download Details")
                .disabled(selectedDownload == nil)
            }
        }

        ToolbarItem(placement: .navigation) {
            ControlGroup {
                Button {
                    model.resumeDownloads(selectedDownloads)
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .help("Resume Selected Downloads")
                .disabled(selectedDownloads.isEmpty || model.isBusy)

                Button {
                    model.pauseDownloads(selectedDownloads)
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
                .help("Pause Selected Downloads")
                .disabled(selectedDownloads.isEmpty || model.isBusy)

                Button {
                    pendingRemoveDownloadIDs = selectedDownloadIDs
                    showRemoveConfirmation = !pendingRemoveDownloadIDs.isEmpty
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .help("Remove Selected Downloads")
                .disabled(selectedDownloads.isEmpty || model.isBusy)
            }
            .controlGroupStyle(.navigation)
        }

        ToolbarSpacer(.flexible, placement: .automatic)

        ToolbarItem(placement: .primaryAction) {
            ControlGroup {
                Button {
                    showAddLinksSheet = true
                } label: {
                    Label("Add Links", systemImage: "plus")
                }
                .help("Show Add Links Panel")
                .disabled(model.isBusy)
            }
        }

        ToolbarItem(placement: .primaryAction) {
            ControlGroup {
                Button {
                    showCompletedDownloadsSheet.toggle()
                } label: {
                    Label("Completed", systemImage: "checkmark")
                }
                .help("Show Completed Downloads")
                .popover(isPresented: $showCompletedDownloadsSheet, arrowEdge: .bottom) {
                    completedDownloadsSheet
                }
            }
        }

        ToolbarItem(placement: .primaryAction) {
            ControlGroup {
                Button {
                    openWindow(id: "search-window")
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .help("Open Search Window")
            }
        }

        ToolbarItem(placement: .primaryAction) {
            ControlGroup {
                Button {
                    openWindow(id: "servers-window")
                } label: {
                    Label("Servers", systemImage: "server.rack")
                }
                .help("Open Servers Window")
            }
        }
    }

    @ViewBuilder
    private var mainPanel: some View {
        switch selectedTab {
        case .search:
            searchPanel
        case .downloads:
            downloadsPanel
        case .servers:
            serversPanel
        }
    }

    private var searchPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Picker("Scope", selection: $model.searchScope) {
                    Text("Kad").tag("kad")
                    Text("Global").tag("global")
                    Text("Local").tag("local")
                }
                .pickerStyle(.segmented)
                .frame(width: 260)

                TextField("Search keyword", text: $model.searchQuery)
                    .textFieldStyle(.roundedBorder)

                Button("Search") {
                    model.performSearch()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy || model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            HStack {
                Text(model.searchStatusMessage.isEmpty ? "Ready" : model.searchStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Table(displayedSearchResults, sortOrder: $searchSortOrder) {
                TableColumn("ID", value: \SearchResult.index) { item in
                    Text(String(item.index))
                }.width(60)
                TableColumn("Name", value: \SearchResult.name) { item in
                    Text(item.name)
                }
                TableColumn("Size", value: \SearchResult.sizeBytes) { item in
                    Text(item.sizeDisplay)
                }.width(110)
                TableColumn("Sources", value: \SearchResult.sources) { item in
                    Text(String(item.sources))
                }.width(80)
                TableColumn("") { item in
                    Button("Download") {
                        model.downloadResult(item)
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isBusy)
                }.width(110)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var downloadsPanel: some View {
        Table(displayedDownloads, selection: $selectedDownloadIDs, sortOrder: $downloadSortOrder) {
            TableColumn("Name", sortUsing: KeyPathComparator(\DownloadItem.name, order: .forward)) { item in
                downloadTableCell(item, showsProgressBackground: false) {
                    HStack(spacing: 8) {
                        Image(systemName: downloadStatusSymbol(for: item.status))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                        Text(item.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .contextMenu { downloadContextMenu(item) }
            }
            .width(min: 320, ideal: 560)

            TableColumn("Progress", sortUsing: KeyPathComparator(\DownloadItem.doneBytes, order: .reverse)) { item in
                downloadTableCell(item, alignment: .trailing, showsProgressBackground: true) {
                    Text(item.completionText)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .contextMenu { downloadContextMenu(item) }
            }
            .width(132)

            TableColumn("Speed", sortUsing: KeyPathComparator(\DownloadItem.speedBytes, order: .reverse)) { item in
                downloadTableCell(item, alignment: .trailing, showsProgressBackground: false) {
                    Text(item.speedBytes > 0 ? item.speedText : "")
                        .lineLimit(1)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .contextMenu { downloadContextMenu(item) }
            }
            .width(74)

            TableColumn("Src", sortUsing: KeyPathComparator(\DownloadItem.sourceTotal, order: .reverse)) { item in
                downloadTableCell(item, alignment: .trailing, showsProgressBackground: false) {
                    Text(item.sourcesText)
                        .lineLimit(1)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .contextMenu { downloadContextMenu(item) }
            }
            .width(52)
        }
        .padding(.horizontal, 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollContentBackground(.hidden)
    }

    private var downloadDetailsSheet: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Download Details")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    isEditingDownloadName = false
                    showDownloadDetailsSheet = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .background(.thinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .help("Close")
            }

            if let item = selectedDownload {
                VStack(alignment: .leading, spacing: 12) {
                        if isEditingDownloadName {
                            HStack(spacing: 8) {
                                TextField("New file name", text: $downloadRenameDraft)
                                    .textFieldStyle(.roundedBorder)
                                Button("Apply") {
                                    model.renameDownload(item, to: downloadRenameDraft)
                                    isEditingDownloadName = false
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(
                                    model.isBusy ||
                                    downloadRenameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                    downloadRenameDraft == item.name
                                )
                                Button("Cancel") {
                                    downloadRenameDraft = item.name
                                    isEditingDownloadName = false
                                }
                                .buttonStyle(.bordered)
                                .disabled(model.isBusy)
                            }
                        } else {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(item.name)
                                    .font(.title3)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                                Spacer()
                                Button("Edit") {
                                    downloadRenameDraft = item.name
                                    isEditingDownloadName = true
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(model.isBusy)
                            }
                        }

                        Text(item.id)
                            .font(.callout.monospaced())
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            DownloadSegmentedProgressBar(
                                colors: item.progressColors,
                                fallbackProgress: item.progressDisplayValue / 100.0
                            )
                            Text("Progress: \(item.progressText)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        HStack(spacing: 10) {
                            Text(item.ed2kLink)
                                .font(.callout.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                            Button("Copy") {
                                model.copyDownloadLinkToClipboard(item)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 22) {
                                VStack(alignment: .leading, spacing: 8) {
                                    detailRowLarge("Completed", item.completionText)
                                    detailRowLarge("Transferred", item.transferredText)
                                    detailRowLarge("Sources", item.sourcesText)
                                    detailRowLarge("Priority", item.priorityText)
                                    detailRowLarge("Category", String(item.category))
                                    detailRowLarge("Part File", item.partMetName.isEmpty ? "-" : item.partMetName)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                VStack(alignment: .leading, spacing: 8) {
                                    detailRowLarge("Transferring", String(item.sourceTransferring))
                                    detailRowLarge("A4AF", String(item.sourceA4AF))
                                    detailRowLarge("Available Parts", String(item.availableParts))
                                    detailRowLarge("Active Time", item.activeTimeText)
                                    detailRowLarge("Last Seen Complete", item.lastSeenCompleteText)
                                    detailRowLarge("Last Received", item.lastReceivedText)
                                    detailRowLarge("Shared", item.shared ? "Yes" : "No")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            if !item.alternativeNames.isEmpty {
                                Divider()
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Alternative Names")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    ForEach(item.alternativeNames.sorted(by: { $0.count > $1.count })) { alt in
                                        HStack(spacing: 10) {
                                            Text(alt.name)
                                                .font(.body)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                            Spacer()
                                            Text("x\(alt.count)")
                                                .font(.body)
                                                .foregroundStyle(.secondary)
                                            Button("Use") {
                                                downloadRenameDraft = alt.name
                                                isEditingDownloadName = true
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                }
                            }

                            Divider()

                            HStack {
                                Text("Sources")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if model.isRefreshingSources {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Button("Refresh") {
                                    model.refreshDownloadSources(for: item)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(model.isRefreshingSources)
                            }

                            if selectedDownloadSources.isEmpty {
                                Text("No sources available yet.")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 4)
                            } else {
                                Table(selectedDownloadSources, sortOrder: $sourceSortOrder) {
                                    TableColumn("Client", value: \.clientName) { source in
                                        Text(source.clientDisplayName)
                                    }
                                    .width(min: 160, ideal: 220, max: 360)

                                    TableColumn("Endpoint", value: \.userIP) { source in
                                        Text(source.endpoint)
                                            .font(.system(.body, design: .monospaced))
                                    }
                                    .width(min: 130, ideal: 160, max: 250)

                                    TableColumn("Software", value: \.softwareVersion) { source in
                                        Text(source.softwareDisplay)
                                            .lineLimit(1)
                                    }
                                    .width(min: 120, ideal: 170, max: 260)

                                    TableColumn("State", value: \.downloadStateText) { source in
                                        Text(source.downloadStateText)
                                    }
                                    .width(min: 130, ideal: 160, max: 260)

                                    TableColumn("Speed", value: \.downSpeedKBps) { source in
                                        Text(source.speedText)
                                    }
                                    .width(min: 90, ideal: 110, max: 180)

                                    TableColumn("Avail", value: \.availableParts) { source in
                                        Text(String(source.availableParts))
                                    }
                                    .width(min: 60, ideal: 80, max: 110)

                                    TableColumn("Queue", value: \.remoteQueueRank) { source in
                                        Text(source.queueRankText)
                                    }
                                    .width(min: 70, ideal: 82, max: 120)

                                    TableColumn("From", value: \.sourceFromText) { source in
                                        Text(source.sourceFromText)
                                    }
                                    .width(min: 110, ideal: 140, max: 210)

                                    TableColumn("Server", value: \.serverName) { source in
                                        Text(source.serverEndpoint)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    .width(min: 170, ideal: 240, max: 360)

                                    TableColumn("Remote Name", value: \.remoteFilename) { source in
                                        Text(source.remoteFilename.isEmpty ? "-" : source.remoteFilename)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    .width(min: 220, ideal: 340, max: 520)
                                }
                                .frame(minHeight: 180, idealHeight: 230, maxHeight: 280)
                            }
                        }
                    }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Select a download item in Downloads tab first.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(14)
        .frame(minWidth: 760, idealWidth: 820, maxWidth: 860)
        .background(GlassEffectBackground(material: .hudWindow))
        .onAppear {
            if let selectedDownload {
                model.refreshDownloadSources(for: selectedDownload)
            }
        }
    }

    private var serversPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                TextField("Server address (IP:Port)", text: $model.serverAddressInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 260)

                TextField("Name (optional)", text: $model.serverNameInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 200)

                Button("Add") {
                    model.addServer()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy || model.serverAddressInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Divider()
                    .frame(height: 18)

                Button("Refresh") {
                    model.refreshServers()
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy)

                Button("Connect") {
                    model.connectServer(selectedServer)
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy)

                Button("Disconnect") {
                    model.disconnectServer()
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy)

                Button("Remove") {
                    if let selectedServer {
                        model.removeServer(selectedServer)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy || selectedServer == nil)

                Spacer()

                Text("\(displayedServers.count) server(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Table(displayedServers, selection: $selectedServerID, sortOrder: $serverSortOrder) {
                TableColumn("Name", value: \.name) { item in
                    Text(item.name.isEmpty ? "(unnamed)" : item.name)
                        .contextMenu { serverContextMenu(item) }
                }
                TableColumn("Address", value: \.address) { item in
                    Text(item.address)
                        .contextMenu { serverContextMenu(item) }
                }.width(170)
                TableColumn("Users", value: \.users) { item in
                    Text(item.usersText)
                        .contextMenu { serverContextMenu(item) }
                }.width(95)
                TableColumn("Files", value: \.files) { item in
                    Text(String(item.files))
                        .contextMenu { serverContextMenu(item) }
                }.width(90)
                TableColumn("Ping", value: \.ping) { item in
                    Text(item.ping > 0 ? "\(item.ping) ms" : "-")
                        .contextMenu { serverContextMenu(item) }
                }.width(90)
                TableColumn("Failed", value: \.failed) { item in
                    Text(String(item.failed))
                        .contextMenu { serverContextMenu(item) }
                }.width(75)
                TableColumn("Version", value: \.version) { item in
                    Text(item.version)
                        .contextMenu { serverContextMenu(item) }
                }.width(90)
                TableColumn("Prio", value: \.priority) { item in
                    Text(String(item.priority))
                        .contextMenu { serverContextMenu(item) }
                }.width(70)
                TableColumn("Static") { item in
                    Text(item.isStatic ? "Yes" : "No")
                        .contextMenu { serverContextMenu(item) }
                }.width(70)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let selectedServer {
                HStack(spacing: 8) {
                    Text("Description:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(selectedServer.description.isEmpty ? "-" : selectedServer.description)
                        .font(.caption)
                    Spacer()
                }
            }
        }
    }

    private var diagnosticsSheet: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Picker("Diagnostics", selection: $diagnosticsTab) {
                    ForEach(DiagnosticsTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 460)

                Spacer()

                Button("Copy") {
                    copyCurrentDiagnostics()
                }
                .buttonStyle(.bordered)

                if diagnosticsTab == .log {
                    Button("Clear Log") {
                        model.resetLog()
                    }
                    .buttonStyle(.bordered)
                }

                Button("Close") {
                    showDiagnosticsSheet = false
                }
                .buttonStyle(.borderedProminent)
            }

            ScrollView {
                Text(currentDiagnosticsText)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(14)
        .frame(minWidth: 920, minHeight: 520)
        .background(GlassEffectBackground(material: .hudWindow))
    }

    private var currentDiagnosticsText: String {
        switch diagnosticsTab {
        case .log:
            return model.outputLog.isEmpty ? "No command output yet." : model.outputLog
        case .downloads:
            return model.lastDownloadsRawOutput.isEmpty ? "No raw download queue output captured yet." : model.lastDownloadsRawOutput
        case .sources:
            return model.lastSourcesRawOutput.isEmpty ? "No raw source output captured yet." : model.lastSourcesRawOutput
        case .search:
            return model.lastSearchRawOutput.isEmpty ? "No raw search output captured yet." : model.lastSearchRawOutput
        case .servers:
            return model.lastServersRawOutput.isEmpty ? "No raw server-list output captured yet." : model.lastServersRawOutput
        }
    }

    private var footerStatusBar: some View {
        GeometryReader { geometry in
            let isNarrow = geometry.size.width < 940

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Button {
                        showEd2kStatusPopover.toggle()
                    } label: {
                        statusBadge(
                            title: "eD2k",
                            value: compactED2kBadgeValue(model.status.ed2k),
                            showsDisclosure: true
                        )
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showEd2kStatusPopover, arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("eD2k Status")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(model.status.ed2k)
                                .font(.callout)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .padding(10)
                        .frame(minWidth: 220, maxWidth: 360)
                    }
                    .help("Show Full eD2k Status")

                    statusBadge(title: "Kad", value: compactConnectionState(model.status.kad))
                    statusBadge(title: "Download", value: model.status.downloadSpeed)
                    statusBadge(title: "Upload", value: model.status.uploadSpeed)
                    statusBadge(title: "Queue", value: model.status.queue)

                    if !isNarrow {
                        Button {
                            footerDetailsExpanded.toggle()
                        } label: {
                            Image(systemName: footerDetailsExpanded ? "chevron.down.circle.fill" : "info.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help(footerDetailsExpanded ? "Hide Network Details" : "Show Network Details")
                    }

                    Spacer()

                    Button {
                        showLoginSheet = true
                    } label: {
                        Label(
                            model.isSessionConnected ? "Connected" : "Disconnected",
                            systemImage: model.isSessionConnected ? "link.circle.fill" : "link.circle"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(model.isSessionConnected ? .green : .orange)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Connection Status and Settings")
                }

                if footerDetailsExpanded && !isNarrow {
                    HStack(spacing: 10) {
                        Text("eD2k: \(model.status.ed2k)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Divider()
                            .frame(height: 12)
                        Text("Kad: \(model.status.kad)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }
                    .padding(.leading, 4)
                }
            }
            .onChange(of: isNarrow) { _, narrow in
                if narrow {
                    footerDetailsExpanded = false
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(height: footerDetailsExpanded ? 46 : 24)
    }

    private func statusBadge(title: String, value: String, showsDisclosure: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text(title + ":")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .lineLimit(1)
            if showsDisclosure {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.thinMaterial, in: Capsule())
    }

    private func compactConnectionState(_ value: String) -> String {
        let lower = value.lowercased()
        if lower.contains("connect") {
            return "On"
        }
        if lower.contains("run") {
            return "Run"
        }
        if lower.contains("unknown") {
            return "?"
        }
        return "Off"
    }

    private func compactED2kBadgeValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = "Connected to "
        guard trimmed.hasPrefix(prefix) else {
            return compactConnectionState(value)
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

        return rest.isEmpty ? "On" : rest
    }

    private func downloadStatusSymbol(for status: String) -> String {
        let raw = status.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercase = raw.lowercased()

        func hasAny(_ haystack: String, _ tokens: [String]) -> Bool {
            tokens.contains { haystack.contains($0) }
        }

        if hasAny(lowercase, ["error", "erroneous", "failed", "corrupt"]) || hasAny(raw, ["错误", "故障", "失败"]) {
            return "xmark"
        }
        if hasAny(lowercase, ["complete", "completed"]) || hasAny(raw, ["完成", "已完成"]) {
            return "checkmark"
        }
        if hasAny(lowercase, ["paused"]) || hasAny(raw, ["暂停"]) {
            return "pause"
        }
        if hasAny(lowercase, ["hashing", "allocat", "completing"]) || hasAny(raw, ["哈希", "分配", "完成中"]) {
            return "progress.indicator"
        }
        if hasAny(lowercase, ["downloading"]) || hasAny(raw, ["下载"]) {
            return "arrow.down"
        }
        if hasAny(lowercase, ["waiting"]) || hasAny(raw, ["等待"]) {
            return "clock"
        }
        return "questionmark"
    }

    private func downloadTableCell<Content: View>(
        _ item: DownloadItem,
        alignment: Alignment = .leading,
        showsProgressBackground: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: alignment)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background {
                if showsProgressBackground {
                    ZStack {
                        Rectangle()
                            .fill(Color.primary.opacity(0.02))
                        DownloadRowSegmentBackground(
                            colors: item.progressColors,
                            fallbackProgress: item.progressDisplayValue / 100.0
                        )
                        .opacity(0.28)
                    }
                }
            }
    }

    private var loginSheet: some View {
        VStack(spacing: 14) {
            Text("Connect To aMule Server")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Circle()
                    .fill(model.isSessionConnected ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(model.isSessionConnected ? "Connected" : "Disconnected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 10) {
                TextField("Host", text: $model.host)
                    .textFieldStyle(.roundedBorder)
                TextField("Port", value: $model.port, formatter: Self.plainPortFormatter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
            }

            SecureField("Password", text: $model.password)
                .textFieldStyle(.roundedBorder)

            HStack {
                if model.isBusy {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
                Button("Close") {
                    showLoginSheet = false
                }
                .buttonStyle(.bordered)
                if model.isSessionConnected {
                    Button("Disconnect") {
                        model.disconnectAll()
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isBusy)
                }
                Button(model.isSessionConnected ? "Reconnect" : "Connect") {
                    model.connectAll()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy)
            }
        }
        .padding(16)
        .frame(minWidth: 400, idealWidth: 430, maxWidth: 470, minHeight: 188)
        .background(GlassEffectBackground(material: .hudWindow))
    }

    private var addLinksSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add eD2k Links")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Paste one link per line (ed2k:// or magnet:? links).")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $addLinksDraft)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 140)

            HStack(spacing: 8) {
                Button("Clear") {
                    addLinksDraft = ""
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Close") {
                    showAddLinksSheet = false
                }
                .buttonStyle(.bordered)

                Button("Start Download") {
                    model.addLinks(addLinksDraft)
                    showAddLinksSheet = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(addLinksDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isBusy)
            }
        }
        .padding(16)
        .frame(minWidth: 560, idealWidth: 620, maxWidth: 760, minHeight: 260, idealHeight: 300)
        .background(GlassEffectBackground(material: .hudWindow))
    }

    private var completedDownloadsSheet: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Completed Downloads")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(completedDownloads.count) item(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Clear") {
                    model.clearCompletedDownloads(completedDownloads)
                }
                .buttonStyle(.bordered)
                .disabled(completedDownloads.isEmpty || model.isBusy)
            }

            if completedDownloads.isEmpty {
                Text("No completed items.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(completedDownloads) { item in
                            HStack(spacing: 10) {
                                Text(item.name)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer(minLength: 8)
                                Text(item.lastSeenCompleteText)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 6)
                            if item.id != completedDownloads.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .frame(height: completedDownloadsContentHeight)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .frame(width: 620)
    }

    @ViewBuilder
    private func downloadContextMenu(_ item: DownloadItem) -> some View {
        Button("Details…") {
            selectedDownloadIDs = [item.id]
            syncSelectedDownloadDraft()
            showDownloadDetailsSheet = true
        }
        Button("Sources…") {
            selectedDownloadIDs = [item.id]
            model.refreshDownloadSources(for: item)
            syncSelectedDownloadDraft()
            showDownloadDetailsSheet = true
        }
        Button("Copy eD2k Link") {
            model.copyDownloadLinkToClipboard(item)
        }
        Divider()
        Button("Pause") {
            model.pauseDownload(item)
        }
        Button("Resume") {
            model.resumeDownload(item)
        }
        Divider()
        Button("Remove") {
            pendingRemoveDownloadIDs = [item.id]
            showRemoveConfirmation = true
        }
        Divider()
        Menu("Priority") {
            Button("Low") { model.setDownloadPriority(item, "low") }
            Button("Normal") { model.setDownloadPriority(item, "normal") }
            Button("High") { model.setDownloadPriority(item, "high") }
            Button("Auto") { model.setDownloadPriority(item, "auto") }
        }
    }

    @ViewBuilder
    private func serverContextMenu(_ item: ServerItem) -> some View {
        Button("Connect") {
            model.connectServer(item)
        }
        Button("Remove") {
            model.removeServer(item)
        }
    }

    private func detailRowLarge(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title + ":")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 145, alignment: .leading)
            Text(value)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func refreshDisplayedSearchResults() {
        displayedSearchResults = model.searchResults.sorted(using: searchSortOrder)
    }

    private func refreshDisplayedDownloads() {
        displayedDownloads = model.downloads.sorted(using: downloadSortOrder)
        selectedDownloadIDs = selectedDownloadIDs.filter { id in
            displayedDownloads.contains(where: { $0.id == id })
        }
        if selectedDownloadIDs.isEmpty {
            downloadRenameDraft = ""
            showDownloadDetailsSheet = false
        } else if selectedDownload != nil && downloadRenameDraft.isEmpty {
            syncSelectedDownloadDraft()
        }
    }

    private func refreshDisplayedServers() {
        displayedServers = model.servers.sorted(using: serverSortOrder)
        if let selectedServerID,
           !displayedServers.contains(where: { $0.id == selectedServerID }) {
            self.selectedServerID = nil
        }
    }

    private func removePendingDownloads() {
        let items = displayedDownloads.filter { pendingRemoveDownloadIDs.contains($0.id) }
        pendingRemoveDownloadIDs.removeAll()
        model.removeDownloads(items)
    }

    private func copyCurrentDiagnostics() {
        switch diagnosticsTab {
        case .log:
            model.copyLogToClipboard()
        case .downloads:
            model.copyDownloadsRawToClipboard()
        case .sources:
            model.copySourcesRawToClipboard()
        case .search:
            model.copySearchRawToClipboard()
        case .servers:
            model.copyServersRawToClipboard()
        }
    }

    private func syncSelectedDownloadDraft() {
        guard let selectedDownload else {
            downloadRenameDraft = ""
            return
        }
        downloadRenameDraft = selectedDownload.name
    }

    private func isCompletedDownload(_ item: DownloadItem) -> Bool {
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
}

private struct DownloadRowSegmentBackground: View {
    let colors: [UInt32]
    let fallbackProgress: Double

    private static let fallbackDoneColor = packedColor(r: 104, g: 104, b: 104)
    private static let fallbackMissingColor = packedColor(r: 255, g: 0, b: 0)

    private var renderedColors: [UInt32] {
        if !colors.isEmpty {
            return colors
        }

        let segmentCount = 64
        let safeProgress = max(0, min(fallbackProgress, 1))
        let doneSegments = Int((safeProgress * Double(segmentCount)).rounded(.down))
        return (0..<segmentCount).map {
            $0 < doneSegments ? Self.fallbackDoneColor : Self.fallbackMissingColor
        }
    }

    var body: some View {
        Canvas { context, size in
            let segments = renderedColors
            let count = max(segments.count, 1)
            let height = max(1, size.height)

            for index in 0..<count {
                let left = floor(CGFloat(index) * size.width / CGFloat(count))
                let right = floor(CGFloat(index + 1) * size.width / CGFloat(count))
                let width = max(1, right - left)
                let rect = CGRect(x: left, y: 0, width: width, height: height)
                context.fill(
                    Path(rect),
                    with: .color(color(from: segments[min(index, segments.count - 1)]))
                )
            }
        }
    }

    private func color(from packed: UInt32) -> Color {
        let red = Double(packed & 0xff) / 255.0
        let green = Double((packed >> 8) & 0xff) / 255.0
        let blue = Double((packed >> 16) & 0xff) / 255.0
        return Color(red: red, green: green, blue: blue)
    }

    private static func packedColor(r: Int, g: Int, b: Int) -> UInt32 {
        (UInt32(b & 0xff) << 16) | (UInt32(g & 0xff) << 8) | UInt32(r & 0xff)
    }
}

private struct DownloadSegmentedProgressBar: View {
    let colors: [UInt32]
    let fallbackProgress: Double

    private static let fallbackDoneColor = packedColor(r: 104, g: 104, b: 104)
    private static let fallbackMissingColor = packedColor(r: 255, g: 0, b: 0)

    private var renderedColors: [UInt32] {
        if !colors.isEmpty {
            return colors
        }
        let segmentCount = 48
        let safeProgress = max(0, min(fallbackProgress, 1))
        let doneSegments = Int((safeProgress * Double(segmentCount)).rounded(.down))
        return (0..<segmentCount).map {
            $0 < doneSegments ? Self.fallbackDoneColor : Self.fallbackMissingColor
        }
    }

    var body: some View {
        Canvas { context, size in
            let segments = renderedColors
            let count = max(segments.count, 1)
            let height = max(1, size.height)

            for index in 0..<count {
                let left = floor(CGFloat(index) * size.width / CGFloat(count))
                let right = floor(CGFloat(index + 1) * size.width / CGFloat(count))
                let width = max(1, right - left)
                let rect = CGRect(x: left, y: 0, width: width, height: height)
                context.fill(
                    Path(rect),
                    with: .color(color(from: segments[min(index, segments.count - 1)]))
                )
            }
        }
        .frame(height: 8)
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private func color(from packed: UInt32) -> Color {
        let red = Double(packed & 0xff) / 255.0
        let green = Double((packed >> 8) & 0xff) / 255.0
        let blue = Double((packed >> 16) & 0xff) / 255.0
        return Color(red: red, green: green, blue: blue)
    }

    private static func packedColor(r: Int, g: Int, b: Int) -> UInt32 {
        (UInt32(b & 0xff) << 16) | (UInt32(g & 0xff) << 8) | UInt32(r & 0xff)
    }
}

private struct AddLinksHUD: View {
    let message: String

    var body: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(message)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 3)
        }
        .padding(.top, 18)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
