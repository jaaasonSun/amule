import SwiftUI
import AppKit
import SharedUI

private func L2(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func LF2(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), locale: .current, arguments: args)
}

private enum ServerWindowConnectionState2 {
    case connected
    case disconnected
    case transitional
    case unknown
}

private func connectionState2(from value: String) -> ServerWindowConnectionState2 {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty || trimmed == "-" { return .unknown }

    let lower = trimmed.lowercased()
    if ["disconnected", "not connected", "offline", "stopped", "off", "断开", "未连接", "離線", "离线", "未連線"]
        .contains(where: { lower.contains($0) }) {
        return .disconnected
    }
    if ["connecting", "starting", "initializing", "pending", "run", "running", "连接中", "正在连接", "連線中", "初始化"]
        .contains(where: { lower.contains($0) }) {
        return .transitional
    }
    if ["connected", "lowid", "highid", "firewalled", "on", "已连接", "已連線", "连接", "連線"]
        .contains(where: { lower.contains($0) }) {
        return .connected
    }
    return .unknown
}

private func localizedConnectionStateText2(_ state: ServerWindowConnectionState2) -> String {
    switch state {
    case .connected: return L2("Connected")
    case .disconnected: return L2("Disconnected")
    case .transitional: return L2("Connecting")
    case .unknown: return L2("Unknown")
    }
}

private func extractED2kServerName2(from value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let prefixes = ["Connected to ", "Connecting to "]
    guard let prefix = prefixes.first(where: { trimmed.hasPrefix($0) }) else { return nil }

    var rest = String(trimmed.dropFirst(prefix.count))
    if let suffixRange = rest.range(of: #"\s+(LowID|HighID)\s*$"#, options: .regularExpression) {
        rest.removeSubrange(suffixRange)
    }
    if let endpointRange = rest.range(
        of: #"\s+\[?[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(?::[0-9]+)?\]?$"#,
        options: .regularExpression
    ) {
        rest.removeSubrange(endpointRange)
    }
    let name = rest.trimmingCharacters(in: .whitespacesAndNewlines)
    return name.isEmpty ? nil : name
}

private func localizedED2kStatusSummary2(_ value: String) -> String {
    let state = connectionState2(from: value)
    switch state {
    case .connected:
        if let name = extractED2kServerName2(from: value) {
            return LF2("Connected to %@", name)
        }
    case .transitional:
        if let name = extractED2kServerName2(from: value) {
            return LF2("Connecting to %@", name)
        }
    case .disconnected, .unknown:
        break
    }
    return localizedConnectionStateText2(state)
}


struct AddLinksWindowView: View {
    @EnvironmentObject private var model: AppModel
    @State private var linksDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add eD2k Links")
                .font(.headline)

            Text("Paste one link per line (ed2k:// or magnet:? links).")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $linksDraft)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Button("Clear") {
                    linksDraft = ""
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Start Download") {
                    model.addLinks(linksDraft)
                }
                .buttonStyle(.borderedProminent)
                .disabled(linksDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isBusy)
            }
        }
        .padding(14)
        .frame(minWidth: 520, idealWidth: 560, maxWidth: 700, minHeight: 280, idealHeight: 320)
        .background(GlassEffectBackground(material: .underWindowBackground))
        .background(
            WindowAppearanceConfigurator(
                hideTitle: true,
                transparentTitlebar: true,
                fullSizeContentView: true,
                toolbarStyle: .automatic,
                makeWindowTransparent: true,
                ensureToolbarWhenTransparentTitlebar: false,
                windowLevel: .floating,
                windowCollectionBehavior: [.fullScreenAuxiliary, .moveToActiveSpace],
                isMovableByWindowBackground: true,
                panelHidesOnDeactivate: false,
                useUtilityStyleMask: true,
                isResizable: false,
                hidesStandardWindowButtons: true
            )
        )
    }
}

struct DownloadDetailsWindowView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("amule.ui.alwaysShowSuggestedFilename") private var alwaysShowSuggestedFilename = false

    @State private var sourceSortOrder = [KeyPathComparator(\DownloadSourceItem.clientName, order: .forward)]
    @State private var downloadRenameDraft: String = ""
    @State private var isEditingDownloadName = false

    private var selectedDownload: DownloadItem? {
        guard let selectedDownloadID = model.selectedDownloadID else { return nil }
        return model.downloads.first(where: { $0.id == selectedDownloadID })
    }

    private var selectedDownloadSources: [DownloadSourceItem] {
        model.sources(for: selectedDownload).sorted(using: sourceSortOrder)
    }

    private var canRenameSelectedDownload: Bool {
        guard let item = selectedDownload else { return false }
        return !item.isCompletedLike
    }

    private func shouldShowSuggestion(for item: DownloadItem, suggestion: String) -> Bool {
        guard alwaysShowSuggestedFilename else { return false }
        if item.usesDiagnosticNameEncodingFallback(alwaysShowDiagnostic: alwaysShowSuggestedFilename) {
            return item.displayedNameEncodingValue(alwaysShowDiagnostic: alwaysShowSuggestedFilename) == suggestion
        }
        guard !item.nameEncodingSuspect else { return false }
        guard item.displayedNameEncodingValue(alwaysShowDiagnostic: alwaysShowSuggestedFilename) == suggestion else { return false }
        return true
    }

    private func useSuggestionForRename(_ item: DownloadItem, suggestion: String) {
        guard let draft = FilenameSuggestionPresentation.renameDraft(from: suggestion, currentName: item.name) else { return }
        downloadRenameDraft = draft
        isEditingDownloadName = true
    }

    private func suggestionSectionTitle(for item: DownloadItem) -> String {
        if item.usesDiagnosticNameEncodingFallback(alwaysShowDiagnostic: alwaysShowSuggestedFilename) {
            return "Current Filename (Diagnostic)"
        }
        if alwaysShowSuggestedFilename && !item.nameEncodingSuspect {
            return "Suggested Filename (Diagnostic)"
        }
        return "Suggested Filename"
    }

    private func suggestionHelpText(for item: DownloadItem) -> String {
        if item.usesDiagnosticNameEncodingFallback(alwaysShowDiagnostic: alwaysShowSuggestedFilename) {
            return "Diagnostic display only. No distinct filename suggestion was detected, so this shows the current/original filename."
        }
        if canRenameSelectedDownload {
            return "Diagnostic guess only. The original filename stays unchanged until you apply a rename."
        }
        return "Diagnostic guess only. The original filename is preserved, and renaming is not available for this download."
    }

    private func suggestionHeaderTitle(for item: DownloadItem) -> String {
        if item.usesDiagnosticNameEncodingFallback(alwaysShowDiagnostic: alwaysShowSuggestedFilename) {
            return "Current Filename (Diagnostic)"
        }
        return item.nameEncodingSuspect ? "Suggested Filename" : "Diagnostic Suggestion"
    }

    private func suggestionHeaderColor(for item: DownloadItem) -> Color {
        item.usesDiagnosticNameEncodingFallback(alwaysShowDiagnostic: alwaysShowSuggestedFilename)
            ? .secondary
            : (item.nameEncodingSuspect ? .orange : .secondary)
    }

    private var sourcesTableHeight: CGFloat {
        let rowHeight: CGFloat = 28
        let headerHeight: CGFloat = 30
        let clampedRows = max(1, min(selectedDownloadSources.count, 5))
        if selectedDownloadSources.count <= 5 {
            return headerHeight + rowHeight * CGFloat(clampedRows) + 4
        }
        return 230
    }

    var body: some View {
        VStack(spacing: 12) {
            if let item = selectedDownload {
                VStack(alignment: .leading, spacing: 12) {
                    if isEditingDownloadName && canRenameSelectedDownload {
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
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.name)
                                    .font(.title3)
                                    .lineLimit(2)
                                    .truncationMode(.middle)

                                if let suggestion = item.displayedNameEncodingValue(alwaysShowDiagnostic: alwaysShowSuggestedFilename) {
                                    HStack(spacing: 8) {
                                        Label(suggestionHeaderTitle(for: item), systemImage: "wand.and.stars")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(suggestionHeaderColor(for: item))
                                        Text(suggestion)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        if item.meaningfulNameEncodingSuggestion != nil && canRenameSelectedDownload {
                                            Button("Use Suggested Filename") {
                                                useSuggestionForRename(item, suggestion: suggestion)
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.mini)
                                            .disabled(model.isBusy)
                                        }
                                    }
                                }
                            }
                            Spacer()
                            if canRenameSelectedDownload {
                                Button("Edit") {
                                    downloadRenameDraft = item.name
                                    isEditingDownloadName = true
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(model.isBusy)
                            }
                        }
                    }

                    Text(item.id)
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)

                    if let suggestion = item.displayedNameEncodingValue(alwaysShowDiagnostic: alwaysShowSuggestedFilename),
                       shouldShowSuggestion(for: item, suggestion: suggestion) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(suggestionSectionTitle(for: item))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(suggestion)
                                        .font(.body)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(suggestionHelpText(for: item))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if item.meaningfulNameEncodingSuggestion != nil && canRenameSelectedDownload {
                                    Button("Use Suggested Filename") {
                                        useSuggestionForRename(item, suggestion: suggestion)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .disabled(model.isBusy)
                                }
                            }
                        }

                        Divider()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        DownloadSegmentedProgressBar(
                            colors: item.progressColors,
                            fallbackProgress: item.progressDisplayValue / 100.0
                        )
                        Text(LF2("Progress: %@", item.progressText))
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
                                detailRowLarge("Shared", item.shared ? L2("Yes") : L2("No"))
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
                                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(alt.name)
                                                .font(.body)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                            if let suggestion = alt.meaningfulNameEncodingSuggestion {
                                                Label(suggestion, systemImage: "wand.and.stars")
                                                    .font(.caption)
                                                    .foregroundStyle(.orange)
                                                    .lineLimit(1)
                                                    .truncationMode(.middle)
                                            }
                                        }
                                        Spacer()
                                        Text("x\(alt.count)")
                                            .font(.body)
                                            .foregroundStyle(.secondary)
                                        if canRenameSelectedDownload {
                                            Button("Use") {
                                                useSuggestionForRename(item, suggestion: alt.meaningfulNameEncodingSuggestion ?? alt.name)
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                        }
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
                            .frame(height: sourcesTableHeight)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Select a download item in the Downloads window first.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .padding(14)
        .frame(width: 820, alignment: .topLeading)
        .frame(minHeight: 180, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
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
                makeWindowTransparent: true,
                ensureToolbarWhenTransparentTitlebar: false,
                forceNoToolbar: true
            )
        )
        .onAppear {
            syncSelectionState()
        }
        .onChange(of: model.selectedDownloadID) { _, _ in
            syncSelectionState()
        }
        .onChange(of: model.downloads) {
            syncSelectionState()
        }
        .onChange(of: model.renameSuggestionRequestID) { _, _ in
            applyPendingRenameSuggestionIfNeeded()
        }
    }

    private func syncSelectionState() {
        guard let selectedDownload else {
            downloadRenameDraft = ""
            isEditingDownloadName = false
            return
        }
        if !isEditingDownloadName || downloadRenameDraft.isEmpty {
            downloadRenameDraft = selectedDownload.name
        }
        if !canRenameSelectedDownload {
            isEditingDownloadName = false
        }
        model.refreshDownloadSources(for: selectedDownload)
        applyPendingRenameSuggestionIfNeeded()
    }

    private func applyPendingRenameSuggestionIfNeeded() {
        guard let selectedDownload else { return }
        guard let suggestion = model.consumeRenameSuggestionRequest(for: selectedDownload.id) else { return }
        guard canRenameSelectedDownload else { return }
        useSuggestionForRename(selectedDownload, suggestion: suggestion)
    }

    private func detailRowLarge(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(L2(title) + ":")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 145, alignment: .leading)
            Text(value)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ServersWindowView: View {
    @EnvironmentObject private var model: AppModel

    @State private var serverSortOrder = [
        KeyPathComparator(\ServerItem.files, order: .reverse),
        KeyPathComparator(\ServerItem.name, order: .forward)
    ]
    @State private var displayedServers: [ServerItem] = []
    @State private var selectedServerID: ServerItem.ID? = nil
    @State private var showingAddServerSheet = false
    @State private var showingImportServerMetSheet = false

    private var selectedServer: ServerItem? {
        guard let selectedServerID else { return nil }
        return displayedServers.first(where: { $0.id == selectedServerID })
    }

    @ToolbarContentBuilder
    private var serversToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            ControlGroup {
                Button {
                    showingAddServerSheet = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .help("Add Server")
                .disabled(model.isBusy)

                Button {
                    model.refreshServers()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh Servers")
                .disabled(model.isBusy)

                Button {
                    if let selectedServer {
                        model.removeServer(selectedServer)
                    }
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .help("Remove Selected Server")
                .disabled(model.isBusy || selectedServer == nil)
            }
            .controlGroupStyle(.navigation)
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                showingImportServerMetSheet = true
            } label: {
                Label("Import .met", systemImage: "arrow.down.circle")
            }
            .help("Import server list from URL")
            .disabled(model.isBusy)
        }

        ToolbarItem(placement: .primaryAction) {
            ControlGroup {
                Button {
                    model.connectServer(selectedServer)
                } label: {
                    Label("Connect", systemImage: "link")
                }
                .help("Connect Selected Server")
                .disabled(model.isBusy || selectedServer == nil)

                Button {
                    model.disconnectServer()
                } label: {
                    Label("Disconnect", systemImage: "minus.circle")
                }
                .help("Disconnect Current Server")
                .disabled(model.isBusy)
            }
            .controlGroupStyle(.navigation)
        }
    }

    var body: some View {
        baseServersContent
            .frame(minWidth: 1040, minHeight: 620)
            .background(
                GlassEffectBackground(material: .underWindowBackground)
                    .ignoresSafeArea()
            )
            .background(
                WindowAppearanceConfigurator(
                    windowTitle: "eD2k",
                    hideTitle: false,
                    transparentTitlebar: true,
                    fullSizeContentView: true,
                    toolbarStyle: .automatic,
                    makeWindowTransparent: true,
                    ensureToolbarWhenTransparentTitlebar: false
                )
            )
    }

    private var baseServersContent: some View {
        VStack(spacing: 0) {
            Table(displayedServers, selection: $selectedServerID, sortOrder: $serverSortOrder) {
                TableColumn("Name", value: \.name) { item in
                    HStack(spacing: 6) {
                        if isConnectedServer(item) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .help("Connected Server")
                        }
                        Text(item.name.isEmpty ? L2("(unnamed)") : item.name)
                            .fontWeight(isConnectedServer(item) ? .semibold : .regular)
                    }
                        .contextMenu { serverContextMenu(item) }
                }
                .width(min: 180, ideal: 220, max: 420)

                TableColumn("Address", value: \.endpointText) { item in
                    Text(item.endpointText)
                        .contextMenu { serverContextMenu(item) }
                }
                .width(170)

                TableColumn("Users", value: \.users) { item in
                    Text(item.usersText)
                        .contextMenu { serverContextMenu(item) }
                }
                .width(95)

                TableColumn("Files", value: \.files) { item in
                    Text(String(item.files))
                        .contextMenu { serverContextMenu(item) }
                }
                .width(90)

                TableColumn("Ping", value: \.ping) { item in
                    Text(item.ping > 0 ? "\(item.ping) ms" : "-")
                        .contextMenu { serverContextMenu(item) }
                }
                .width(90)

                TableColumn("Failed", value: \.failed) { item in
                    Text(String(item.failed))
                        .contextMenu { serverContextMenu(item) }
                }
                .width(75)

                TableColumn("Version", value: \.version) { item in
                    Text(item.version)
                        .contextMenu { serverContextMenu(item) }
                }
                .width(90)

                TableColumn("Prio", value: \.priority) { item in
                    Text(String(item.priority))
                        .contextMenu { serverContextMenu(item) }
                }
                .width(70)

                TableColumn("Static") { item in
                    Text(item.isStatic ? L2("Yes") : L2("No"))
                        .contextMenu { serverContextMenu(item) }
                }
                .width(70)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollContentBackground(.hidden)
            .background(
                ServersTableAutosaveConfigurator(
                    autosaveName: "AMuleNativeRemote.ServersTable"
                )
            )

            Divider()
            HStack(spacing: 8) {
                if let selectedServer {
                    Text("Description:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(selectedServer.description.isEmpty ? "-" : selectedServer.description)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer()
                Text(localizedED2kStatusSummary2(model.status.ed2k))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(LF2("%lld server(s)", Int64(displayedServers.count)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .toolbar { serversToolbar }
        .task {
            refreshDisplayedServers()
            model.refreshServers()
        }
        .onChange(of: model.servers) {
            refreshDisplayedServers()
        }
        .onChange(of: serverSortOrder) {
            refreshDisplayedServers()
        }
        .onChange(of: model.status.ed2k) {
            refreshDisplayedServers()
        }
        .sheet(isPresented: $showingAddServerSheet) {
            AddServerSheetView(isBusy: model.isBusy) { address, name in
                model.serverAddressInput = address
                model.serverNameInput = name
                model.addServer()
                showingAddServerSheet = false
            }
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showingImportServerMetSheet) {
            ImportServerMetSheetView(isBusy: model.isBusy) { url in
                model.updateServerListFromURL(url)
                showingImportServerMetSheet = false
            }
            .presentationDetents([.height(200)])
            .presentationDragIndicator(.hidden)
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

    private func refreshDisplayedServers() {
        var sorted = model.servers.sorted(using: serverSortOrder)
        let connected = sorted.filter(isConnectedServer)
        if !connected.isEmpty {
            let others = sorted.filter { !isConnectedServer($0) }
            sorted = connected + others
        }
        displayedServers = sorted
        if let selectedServerID,
           !displayedServers.contains(where: { $0.id == selectedServerID }) {
            self.selectedServerID = nil
        }
    }

    private func isConnectedServer(_ server: ServerItem) -> Bool {
        guard let endpoint = currentConnectedServerEndpoint else { return false }
        return server.ip == endpoint.ip && server.port == endpoint.port
    }

    private var currentConnectedServerEndpoint: (ip: String, port: Int)? {
        let text = model.status.ed2k.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        // Extract the first IPv4:port endpoint from eD2k status text, e.g.
        // "Connected to Foo [1.2.3.4:4661] LowID".
        guard let range = text.range(
            of: #"\b([0-9]{1,3}(?:\.[0-9]{1,3}){3}):([0-9]{1,5})\b"#,
            options: .regularExpression
        ) else {
            return nil
        }

        let endpoint = String(text[range])
        let parts = endpoint.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let port = Int(parts[1]) else { return nil }
        return (ip: parts[0], port: port)
    }
}

private struct AddServerSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let isBusy: Bool
    let onAdd: (_ address: String, _ name: String) -> Void

    @State private var address: String = ""
    @State private var name: String = ""

    private var trimmedAddress: String {
        address.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Server")
                .font(.headline)

            TextField("Server address (IP:Port)", text: $address)
                .textFieldStyle(.roundedBorder)

            TextField("Name (optional)", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Add Server") {
                    onAdd(trimmedAddress, trimmedName)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy || trimmedAddress.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 440)
    }
}

private struct ImportServerMetSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let isBusy: Bool
    let onAdd: (_ url: String) -> Void

    @State private var url: String = ""

    private var trimmedURL: String {
        url.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import Server List")
                .font(.headline)

            TextField("http://example.com/server.met", text: $url)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Add") {
                    onAdd(trimmedURL)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy || trimmedURL.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 520)
    }
}

struct DiagnosticsWindowView: View {
    @EnvironmentObject private var model: AppModel

    private enum DiagnosticsTab: String, CaseIterable {
        case log = "Log"
        case downloads = "Raw DL"
        case sources = "Raw Src"
        case search = "Raw Search"
        case servers = "Raw Servers"
        case coreLog = "Core Log"
        case coreDebugLog = "Core Debug"

        var localizedTitle: String { L2(rawValue) }
    }

    @State private var diagnosticsTab: DiagnosticsTab = .log

    private var availableTabs: [DiagnosticsTab] {
        var tabs: [DiagnosticsTab] = [.log, .downloads, .sources, .search, .servers]
        if model.isBridgeOpSupported("log") {
            tabs.append(.coreLog)
        }
        if model.isBridgeOpSupported("debug-log") {
            tabs.append(.coreDebugLog)
        }
        return tabs
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Picker("Diagnostics", selection: $diagnosticsTab) {
                        ForEach(availableTabs, id: \.self) { tab in
                            Text(tab.localizedTitle).tag(tab)
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

                    if diagnosticsTab == .coreLog {
                        Button("Refresh") {
                            model.refreshCoreLog()
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.isBusy || !model.isBridgeOpSupported("log"))
                    }

                    if diagnosticsTab == .coreDebugLog {
                        Button("Refresh") {
                            model.refreshCoreDebugLog()
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.isBusy || !model.isBridgeOpSupported("debug-log"))
                    }
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
            .padding(.top, proxy.safeAreaInsets.top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(minWidth: 920, minHeight: 520)
        .background(GlassEffectBackground(material: .underWindowBackground))
        .background(
            WindowAppearanceConfigurator(
                hideTitle: false,
                transparentTitlebar: true,
                fullSizeContentView: true,
                toolbarStyle: .unified,
                makeWindowTransparent: true,
                ensureToolbarWhenTransparentTitlebar: true
            )
        )
        .onAppear {
            if !availableTabs.contains(diagnosticsTab), let first = availableTabs.first {
                diagnosticsTab = first
            }
        }
        .onChange(of: model.bridgeOps) {
            if !availableTabs.contains(diagnosticsTab), let first = availableTabs.first {
                diagnosticsTab = first
            }
        }
    }

    private var currentDiagnosticsText: String {
        switch diagnosticsTab {
        case .log:
            return model.outputLog.isEmpty ? L2("No command output yet.") : model.outputLog
        case .downloads:
            return model.lastDownloadsRawOutput.isEmpty ? L2("No raw download queue output captured yet.") : model.lastDownloadsRawOutput
        case .sources:
            return model.lastSourcesRawOutput.isEmpty ? L2("No raw source output captured yet.") : model.lastSourcesRawOutput
        case .search:
            return model.lastSearchRawOutput.isEmpty ? L2("No raw search output captured yet.") : model.lastSearchRawOutput
        case .servers:
            return model.lastServersRawOutput.isEmpty ? L2("No raw server-list output captured yet.") : model.lastServersRawOutput
        case .coreLog:
            return model.coreLogLines.isEmpty ? L2("No core log lines captured yet.") : model.coreLogLines.joined(separator: "\n")
        case .coreDebugLog:
            return model.coreDebugLogLines.isEmpty ? L2("No core debug log lines captured yet.") : model.coreDebugLogLines.joined(separator: "\n")
        }
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
        case .coreLog:
            model.copyCoreLogRawToClipboard()
        case .coreDebugLog:
            model.copyCoreDebugLogRawToClipboard()
        }
    }
}

struct UploadsWindowView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    model.refreshUploads()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy || !model.isBridgeOpSupported("uploads"))

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if !model.isBridgeOpSupported("uploads") {
                Text("Uploads are unsupported by this bridge.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(18)
            } else if model.uploads.isEmpty {
                Text("No active uploads.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(18)
            } else {
                List(model.uploads, id: \.clientID) { upload in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(upload.clientName.isEmpty ? "Client \(upload.clientID)" : upload.clientName)
                                .font(.headline)
                            Spacer()
                            Text("↑ \(upload.speedUp)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(upload.userIP):\(upload.userPort)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 760, minHeight: 500)
        .background(GlassEffectBackground(material: .underWindowBackground).ignoresSafeArea())
        .background(
            WindowAppearanceConfigurator(
                windowTitle: "Uploads",
                hideTitle: false,
                transparentTitlebar: true,
                fullSizeContentView: true,
                toolbarStyle: .automatic,
                makeWindowTransparent: true,
                ensureToolbarWhenTransparentTitlebar: false
            )
        )
        .task { model.refreshUploads() }
    }
}

struct SharedFilesWindowView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    model.refreshSharedFiles()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy || !model.isBridgeOpSupported("shared-files"))

                Button("Reload") {
                    model.reloadSharedFiles()
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy || !model.isBridgeOpSupported("shared-files-reload"))

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if !model.isBridgeOpSupported("shared-files") {
                Text("Shared files are unsupported by this bridge.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(18)
            } else if model.sharedFiles.isEmpty {
                Text("No shared files available.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(18)
            } else {
                List(model.sharedFiles, id: \.hash) { file in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(file.name)
                            .font(.headline)
                        Text(file.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 760, minHeight: 500)
        .background(GlassEffectBackground(material: .underWindowBackground).ignoresSafeArea())
        .background(
            WindowAppearanceConfigurator(
                windowTitle: "Shared Files",
                hideTitle: false,
                transparentTitlebar: true,
                fullSizeContentView: true,
                toolbarStyle: .automatic,
                makeWindowTransparent: true,
                ensureToolbarWhenTransparentTitlebar: false
            )
        )
        .task { model.refreshSharedFiles() }
    }
}

struct CategoriesWindowView: View {
    @EnvironmentObject private var model: AppModel
    @State private var newCategoryName = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    model.refreshCategories()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy || !model.isBridgeOpSupported("categories"))

                TextField("New category name", text: $newCategoryName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 280)

                Button("Create") {
                    model.createCategory(name: newCategoryName, path: "", comment: "", color: 0, priority: 0)
                    newCategoryName = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy || !model.isBridgeOpSupported("category-create"))

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if !model.isBridgeOpSupported("categories") {
                Text("Categories are unsupported by this bridge.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(18)
            } else if model.categories.isEmpty {
                Text("No categories available.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(18)
            } else {
                List(model.categories, id: \.id) { category in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.title.isEmpty ? "Category \(category.id)" : category.title)
                                .font(.headline)
                            Text("ID: \(category.id)  Priority: \(category.priority)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Delete") {
                            model.deleteCategory(id: category.id)
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.isBusy || !model.isBridgeOpSupported("category-delete"))
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 700, minHeight: 460)
        .background(GlassEffectBackground(material: .underWindowBackground).ignoresSafeArea())
        .background(
            WindowAppearanceConfigurator(
                windowTitle: "Categories",
                hideTitle: false,
                transparentTitlebar: true,
                fullSizeContentView: true,
                toolbarStyle: .automatic,
                makeWindowTransparent: true,
                ensureToolbarWhenTransparentTitlebar: false
            )
        )
        .task { model.refreshCategories() }
    }
}

struct FriendsWindowView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    model.refreshFriends()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy || !model.isBridgeOpSupported("friends"))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if !model.isBridgeOpSupported("friends") {
                Text("Friends are unsupported by this bridge.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(18)
            } else if model.friends.isEmpty {
                Text("No friends available.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(18)
            } else {
                List(model.friends, id: \.id) { friend in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(friend.name.isEmpty ? "Friend \(friend.id)" : friend.name)
                                .font(.headline)
                            Spacer()
                            Text("\(friend.ip):\(friend.port)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Toggle("Friend Slot", isOn: Binding(
                                get: { friend.friendSlot },
                                set: { enabled in model.setFriendSlot(id: friend.id, enabled: enabled) }
                            ))
                            .toggleStyle(.switch)
                            .disabled(model.isBusy || !model.isBridgeOpSupported("friend-slot"))

                            Spacer()
                            Button("Remove") {
                                model.removeFriend(id: friend.id)
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.isBusy || !model.isBridgeOpSupported("friend-remove"))
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 760, minHeight: 500)
        .background(GlassEffectBackground(material: .underWindowBackground).ignoresSafeArea())
        .background(
            WindowAppearanceConfigurator(
                windowTitle: "Friends",
                hideTitle: false,
                transparentTitlebar: true,
                fullSizeContentView: true,
                toolbarStyle: .automatic,
                makeWindowTransparent: true,
                ensureToolbarWhenTransparentTitlebar: false
            )
        )
        .task { model.refreshFriends() }
    }
}

struct StatsWindowView: View {
    @EnvironmentObject private var model: AppModel
    @State private var widthInput = "480"
    @State private var scaleInput = "1"

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    model.refreshStatsTree()
                } label: {
                    Label("Refresh Tree", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy || !model.isBridgeOpSupported("stats-tree"))

                TextField("Width", text: $widthInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                TextField("Scale", text: $scaleInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)

                Button("Refresh Graphs") {
                    let width = Int(widthInput) ?? 480
                    let scale = Int(scaleInput) ?? 1
                    model.refreshStatsGraphs(width: max(1, width), scale: max(1, scale))
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy || !model.isBridgeOpSupported("stats-graphs"))

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let tree = model.statsTree {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Stats Tree")
                                .font(.headline)
                            ForEach(flatten(tree: tree), id: \.self) { line in
                                Text(line)
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }
                    }

                    if let graphs = model.statsGraphs {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Stats Graphs (\(graphs.samples.count) samples)")
                                .font(.headline)
                            Text("Last: \(graphs.last)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(Array(graphs.samples.enumerated()), id: \.offset) { _, sample in
                                Text("dl=\(sample.dl) ul=\(sample.ul) conn=\(sample.connections) kad=\(sample.kad)")
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
        }
        .frame(minWidth: 780, minHeight: 520)
        .background(GlassEffectBackground(material: .underWindowBackground).ignoresSafeArea())
        .background(
            WindowAppearanceConfigurator(
                windowTitle: "Statistics",
                hideTitle: false,
                transparentTitlebar: true,
                fullSizeContentView: true,
                toolbarStyle: .automatic,
                makeWindowTransparent: true,
                ensureToolbarWhenTransparentTitlebar: false
            )
        )
        .task {
            model.refreshStatsTree()
            model.refreshStatsGraphs()
        }
    }

    private func flatten(tree: BridgeStatsTreeNodePayload, depth: Int = 0) -> [String] {
        let indent = String(repeating: "  ", count: depth)
        var lines = ["\(indent)- \(tree.label): \(tree.value)"]
        for child in tree.children {
            lines.append(contentsOf: flatten(tree: child, depth: depth + 1))
        }
        return lines
    }
}

struct PreferencesWindowView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    model.refreshConnectionPrefs()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy || !model.isBridgeOpSupported("prefs-connection-get"))

                Spacer()
                if model.isBusy {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            Form {
                Section("Connection Speed Limits") {
                    VStack(alignment: .leading, spacing: 14) {
                        limitField(
                            title: "Download",
                            text: $model.connectionMaxDownloadInput,
                            value: model.connectionMaxDownloadKBps,
                            placeholder: "0"
                        )
                        limitField(
                            title: "Upload",
                            text: $model.connectionMaxUploadInput,
                            value: model.connectionMaxUploadKBps,
                            placeholder: "0"
                        )
                        Text("Values are in KiB/s. Use 0 for unlimited speed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                Section("IP Filter") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("https://example.com/ipfilter.dat", text: $model.ipFilterURLInput)
                            .textFieldStyle(.roundedBorder)
                            .disabled(model.isBusy || !model.isBridgeOpSupported("ipfilter-update"))

                        HStack(spacing: 10) {
                            Button("Update") {
                                model.updateIpFilterFromURL(model.ipFilterURLInput)
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.isBusy || !model.isBridgeOpSupported("ipfilter-update"))

                            Button("Reload") {
                                model.reloadIpFilter()
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.isBusy || !model.isBridgeOpSupported("ipfilter-reload"))
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Apply") {
                    model.setConnectionSpeedLimits(
                        maxDL: model.connectionMaxDownloadInput,
                        maxUL: model.connectionMaxUploadInput
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy || !model.isBridgeOpSupported("prefs-connection-set"))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(minWidth: 640, minHeight: 420)
        .background(GlassEffectBackground(material: .underWindowBackground).ignoresSafeArea())
        .background(
            WindowAppearanceConfigurator(
                windowTitle: "Preferences",
                hideTitle: false,
                transparentTitlebar: true,
                fullSizeContentView: true,
                toolbarStyle: .automatic,
                makeWindowTransparent: true,
                ensureToolbarWhenTransparentTitlebar: false
            )
        )
        .task {
            if model.isBridgeOpSupported("prefs-connection-get") {
                model.refreshConnectionPrefs()
            }
        }
    }

    private func limitField(title: String, text: Binding<String>, value: Int, placeholder: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .frame(width: 96, alignment: .leading)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 180)
            Text("KiB/s")
                .foregroundStyle(.secondary)
            Spacer()
            Text("Current: \(value)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ServersTableAutosaveConfigurator: NSViewRepresentable {
    let autosaveName: String

    final class HostView: NSView {
        var autosaveName: String = ""

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
                tableView.autosaveName = self.autosaveName
                tableView.autosaveTableColumns = true
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
    }

    func makeNSView(context: Context) -> HostView {
        let view = HostView(frame: .zero)
        view.isHidden = true
        view.autosaveName = autosaveName
        return view
    }

    func updateNSView(_ nsView: HostView, context: Context) {
        nsView.autosaveName = autosaveName
        nsView.apply()
    }
}
