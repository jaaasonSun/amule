import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showLogSheet = false
    @State private var showRawDlSheet = false
    @State private var showSearchRawSheet = false
    @State private var showLoginSheet = false
    @State private var downloadSortOrder = [KeyPathComparator(\DownloadItem.name, order: .forward)]

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
            model.ensurePreferredCommandPath()
            model.startAutoRefresh()
            await model.refreshStatus(logOutput: false)
            model.refreshDownloads()
            showLoginSheet = true
        }
        .onDisappear {
            model.stopAutoRefresh()
        }
        .onChange(of: model.isSessionConnected) { connected in
            if connected {
                showLoginSheet = false
            }
        }
        .sheet(isPresented: $showLogSheet) {
            logSheet
        }
        .sheet(isPresented: $showRawDlSheet) {
            rawDlSheet
        }
        .sheet(isPresented: $showSearchRawSheet) {
            rawSearchSheet
        }
        .sheet(isPresented: $showLoginSheet) {
            loginSheet
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

            Button("Connection...") {
                showLoginSheet = true
            }
            .buttonStyle(.bordered)

            Button("Copy Log") {
                model.copyLogToClipboard()
            }
            .buttonStyle(.bordered)
            .disabled(model.outputLog.isEmpty)

            Button("Show Log") {
                showLogSheet = true
            }
            .buttonStyle(.bordered)

            Button("Show Raw DL") {
                showRawDlSheet = true
            }
            .buttonStyle(.bordered)
            .disabled(model.lastDownloadsRawOutput.isEmpty)

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
        .frame(minHeight: 280)
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

                Button("Raw Search") {
                    showSearchRawSheet = true
                }
                .buttonStyle(.bordered)
                .disabled(model.lastSearchRawOutput.isEmpty)
            }

            HStack {
                Text(model.searchStatusMessage.isEmpty ? "Ready" : model.searchStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Table(model.searchResults) {
                TableColumn("ID") { item in
                    Text(String(item.id))
                }.width(60)
                TableColumn("Name") { item in
                    Text(item.name)
                }
                TableColumn("Size (MB)") { item in
                    Text(item.sizeMB)
                }.width(90)
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

                Button("Copy Raw DL Output") {
                    model.copyDownloadsRawToClipboard()
                }
                .buttonStyle(.bordered)
                .disabled(model.lastDownloadsRawOutput.isEmpty)

                Button("Show Raw DL Output") {
                    showRawDlSheet = true
                }
                .buttonStyle(.bordered)
                .disabled(model.lastDownloadsRawOutput.isEmpty)

                Text("Parsed \(model.downloads.count) item(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Table(sortedDownloads, sortOrder: $downloadSortOrder) {
                TableColumn("Name", value: \.name) { item in
                    Text(item.name)
                        .contextMenu {
                            downloadContextMenu(item)
                        }
                }
                TableColumn("Progress", value: \.progressValue) { item in
                    Text(item.progress + "%")
                        .contextMenu {
                            downloadContextMenu(item)
                        }
                }.width(90)
                TableColumn("Sources", value: \.sourceCurrent) { item in
                    Text(item.sources)
                        .contextMenu {
                            downloadContextMenu(item)
                        }
                }.width(90)
                TableColumn("Status", value: \.status) { item in
                    Text(item.status)
                        .contextMenu {
                            downloadContextMenu(item)
                        }
                }
                TableColumn("Speed", value: \.speed) { item in
                    Text(item.speed)
                        .contextMenu {
                            downloadContextMenu(item)
                        }
                }.width(130)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var sortedDownloads: [DownloadItem] {
        model.downloads.sorted(using: downloadSortOrder)
    }

    private var logSheet: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Command Log")
                    .font(.headline)
                Spacer()
                Button("Copy") {
                    model.copyLogToClipboard()
                }
                .buttonStyle(.bordered)
                Button("Clear") {
                    model.resetLog()
                }
                .buttonStyle(.bordered)
                Button("Close") {
                    showLogSheet = false
                }
                .buttonStyle(.borderedProminent)
            }
            ScrollView {
                Text(model.outputLog.isEmpty ? "No command output yet." : model.outputLog)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(14)
        .frame(minWidth: 900, minHeight: 520)
    }

    private var rawDlSheet: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Raw Download Queue Output")
                    .font(.headline)
                Spacer()
                Button("Copy") {
                    model.copyDownloadsRawToClipboard()
                }
                .buttonStyle(.bordered)
                Button("Close") {
                    showRawDlSheet = false
                }
                .buttonStyle(.borderedProminent)
            }
            ScrollView {
                Text(model.lastDownloadsRawOutput.isEmpty ? "No raw queue output captured yet." : model.lastDownloadsRawOutput)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(14)
        .frame(minWidth: 900, minHeight: 420)
    }

    private var rawSearchSheet: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Raw Search Output")
                    .font(.headline)
                Spacer()
                Button("Copy") {
                    model.copySearchRawToClipboard()
                }
                .buttonStyle(.bordered)
                Button("Close") {
                    showSearchRawSheet = false
                }
                .buttonStyle(.borderedProminent)
            }
            ScrollView {
                Text(model.lastSearchRawOutput.isEmpty ? "No search output captured yet." : model.lastSearchRawOutput)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(14)
        .frame(minWidth: 900, minHeight: 420)
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
                TextField("amulecmd path", text: $model.commandPath)
                    .textFieldStyle(.roundedBorder)
                Button("Locate…") {
                    pickAmuleCmdPath()
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

    private func pickAmuleCmdPath() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use amulecmd"
        panel.title = "Choose amulecmd binary"
        if panel.runModal() == .OK, let url = panel.url {
            model.commandPath = url.path
        }
    }
}
