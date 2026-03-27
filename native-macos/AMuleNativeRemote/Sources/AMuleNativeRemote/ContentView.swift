import SwiftUI
import AppKit
import Combine

private func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func LF(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), locale: .current, arguments: args)
}

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    private enum PartFileStatusCode {
        static let ready = 0
        static let empty = 1
        static let waitingForHash = 2
        static let hashing = 3
        static let error = 4
        static let insufficient = 5
        static let unknown = 6
        static let paused = 7
        static let completing = 8
        static let complete = 9
        static let allocating = 10
    }

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

    private static let plainPortFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.usesGroupingSeparator = false
        formatter.allowsFloats = false
        return formatter
    }()

    @State private var showLoginSheet = false
    @State private var showAddLinksSheet = false
    @State private var showKadSheet = false
    @State private var addLinksDraft: String = ""
    @State private var kadNodesURL: String = "http://upd.emule-security.org/nodes.dat"
    @State private var isRefreshingKadStatus = false
    @State private var selectedSidebarSelection: SidebarSelection = .downloads(.all)

    @State private var downloadSortOrder = [KeyPathComparator(\DownloadItem.name, order: .forward)]
    @State private var downloadNameFilterQuery: String = ""
    @State private var displayedDownloads: [DownloadItem] = []
    @State private var selectedDownloadIDs: Set<DownloadItem.ID> = []
    @State private var showRemoveConfirmation = false
    @State private var pendingRemoveDownloadIDs: Set<DownloadItem.ID> = []

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
            .filter { isCompletedDownload($0) }
            .sorted {
                if $0.lastSeenComplete != $1.lastSeenComplete {
                    return $0.lastSeenComplete > $1.lastSeenComplete
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    var body: some View {
        configuredBody
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

                    searchSidebarRow
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
                            SearchWindowView(embeddedInMainWindow: true)
                                .transaction { tx in
                                    tx.animation = nil
                                    tx.disablesAnimations = true
                                }
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
                    mainFooterBar
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .navigationTitle(windowTitleText)
        }
    }

    private var configuredBody: some View {
        presentedBody
    }

    private var styledBody: some View {
        baseBody
            .frame(minWidth: 760, minHeight: 420)
            .background(
                GlassEffectBackground(material: .underWindowBackground)
                    .ignoresSafeArea()
            )
            .background(
                WindowAppearanceConfigurator(
                    hideTitle: false,
                    transparentTitlebar: true,
                    fullSizeContentView: true,
                    toolbarStyle: .automatic,
                    showsToolbarBaselineSeparator: false,
                    allowsToolbarCustomization: false,
                    autosavesToolbarConfiguration: false,
                    makeWindowTransparent: true,
                    ensureToolbarWhenTransparentTitlebar: false
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
            .onChange(of: model.downloads) {
                refreshDisplayedDownloads()
            }
            .onChange(of: downloadSortOrder) {
                refreshDisplayedDownloads()
            }
            .onChange(of: downloadNameFilterQuery) {
                refreshDisplayedDownloads()
            }
            .onChange(of: selectedSidebarSelection) {
                refreshDisplayedDownloads()
            }
            .onChange(of: selectedDownloadIDs) {
                model.selectedDownloadID = selectedDownload?.id
                if let selectedDownload {
                    model.refreshDownloadSources(for: selectedDownload)
                }
            }
            .onChange(of: model.addLinksPanelRequestID) {
                showAddLinksSheet = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .amuleIncomingLinksDidChange)) { _ in
                model.flushIncomingLinksIfAny()
            }
    }

    private var presentedBody: some View {
        observedBody
            .animation(.none, value: selectedSidebarSelection)
            .sheet(isPresented: $showLoginSheet) {
                if #available(macOS 13.3, *) {
                    loginSheet
                        .presentationBackground(.clear)
                } else {
                    loginSheet
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
            .sheet(isPresented: $showKadSheet) {
                if #available(macOS 13.3, *) {
                    kadSheet
                        .presentationBackground(.clear)
                } else {
                    kadSheet
                }
            }
            .toolbar {
                if case .downloads = selectedSidebarSelection {
                    downloadsToolbar
                }
            }
            .alert("Remove Selected Downloads?", isPresented: $showRemoveConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    removePendingDownloads()
                }
            } message: {
                Text(
                    LF(
                        "This will remove %lld selected download(s). This action cannot be undone.",
                        Int64(pendingRemoveDownloadIDs.count)
                    )
                )
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
        ToolbarItem(placement: .automatic) {
            Button {
                presentSelectedDownloadDetails()
            } label: {
                Label("Details", systemImage: "info")
            }
            .help("Show Download Details")
            .disabled(selectedDownload == nil)
        }

        ToolbarItem(placement: .automatic) {
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

        ToolbarItem(placement: .automatic) {
            Button {
                showAddLinksSheet = true
            } label: {
                Label("Add Links", systemImage: "plus")
            }
            .help("Show Add Links Panel")
            .disabled(model.isBusy)
        }

        ToolbarItem(placement: .automatic) {
            Button {
                model.clearCompletedDownloads(completedDownloads)
            } label: {
                Label("Clear Completed", systemImage: "checkmark")
            }
            .help("Clear Completed Downloads")
            .disabled(completedDownloads.isEmpty || model.isBusy)
        }
    }

    private var downloadsPanel: some View {
        return Table(displayedDownloads, selection: $selectedDownloadIDs, sortOrder: $downloadSortOrder) {
            TableColumn("Name", sortUsing: KeyPathComparator(\DownloadItem.name, order: .forward)) { item in
                downloadTableCell(
                    item,
                    showsProgressBackground: false
                ) {
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

            TableColumn("Progress", sortUsing: KeyPathComparator(\DownloadItem.progressSortValue, order: .reverse)) { item in
                downloadTableCell(
                    item,
                    alignment: .trailing,
                    showsProgressBackground: true
                ) {
                    Text(item.completionText)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .contextMenu { downloadContextMenu(item) }
            }
            .width(128)

            TableColumn("Speed", sortUsing: KeyPathComparator(\DownloadItem.speedSortValue, order: .reverse)) { item in
                downloadTableCell(
                    item,
                    alignment: .trailing,
                    showsProgressBackground: false
                ) {
                    Text(item.speedBytes > 0 ? item.speedText : "")
                        .lineLimit(1)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .contextMenu { downloadContextMenu(item) }
            }
            .width(64)

            TableColumn("Src", sortUsing: KeyPathComparator(\DownloadItem.sourceTotal, order: .reverse)) { item in
                downloadTableCell(
                    item,
                    alignment: .trailing,
                    showsProgressBackground: false
                ) {
                    Text(item.sourcesText)
                        .lineLimit(1)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .contextMenu { downloadContextMenu(item) }
            }
            .width(48)
        }
        .padding(.horizontal, 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollContentBackground(.hidden)
        .searchable(text: $downloadNameFilterQuery, placement: .toolbar, prompt: L("Filter Downloads"))
    }

    enum ConnectionState {
        case connected
        case disconnected
        case transitional
        case unknown
    }

    private var searchSidebarRow: some View {
        Label("Search", systemImage: "magnifyingglass")
            .lineLimit(1)
            .badge(searchSidebarBadgeText)
    }

    private var searchSidebarBadgeText: String {
        if model.isSearchInProgress {
            return "…"
        }
        return String(model.searchResults.count)
    }

    private var amuleServerFooterConnectionState: ConnectionState {
        model.isSessionConnected ? .connected : .disconnected
    }

    private var ed2kFooterConnectionState: ConnectionState {
        connectionState(from: model.status.ed2k)
    }

    private var kadFooterConnectionState: ConnectionState {
        connectionState(from: model.status.kad)
    }

    private var ed2kFooterStatusText: String {
        compactED2kBadgeValue(model.status.ed2k)
    }

    private var mainFooterBar: some View {
        HStack(spacing: 6) {
            footerStatusControl(state: amuleServerFooterConnectionState) {
                Button {
                    showLoginSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .foregroundStyle(.secondary)
                        Text(L("aMule Server"))
                        footerConnectionStateSymbol(amuleServerFooterConnectionState)
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .help("Open Connection Panel")
            }

            footerStatusControl(state: ed2kFooterConnectionState) {
                ControlGroup {
                    Button {
                        openWindow(id: "servers-window")
                        NSApp.activate(ignoringOtherApps: true)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "rectangle.connected.to.line.below")
                                .foregroundStyle(.secondary)
                            switch ed2kFooterConnectionState {
                            case .connected:
                                Text(ed2kFooterPrimaryText)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            case .transitional:
                                Text(ed2kFooterPrimaryText)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                footerConnectionStateSymbol(ed2kFooterConnectionState)
                            case .disconnected, .unknown:
                                Text("eD2k")
                                footerConnectionStateSymbol(ed2kFooterConnectionState)
                            }
                        }
                        .font(.caption)
                        // Segmented controls render tighter leading content padding than
                        // bordered buttons; add a small inset so eD2k aligns visually
                        // with the aMule/Kad footer buttons.
                        .padding(.leading, 3)
                    }
                    .help("Open eD2k Window")

                    Button {
                        if ed2kFooterConnectionState == .connected {
                            model.connectServer(nil)
                        } else {
                            model.connectServer(bestServerForED2kConnect)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Reconnect")
                    .disabled(model.isBusy)
                }
                .controlGroupStyle(.navigation)
            }

            footerStatusControl(state: kadFooterConnectionState) {
                Button {
                    showKadSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                            .foregroundStyle(.secondary)
                        Text("Kad")
                        footerConnectionStateSymbol(kadFooterConnectionState)
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .help("Open Kad Panel")
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                footerMetricChip(title: L("Download"), value: model.status.downloadSpeed)
                footerMetricChip(title: L("Upload"), value: model.status.uploadSpeed)
            }
            .padding(.trailing, 8)
        }
        .controlSize(.small)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }

    private func footerMetricChip(title: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
        }
        .font(.caption)
    }

    private var ed2kFooterPrimaryText: String {
        let compact = ed2kFooterStatusText
        let stateText = compactConnectionState(model.status.ed2k)
        if compact != stateText && compact != "?" && !compact.isEmpty {
            return compact
        }
        return "eD2k"
    }

    @ViewBuilder
    private func footerStatusControl<Content: View>(
        state: ConnectionState,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if case .disconnected = state {
            content()
                .tint(.red)
        } else {
            content()
        }
    }

    @ViewBuilder
    private func footerConnectionStateSymbol(_ state: ConnectionState) -> some View {
        switch state {
        case .connected:
            Image(systemName: "checkmark.circle")
        case .disconnected:
            Image(systemName: "xmark.circle")
        case .transitional:
            ProgressView()
                .controlSize(.small)
        case .unknown:
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
        }
    }

    private var bestServerForED2kConnect: ServerItem? {
        model.servers
            .filter { !$0.ip.isEmpty && $0.port > 0 }
            .sorted {
                if $0.files != $1.files { return $0.files > $1.files }
                if $0.users != $1.users { return $0.users > $1.users }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            .first
    }

    private var kadSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Kad")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    Circle()
                        .fill(kadSheetStatusDotColor)
                        .frame(width: 8, height: 8)
                    Text(localizedConnectionStatusText(for: model.status.kad))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Button {
                        guard !isRefreshingKadStatus else { return }
                        isRefreshingKadStatus = true
                        Task {
                            await model.refreshStatus(logOutput: false, suppressErrors: true)
                            await MainActor.run {
                                isRefreshingKadStatus = false
                            }
                        }
                    } label: {
                        Group {
                            if isRefreshingKadStatus {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .controlSize(.small)
                    .help("Refresh")
                    .disabled(model.isBusy || isRefreshingKadStatus)
                    Spacer()
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Update nodes.dat from URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("http://example.com/nodes.dat", text: $kadNodesURL)
                    .textFieldStyle(.roundedBorder)
                    .disabled(model.isBusy)
            }

            HStack(spacing: 8) {
                Spacer()
                Button("Close") {
                    showKadSheet = false
                }
                .buttonStyle(.bordered)

                Button("Download nodes.dat") {
                    model.updateKadNodesFromURL(kadNodesURL)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy || kadNodesURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(minWidth: 300, idealWidth: 320, maxWidth: 360)
        .background(GlassEffectBackground(material: .hudWindow))
    }

    private var kadSheetStatusDotColor: Color {
        switch connectionState(from: model.status.kad) {
        case .connected:
            return .green
        case .transitional:
            return .orange
        case .disconnected:
            return .orange
        case .unknown:
            return .secondary
        }
    }

    private func connectionState(from value: String) -> ConnectionState {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "-" {
            return .unknown
        }

        let lower = trimmed.lowercased()

        let disconnectedTokens = [
            "disconnected", "not connected", "offline", "stopped", "off",
            "断开", "未连接", "離線", "离线", "未連線"
        ]
        if disconnectedTokens.contains(where: { lower.contains($0) }) {
            return .disconnected
        }

        let transitionalTokens = [
            "connecting", "starting", "initializing", "pending", "run", "running",
            "连接中", "正在连接", "連線中", "初始化"
        ]
        if transitionalTokens.contains(where: { lower.contains($0) }) {
            return .transitional
        }

        let connectedTokens = [
            "connected", "lowid", "highid", "firewalled", "on",
            "已连接", "已連線", "连接", "連線"
        ]
        if connectedTokens.contains(where: { lower.contains($0) }) {
            return .connected
        }

        if lower.contains("unknown") || lower.contains("未知") {
            return .unknown
        }

        return .unknown
    }

    private func compactConnectionState(_ value: String) -> String {
        switch connectionState(from: value) {
        case .connected:
            return L("On")
        case .disconnected:
            return L("Off")
        case .transitional:
            return L("Run")
        case .unknown:
            return "?"
        }
    }

    private func localizedConnectionStatusText(for value: String) -> String {
        switch connectionState(from: value) {
        case .connected:
            return L("Connected")
        case .disconnected:
            return L("Disconnected")
        case .transitional:
            return L("Connecting")
        case .unknown:
            return L("Unknown")
        }
    }

    private func compactED2kBadgeValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = ["Connected to ", "Connecting to "]
        guard let prefix = prefixes.first(where: { trimmed.hasPrefix($0) }) else {
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

        return rest.isEmpty ? compactConnectionState(value) : rest
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
                    DownloadRowSegmentBackground(
                        colors: item.progressColors,
                        fallbackProgress: item.progressDisplayValue / 100.0
                    )
                    .opacity(0.20)
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
                Text(model.isSessionConnected ? L("Connected") : L("Disconnected"))
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
                Button(model.isSessionConnected ? L("Reconnect") : L("Connect")) {
                    model.connectAll()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy)
            }
        }
        .padding(16)
        .frame(minWidth: 300, idealWidth: 320, maxWidth: 360, minHeight: 188)
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

    @ViewBuilder
    private func downloadContextMenu(_ item: DownloadItem) -> some View {
        Button("Details…") {
            openDownloadDetailsWindow(for: item, refreshSources: false)
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

    private func downloadFilterCount(for filter: DownloadSidebarFilter) -> Int {
        switch filter {
        case .all:
            return model.downloads.count
        case .downloading:
            return model.downloads.filter { isDownloadingDownload($0) }.count
        case .pending:
            return model.downloads.filter { isPendingDownload($0) }.count
        case .paused:
            return model.downloads.filter { isPausedDownload($0) }.count
        case .completed:
            return model.downloads.filter { isCompletedDownload($0) }.count
        }
    }

    private func filteredDownloads(_ items: [DownloadItem], for filter: DownloadSidebarFilter) -> [DownloadItem] {
        switch filter {
        case .all:
            return items
        case .downloading:
            return items.filter { isDownloadingDownload($0) }
        case .pending:
            return items.filter { isPendingDownload($0) }
        case .paused:
            return items.filter { isPausedDownload($0) }
        case .completed:
            return items.filter { isCompletedDownload($0) }
        }
    }

    private func isPausedDownload(_ item: DownloadItem) -> Bool {
        if item.statusCode == PartFileStatusCode.paused || item.statusCode == PartFileStatusCode.insufficient {
            return true
        }
        let lower = item.status.lowercased()
        if lower.contains("paused") || lower.contains("insufficient") || item.status.contains("暂停") || item.status.contains("磁盘空间不足") {
            return true
        }
        return false
    }

    private func isDownloadingDownload(_ item: DownloadItem) -> Bool {
        if isCompletedDownload(item) || isPausedDownload(item) {
            return false
        }
        if item.statusCode == PartFileStatusCode.completing ||
            item.statusCode == PartFileStatusCode.waitingForHash ||
            item.statusCode == PartFileStatusCode.hashing ||
            item.statusCode == PartFileStatusCode.allocating ||
            item.statusCode == PartFileStatusCode.error ||
            item.statusCode == PartFileStatusCode.insufficient {
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

    private func isPendingDownload(_ item: DownloadItem) -> Bool {
        if isCompletedDownload(item) || isPausedDownload(item) || isDownloadingDownload(item) {
            return false
        }
        return true
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

        for token in tokens {
            if haystack.contains(token) || compactHaystack.contains(token) {
                continue
            }
            if fuzzySubsequenceMatch(needle: token, in: haystack) || fuzzySubsequenceMatch(needle: token, in: compactHaystack) {
                continue
            }
            return false
        }
        return true
    }

    private func normalizedFuzzySearchString(_ raw: String) -> String {
        let folded = raw.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
        let mapped = folded.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) || CharacterSet.nonBaseCharacters.contains(scalar) {
                return Character(scalar)
            }
            // Keep CJK and other letters/numbers via Unicode categories covered by alphanumerics.
            return " "
        }
        return String(mapped)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func fuzzySubsequenceMatch(needle: String, in haystack: String) -> Bool {
        guard !needle.isEmpty else { return true }
        if needle.count == 1 {
            return haystack.contains(needle)
        }

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
            if !found {
                return false
            }
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

    private func isCompletedDownload(_ item: DownloadItem) -> Bool {
        if item.isCompleted || item.statusCode == PartFileStatusCode.complete {
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
        let luma = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
        let saturationScale = 0.42
        let softenedRed = luma + (red - luma) * saturationScale
        let softenedGreen = luma + (green - luma) * saturationScale
        let softenedBlue = luma + (blue - luma) * saturationScale
        return Color(red: softenedRed, green: softenedGreen, blue: softenedBlue)
    }

    private static func packedColor(r: Int, g: Int, b: Int) -> UInt32 {
        (UInt32(b & 0xff) << 16) | (UInt32(g & 0xff) << 8) | UInt32(r & 0xff)
    }
}

struct DownloadSegmentedProgressBar: View {
    let colors: [UInt32]
    let fallbackProgress: Double

    private let outerCornerRadius: CGFloat = 6
    private let innerCornerRadius: CGFloat = 4.5

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
        .frame(height: 10)
        .clipShape(RoundedRectangle(cornerRadius: innerCornerRadius, style: .continuous))
        .padding(2)
        .background {
            RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.18))
        }
        .overlay {
            RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.75)
        }
    }

    private func color(from packed: UInt32) -> Color {
        let red = Double(packed & 0xff) / 255.0
        let green = Double((packed >> 8) & 0xff) / 255.0
        let blue = Double((packed >> 16) & 0xff) / 255.0
        let luma = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
        let saturationScale = 0.55
        let softenedRed = luma + (red - luma) * saturationScale
        let softenedGreen = luma + (green - luma) * saturationScale
        let softenedBlue = luma + (blue - luma) * saturationScale
        return Color(
            red: softenedRed,
            green: softenedGreen,
            blue: softenedBlue,
            opacity: 0.82
        )
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
