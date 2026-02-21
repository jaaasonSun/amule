import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    private static let plainPortFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.usesGroupingSeparator = false
        formatter.allowsFloats = false
        return formatter
    }()

    @State private var showLoginSheet = false
    @State private var showAddLinksSheet = false
    @State private var showCompletedDownloadsSheet = false
    @State private var addLinksDraft: String = ""

    @State private var downloadSortOrder = [KeyPathComparator(\DownloadItem.name, order: .forward)]
    @State private var displayedDownloads: [DownloadItem] = []
    @State private var selectedDownloadIDs: Set<DownloadItem.ID> = []
    @State private var footerDetailsExpanded = false
    @State private var showEd2kStatusPopover = false
    @State private var showRemoveConfirmation = false
    @State private var pendingRemoveDownloadIDs: Set<DownloadItem.ID> = []

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
                model.startAutoRefresh()
                await model.refreshStatus(logOutput: false, suppressErrors: true)
                model.refreshDownloads()
                model.refreshServers()
                refreshDisplayedDownloads()
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
            .onChange(of: downloadSortOrder) {
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
                    presentSelectedDownloadDetails()
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

        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                showAddLinksSheet = true
            } label: {
                Label("Add Links", systemImage: "plus")
            }
            .help("Show Add Links Panel")
            .disabled(model.isBusy)

            Button {
                showCompletedDownloadsSheet.toggle()
            } label: {
                Label {
                    Text("Completed")
                } icon: {
                    completedToolbarIcon(count: completedDownloads.count)
                }
            }
            .help("Show Completed Downloads")
            .popover(isPresented: $showCompletedDownloadsSheet, arrowEdge: .bottom) {
                completedDownloadsSheet
            }

            Button {
                openWindow(id: "search-window")
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .help("Open Search Window")

            Button {
                openWindow(id: "servers-window")
            } label: {
                Label("Servers", systemImage: "server.rack")
            }
            .help("Open Servers Window")
        }
    }

    private var downloadsPanel: some View {
        Table(displayedDownloads, selection: $selectedDownloadIDs, sortOrder: $downloadSortOrder) {
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
        .background(
            DownloadsTableRowStripeStyle()
        )
    }

    private var footerStatusBar: some View {
        GeometryReader { geometry in
            let isNarrow = geometry.size.width < 940
            let ed2kState = connectionState(from: model.status.ed2k)
            let kadState = connectionState(from: model.status.kad)

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Button {
                        showEd2kStatusPopover.toggle()
                    } label: {
                        statusBadge(
                            title: "eD2k",
                            value: compactED2kBadgeValue(model.status.ed2k),
                            showsDisclosure: true,
                            tone: statusBadgeTone(for: ed2kState)
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

                    statusBadge(
                        title: "Kad",
                        value: compactConnectionState(model.status.kad),
                        tone: statusBadgeTone(for: kadState)
                    )
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

    private enum ConnectionState {
        case connected
        case disconnected
        case transitional
        case unknown
    }

    private enum StatusBadgeTone {
        case neutral
        case connected
        case disconnected
        case transitional
        case unknown
    }

    private func statusBadge(
        title: String,
        value: String,
        showsDisclosure: Bool = false,
        tone: StatusBadgeTone = .neutral
    ) -> some View {
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
        .background(statusBadgeBackground(tone: tone), in: Capsule())
    }

    private func statusBadgeBackground(tone: StatusBadgeTone) -> Color {
        switch tone {
        case .neutral:
            return Color.secondary.opacity(0.12)
        case .connected:
            return Color.green.opacity(0.18)
        case .disconnected:
            return Color.orange.opacity(0.22)
        case .transitional:
            return Color.yellow.opacity(0.20)
        case .unknown:
            return Color.secondary.opacity(0.18)
        }
    }

    @ViewBuilder
    private func completedToolbarIcon(count: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "checkmark")
            if count > 0 {
                Text(count > 99 ? "99+" : "\(count)")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.accentColor, in: Capsule())
                    .offset(x: 8, y: -8)
            }
        }
    }

    private func statusBadgeTone(for state: ConnectionState) -> StatusBadgeTone {
        switch state {
        case .connected:
            return .connected
        case .disconnected:
            return .disconnected
        case .transitional:
            return .transitional
        case .unknown:
            return .unknown
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
            return "On"
        case .disconnected:
            return "Off"
        case .transitional:
            return "Run"
        case .unknown:
            return "?"
        }
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
                    .opacity(0.28)
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

    private func refreshDisplayedDownloads() {
        displayedDownloads = model.downloads.sorted(using: downloadSortOrder)
        selectedDownloadIDs = selectedDownloadIDs.filter { id in
            displayedDownloads.contains(where: { $0.id == id })
        }
        model.selectedDownloadID = selectedDownload?.id
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

private struct DownloadsTableRowStripeStyle: NSViewRepresentable {
    final class HostView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
        }

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            apply()
        }

        override func layout() {
            super.layout()
            apply()
        }

        func apply() {
            DispatchQueue.main.async { [weak self] in
                guard let self, let tableView = self.findNearestTableView() else { return }
                self.configure(tableView)
            }
        }

        private func findNearestTableView() -> NSTableView? {
            var ancestor: NSView? = self
            while let current = ancestor {
                if let tableView = current.subviews.compactMap({ self.findTableView(in: $0) }).first {
                    return tableView
                }
                ancestor = current.superview
            }
            return nil
        }

        private func findTableView(in view: NSView) -> NSTableView? {
            if let table = view as? NSTableView {
                return table
            }
            for subview in view.subviews {
                if let table = findTableView(in: subview) {
                    return table
                }
            }
            return nil
        }

        private func configure(_ tableView: NSTableView) {
            tableView.usesAlternatingRowBackgroundColors = true
            configureHorizontalScrollBehavior(for: tableView)
        }

        private func configureHorizontalScrollBehavior(for tableView: NSTableView) {
            guard let scrollView = tableView.enclosingScrollView else { return }

            let totalColumnWidth = tableView.tableColumns.reduce(CGFloat(0)) { partial, column in
                partial + column.width
            }
            let viewportWidth = scrollView.contentView.bounds.width
            let fitsHorizontally = totalColumnWidth <= (viewportWidth + 0.5)

            let targetElasticity: NSScrollView.Elasticity = fitsHorizontally ? .none : .automatic
            if scrollView.horizontalScrollElasticity != targetElasticity {
                scrollView.horizontalScrollElasticity = targetElasticity
            }

            if fitsHorizontally {
                scrollView.hasHorizontalScroller = false
                let currentOrigin = scrollView.contentView.bounds.origin
                if currentOrigin.x != 0 {
                    scrollView.contentView.scroll(to: NSPoint(x: 0, y: currentOrigin.y))
                    scrollView.reflectScrolledClipView(scrollView.contentView)
                }
            } else {
                scrollView.hasHorizontalScroller = true
            }
        }
    }

    func makeNSView(context: Context) -> HostView {
        let view = HostView(frame: .zero)
        view.isHidden = true
        return view
    }

    func updateNSView(_ nsView: HostView, context: Context) {
        nsView.apply()
    }
}

struct DownloadSegmentedProgressBar: View {
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
