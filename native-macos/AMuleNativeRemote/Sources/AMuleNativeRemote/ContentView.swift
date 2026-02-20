import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    private enum DiagnosticsTab: String, CaseIterable {
        case log = "Log"
        case downloads = "Raw DL"
        case search = "Raw Search"
    }

    @State private var showLoginSheet = false
    @State private var showDiagnosticsSheet = false
    @State private var diagnosticsTab: DiagnosticsTab = .log
    @State private var downloadSortOrder = [KeyPathComparator(\DownloadItem.name, order: .forward)]
    @State private var displayedDownloads: [DownloadItem] = []

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
        .frame(minWidth: 980, minHeight: 700)
        .task {
            model.ensurePreferredBridgePath()
            model.startAutoRefresh()
            await model.refreshStatus(logOutput: false, suppressErrors: true)
            model.refreshDownloads()
            refreshDisplayedDownloads()
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

                Text("Parsed \(model.downloads.count) item(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            Table(displayedDownloads, sortOrder: $downloadSortOrder) {
                TableColumn("Name", value: \.name) { item in
                    Text(item.name)
                        .contextMenu { downloadContextMenu(item) }
                }
                TableColumn("Progress", value: \.progressValue) { item in
                    Text(item.progressText)
                        .contextMenu { downloadContextMenu(item) }
                }.width(90)
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
                .frame(width: 340)

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

    private func refreshDisplayedDownloads() {
        displayedDownloads = model.downloads.sorted(using: downloadSortOrder)
    }

    private func copyCurrentDiagnostics() {
        switch diagnosticsTab {
        case .log:
            model.copyLogToClipboard()
        case .downloads:
            model.copyDownloadsRawToClipboard()
        case .search:
            model.copySearchRawToClipboard()
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
}
