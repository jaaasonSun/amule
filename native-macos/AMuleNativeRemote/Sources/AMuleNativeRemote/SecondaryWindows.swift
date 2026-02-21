import SwiftUI

struct SearchWindowView: View {
    @EnvironmentObject private var model: AppModel

    @State private var searchSortOrder = [KeyPathComparator(\SearchResult.index, order: .forward)]
    @State private var displayedSearchResults: [SearchResult] = []

    var body: some View {
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
                TableColumn("ID", value: \.index) { item in
                    Text(String(item.index))
                }
                .width(60)

                TableColumn("Name", value: \.name) { item in
                    Text(item.name)
                }

                TableColumn("Size", value: \.sizeBytes) { item in
                    Text(item.sizeDisplay)
                }
                .width(110)

                TableColumn("Sources", value: \.sources) { item in
                    Text(String(item.sources))
                }
                .width(80)

                TableColumn("") { item in
                    Button("Download") {
                        model.downloadResult(item)
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isBusy)
                }
                .width(110)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollContentBackground(.hidden)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .frame(minWidth: 920, minHeight: 560)
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
                makeWindowTransparent: true,
                ensureToolbarWhenTransparentTitlebar: false,
                forceNoToolbar: true
            )
        )
        .task {
            refreshDisplayedSearchResults()
        }
        .onChange(of: model.searchResults) {
            refreshDisplayedSearchResults()
        }
        .onChange(of: searchSortOrder) {
            refreshDisplayedSearchResults()
        }
    }

    private func refreshDisplayedSearchResults() {
        displayedSearchResults = model.searchResults.sorted(using: searchSortOrder)
    }
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

struct ServersWindowView: View {
    @EnvironmentObject private var model: AppModel

    @State private var serverSortOrder = [KeyPathComparator(\ServerItem.name, order: .forward)]
    @State private var displayedServers: [ServerItem] = []
    @State private var selectedServerID: ServerItem.ID? = nil

    private var selectedServer: ServerItem? {
        guard let selectedServerID else { return nil }
        return displayedServers.first(where: { $0.id == selectedServerID })
    }

    var body: some View {
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
                    Text(item.isStatic ? "Yes" : "No")
                        .contextMenu { serverContextMenu(item) }
                }
                .width(70)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollContentBackground(.hidden)

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
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .frame(minWidth: 1040, minHeight: 620)
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
                makeWindowTransparent: true,
                ensureToolbarWhenTransparentTitlebar: false,
                forceNoToolbar: true
            )
        )
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
        displayedServers = model.servers.sorted(using: serverSortOrder)
        if let selectedServerID,
           !displayedServers.contains(where: { $0.id == selectedServerID }) {
            self.selectedServerID = nil
        }
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
    }

    @State private var diagnosticsTab: DiagnosticsTab = .log

    var body: some View {
        GeometryReader { proxy in
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
}
