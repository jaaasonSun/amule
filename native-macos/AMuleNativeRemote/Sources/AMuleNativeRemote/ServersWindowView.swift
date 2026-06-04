import SwiftUI
import AppKit
#if canImport(SharedViews)
import SharedViews
import SharedModels
import SharedServices
#endif

private func L2(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func LF2(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), locale: .current, arguments: args)
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
            ServersTableView(
                servers: displayedServers,
                selectedServerID: $selectedServerID,
                sortOrder: $serverSortOrder
            )
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
                ServerConnectionStatusView(statusText: model.status.ed2k)
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

private struct ServersTableView: View {
    @EnvironmentObject private var model: AppModel

    let servers: [ServerItem]
    @Binding var selectedServerID: ServerItem.ID?
    @Binding var sortOrder: [KeyPathComparator<ServerItem>]

    var body: some View {
        Table(servers, selection: $selectedServerID, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { item in
                let connected = isConnectedServer(item)
                let row = ServerRowView.name(item: item, isConnected: connected)
                return row.contextMenu { serverContextMenu(item) }
            }
            .width(min: 180, ideal: 220, max: 420)

            TableColumn("Address", value: \.endpointText) { item in
                let row = ServerRowView.text(item.endpointText)
                return row.contextMenu { serverContextMenu(item) }
            }
            .width(170)

            TableColumn("Users", value: \.users) { item in
                let row = ServerRowView.text(item.usersText)
                return row.contextMenu { serverContextMenu(item) }
            }
            .width(95)

            TableColumn("Files", value: \.files) { item in
                let row = ServerRowView.number(item.files)
                return row.contextMenu { serverContextMenu(item) }
            }
            .width(90)

            TableColumn("Ping", value: \.ping) { item in
                let row = ServerRowView.ping(item.ping)
                return row.contextMenu { serverContextMenu(item) }
            }
            .width(90)

            TableColumn("Failed", value: \.failed) { item in
                let row = ServerRowView.number(item.failed)
                return row.contextMenu { serverContextMenu(item) }
            }
            .width(75)

            TableColumn("Version", value: \.version) { item in
                let row = ServerRowView.text(item.version)
                return row.contextMenu { serverContextMenu(item) }
            }
            .width(90)

            TableColumn("Prio", value: \.priority) { item in
                let row = ServerRowView.number(item.priority)
                return row.contextMenu { serverContextMenu(item) }
            }
            .width(70)

            TableColumn("Static") { item in
                let row = ServerRowView.isStatic(item.isStatic)
                return row.contextMenu { serverContextMenu(item) }
            }
            .width(70)
        }
    }

    private func serverContextMenu(_ item: ServerItem) -> some View {
        return Group {
            Button("Connect") {
                model.connectServer(item)
            }
            Button("Remove") {
                model.removeServer(item)
            }
        }
    }

    private func isConnectedServer(_ server: ServerItem) -> Bool {
        let text = model.status.ed2k.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        guard let range = text.range(
            of: #"\b([0-9]{1,3}(?:\.[0-9]{1,3}){3}):([0-9]{1,5})\b"#,
            options: .regularExpression
        ) else { return false }
        let endpoint = String(text[range])
        let parts = endpoint.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let port = Int(parts[1]) else { return false }
        return server.ip == parts[0] && server.port == port
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

#if DEBUG
#Preview("Empty Servers") {
    ServersWindowView()
        .environmentObject(AppModel.previewConnected())
}

#Preview("With Servers") {
    ServersWindowView()
        .environmentObject(AppModel.previewWithServers())
}

#Preview("Connected Server Highlighted") {
    let model = AppModel.previewWithServers()
    model.status = StatusSnapshot(
        connected: true,
        ed2k: "Connected to Server [1.2.3.4:4661] HighID",
        kad: "Connected",
        downloadBytesPerSecond: 0,
        uploadBytesPerSecond: 0
    )
    return ServersWindowView()
        .environmentObject(model)
}
#endif
