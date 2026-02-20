import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    private enum DiagnosticsTab: String, CaseIterable {
        case log = "Log"
        case downloads = "Raw DL"
        case search = "Raw Search"
        case servers = "Raw Servers"
    }

    @State private var showLoginSheet = false
    @State private var showDiagnosticsSheet = false
    @State private var diagnosticsTab: DiagnosticsTab = .log

    @State private var downloadSortOrder = [KeyPathComparator(\DownloadItem.name, order: .forward)]
    @State private var displayedDownloads: [DownloadItem] = []
    @State private var selectedDownloadID: DownloadItem.ID? = nil
    @State private var downloadRenameDraft: String = ""

    @State private var serverSortOrder = [KeyPathComparator(\ServerItem.name, order: .forward)]
    @State private var displayedServers: [ServerItem] = []
    @State private var selectedServerID: ServerItem.ID? = nil

    private var selectedDownload: DownloadItem? {
        guard let selectedDownloadID else { return nil }
        return displayedDownloads.first(where: { $0.id == selectedDownloadID })
    }

    private var selectedServer: ServerItem? {
        guard let selectedServerID else { return nil }
        return displayedServers.first(where: { $0.id == selectedServerID })
    }

    var body: some View {
        VStack(spacing: 10) {
            controls
            Divider()
            mainTabs
            Divider()
            footerStatusBar
            if !model.lastError.isEmpty {
                Text(model.lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(minWidth: 1080, minHeight: 740)
        .task {
            model.ensurePreferredBridgePath()
            model.startAutoRefresh()
            await model.refreshStatus(logOutput: false, suppressErrors: true)
            model.refreshDownloads()
            model.refreshServers()
            refreshDisplayedDownloads()
            refreshDisplayedServers()
            showLoginSheet = !model.isSessionConnected
        }
        .onDisappear {
            model.stopAutoRefresh()
        }
        .onChange(of: model.isSessionConnected) { connected in
            if connected {
                showLoginSheet = false
            }
        }
        .onChange(of: model.downloads) { _ in
            refreshDisplayedDownloads()
        }
        .onChange(of: downloadSortOrder) { _ in
            refreshDisplayedDownloads()
        }
        .onChange(of: selectedDownloadID) { _ in
            syncSelectedDownloadDraft()
        }
        .onChange(of: model.servers) { _ in
            refreshDisplayedServers()
        }
        .onChange(of: serverSortOrder) { _ in
            refreshDisplayedServers()
        }
        .sheet(isPresented: $showLoginSheet) {
            loginSheet
        }
        .sheet(isPresented: $showDiagnosticsSheet) {
            diagnosticsSheet
        }
    }

    private var controls: some View {
        HStack {
            Button(model.isSessionConnected ? "Disconnect" : "Connect") {
                if model.isSessionConnected {
                    model.disconnectAll()
                } else {
                    showLoginSheet = true
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isBusy)

            Button("Connection…") {
                showLoginSheet = true
            }
            .buttonStyle(.bordered)

            Button("Diagnostics…") {
                showDiagnosticsSheet = true
            }
            .buttonStyle(.bordered)

            Spacer()

            Text("Build \(model.buildCommit)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if model.isBusy {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var mainTabs: some View {
        TabView {
            searchPanel
                .tabItem { Text("Search") }
            downloadsPanel
                .tabItem { Text("Downloads") }
            serversPanel
                .tabItem { Text("Servers") }
        }
        .frame(minHeight: 320)
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

            Table(model.searchResults) {
                TableColumn("ID") { item in
                    Text(String(item.index))
                }.width(60)
                TableColumn("Name") { item in
                    Text(item.name)
                }
                TableColumn("Size") { item in
                    Text(item.sizeDisplay)
                }.width(110)
                TableColumn("Sources") { item in
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
        VStack(spacing: 10) {
            HStack {
                Button("Refresh Queue") {
                    model.refreshDownloads()
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy)

                Text("\(model.downloads.count) item(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            HSplitView {
                Table(displayedDownloads, selection: $selectedDownloadID, sortOrder: $downloadSortOrder) {
                    TableColumn("Name", value: \.name) { item in
                        Text(item.name)
                            .contextMenu { downloadContextMenu(item) }
                    }
                    TableColumn("Progress", value: \.progressValue) { item in
                        Text(item.progressText)
                            .contextMenu { downloadContextMenu(item) }
                    }.width(90)
                    TableColumn("Done") { item in
                        Text(item.completionText)
                            .contextMenu { downloadContextMenu(item) }
                    }.width(160)
                    TableColumn("Sources", value: \.sourceCurrent) { item in
                        Text(item.sourcesText)
                            .contextMenu { downloadContextMenu(item) }
                    }.width(90)
                    TableColumn("Status", value: \.status) { item in
                        Text(item.status)
                            .contextMenu { downloadContextMenu(item) }
                    }
                    TableColumn("Speed", value: \.speedBytes) { item in
                        Text(item.speedText)
                            .contextMenu { downloadContextMenu(item) }
                    }.width(130)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                downloadDetailsPane
                    .frame(minWidth: 320, idealWidth: 360)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var downloadDetailsPane: some View {
        GroupBox("Download Details") {
            ScrollView {
                if let item = selectedDownload {
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Rename")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                TextField("New file name", text: $downloadRenameDraft)
                                    .textFieldStyle(.roundedBorder)
                                Button("Apply") {
                                    model.renameDownload(item, to: downloadRenameDraft)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(model.isBusy || downloadRenameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || downloadRenameDraft == item.name)
                                Button("Reset") {
                                    downloadRenameDraft = item.name
                                }
                                .buttonStyle(.bordered)
                                .disabled(model.isBusy)
                            }
                        }
                        .padding(.bottom, 4)

                        detailRow("Name", item.name)
                        detailRow("Hash", item.id)
                        detailRow("Status", item.status)
                        detailRow("Progress", item.progressText)
                        detailRow("Completed", item.completionText)
                        detailRow("Transferred", item.transferredText)
                        detailRow("Speed", item.speedText)
                        detailRow("Sources", item.sourcesText)
                        detailRow("Transferring", String(item.sourceTransferring))
                        detailRow("A4AF", String(item.sourceA4AF))
                        detailRow("Priority", item.priorityText)
                        detailRow("Category", String(item.category))
                        detailRow("Part File", item.partMetName.isEmpty ? "-" : item.partMetName)
                        detailRow("Available Parts", String(item.availableParts))
                        detailRow("Active Time", item.activeTimeText)
                        detailRow("Last Seen Complete", item.lastSeenCompleteText)
                        detailRow("Last Received", item.lastReceivedText)
                        detailRow("Shared", item.shared ? "Yes" : "No")

                        Divider()
                            .padding(.vertical, 4)

                        Text("Alternative Names")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if item.alternativeNames.isEmpty {
                            Text("No alternative names available from current sources.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(item.alternativeNames.sorted(by: { $0.count > $1.count })) { alt in
                                HStack(spacing: 8) {
                                    Text(alt.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Text("x\(alt.count)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Button("Use") {
                                        downloadRenameDraft = alt.name
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                } else {
                    Text("Select a download item to view details.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
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
    }

    private var currentDiagnosticsText: String {
        switch diagnosticsTab {
        case .log:
            return model.outputLog.isEmpty ? "No command output yet." : model.outputLog
        case .downloads:
            return model.lastDownloadsRawOutput.isEmpty ? "No raw download queue output captured yet." : model.lastDownloadsRawOutput
        case .search:
            return model.lastSearchRawOutput.isEmpty ? "No raw search output captured yet." : model.lastSearchRawOutput
        case .servers:
            return model.lastServersRawOutput.isEmpty ? "No raw server-list output captured yet." : model.lastServersRawOutput
        }
    }

    private var footerStatusBar: some View {
        HStack(spacing: 12) {
            statusBadge(title: "eD2k", value: model.status.ed2k)
            statusBadge(title: "Kad", value: model.status.kad)
            statusBadge(title: "D", value: model.status.downloadSpeed)
            statusBadge(title: "U", value: model.status.uploadSpeed)
            statusBadge(title: "Q", value: model.status.queue)
            statusBadge(title: "Src", value: model.status.sources)
            Spacer()
            Circle()
                .fill(model.isSessionConnected ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(model.isSessionConnected ? "Connected" : "Disconnected")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func statusBadge(title: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(title + ":")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.thinMaterial, in: Capsule())
    }

    private var loginSheet: some View {
        VStack(spacing: 14) {
            Text("Connect To aMule Server")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                TextField("amule-ec-bridge path", text: $model.bridgePath)
                    .textFieldStyle(.roundedBorder)
                Button("Locate…") {
                    pickBridgePath()
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 10) {
                TextField("Host", text: $model.host)
                    .textFieldStyle(.roundedBorder)
                TextField("Port", value: $model.port, format: .number)
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
                Button("Cancel") {
                    showLoginSheet = false
                }
                .buttonStyle(.bordered)
                Button("Connect") {
                    model.connectAll()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy)
            }
        }
        .padding(16)
        .frame(minWidth: 620, minHeight: 220)
    }

    @ViewBuilder
    private func downloadContextMenu(_ item: DownloadItem) -> some View {
        Button("Pause") {
            model.pauseDownload(item)
        }
        Button("Resume") {
            model.resumeDownload(item)
        }
        Divider()
        Button("Stop (Pause)") {
            model.pauseDownload(item)
        }
        Button("Remove") {
            model.removeDownload(item)
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

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title + ":")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func refreshDisplayedDownloads() {
        displayedDownloads = model.downloads.sorted(using: downloadSortOrder)
        if let selectedDownloadID,
           !displayedDownloads.contains(where: { $0.id == selectedDownloadID }) {
            self.selectedDownloadID = nil
            downloadRenameDraft = ""
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

    private func copyCurrentDiagnostics() {
        switch diagnosticsTab {
        case .log:
            model.copyLogToClipboard()
        case .downloads:
            model.copyDownloadsRawToClipboard()
        case .search:
            model.copySearchRawToClipboard()
        case .servers:
            model.copyServersRawToClipboard()
        }
    }

    private func pickBridgePath() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use bridge"
        panel.title = "Choose amule-ec-bridge binary"
        if panel.runModal() == .OK, let url = panel.url {
            model.bridgePath = url.path
        }
    }

    private func syncSelectedDownloadDraft() {
        guard let selectedDownload else {
            downloadRenameDraft = ""
            return
        }
        downloadRenameDraft = selectedDownload.name
    }
}
