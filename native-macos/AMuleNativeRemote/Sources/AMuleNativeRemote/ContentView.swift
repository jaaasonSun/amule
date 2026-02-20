import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            connectionStrip
            statusGrid
            controls
            mainTabs
            if !model.lastError.isEmpty {
                Text(model.lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            logPanel
        }
        .padding(16)
        .frame(minWidth: 980, minHeight: 700)
        .task {
            model.ensurePreferredCommandPath()
            await model.refreshStatus()
            model.refreshDownloads()
        }
    }

    private var connectionStrip: some View {
        GroupBox("Connection") {
            HStack(spacing: 10) {
                TextField("amulecmd path", text: $model.commandPath)
                    .textFieldStyle(.roundedBorder)
                Button("Locate…") {
                    pickAmuleCmdPath()
                }
                .buttonStyle(.bordered)
                TextField("Host", text: $model.host)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                TextField("Port", value: $model.port, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                SecureField("Password", text: $model.password)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
            }
        }
    }

    private var statusGrid: some View {
        GroupBox("Status") {
            HStack(alignment: .top, spacing: 30) {
                statusRow("eD2k", model.status.ed2k)
                statusRow("Kad", model.status.kad)
                statusRow("Download", model.status.downloadSpeed)
                statusRow("Upload", model.status.uploadSpeed)
                statusRow("Queue", model.status.queue)
                statusRow("Sources", model.status.sources)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var controls: some View {
        HStack {
            Button("Connect") {
                model.connectAll()
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isBusy)

            Button("Disconnect") {
                model.disconnectAll()
            }
            .buttonStyle(.bordered)
            .disabled(model.isBusy)

            Button("Refresh Status") {
                Task { await model.refreshStatus() }
            }
            .buttonStyle(.bordered)
            .disabled(model.isBusy)

            Spacer()

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
                Spacer()
            }

            Table(model.downloads) {
                TableColumn("Name") { item in
                    Text(item.name)
                }
                TableColumn("Progress") { item in
                    Text(item.progress + "%")
                }.width(90)
                TableColumn("Sources") { item in
                    Text(item.sources)
                }.width(90)
                TableColumn("Status") { item in
                    Text(item.status)
                }
                TableColumn("Speed") { item in
                    Text(item.speed)
                }.width(130)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var logPanel: some View {
        GroupBox("Command Log") {
            ScrollView {
                Text(model.outputLog.isEmpty ? "No command output yet." : model.outputLog)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack {
                Spacer()
                Button("Clear Log") {
                    model.resetLog()
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func statusRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(2)
        }
        .frame(width: 120, alignment: .leading)
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
