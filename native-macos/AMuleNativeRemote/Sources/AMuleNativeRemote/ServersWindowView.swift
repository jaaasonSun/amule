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
    let embeddedInMainWindow: Bool

    init(embeddedInMainWindow: Bool = false) {
        self.embeddedInMainWindow = embeddedInMainWindow
    }

    @State private var serverSortOrder = [
        KeyPathComparator(\ServerItem.files, order: .reverse),
        KeyPathComparator(\ServerItem.name, order: .forward)
    ]
    @State private var displayedServers: [ServerItem] = []
    @State private var selectedServerID: ServerItem.ID? = nil
    @State private var showingAddServerSheet = false
    @State private var showingImportServerMetSheet = false
    @State private var showingKadBootstrapSheet = false
    @State private var showingKadNodesSheet = false
    @State private var showShutdownConfirmation = false

    private var selectedServer: ServerItem? {
        guard let selectedServerID else { return nil }
        return displayedServers.first(where: { $0.id == selectedServerID })
    }

    private var footerKadStatusText: String {
        let summary = NetworkStatusSummary(status: model.status)
        return LF2("Kad: %@", localizedConnectionStatusText(for: summary.kad))
    }

    private var footerEd2kStatusText: String {
        NetworkStatusSummary(status: model.status).ed2k
    }

    private var footerServerCountText: String {
        LF2("%lld server(s)", Int64(displayedServers.count))
    }

    private var footerSelectedServerDescription: String? {
        guard let selectedServer else { return nil }
        return selectedServer.description.isEmpty ? "-" : selectedServer.description
    }

    @ToolbarContentBuilder
    private var serversToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            ControlGroup {
                Button {
                    showingAddServerSheet = true
                } label: {
                    Label(L2("Add"), systemImage: "plus")
                }
                .help(L2("Add Server"))
                .disabled(model.isBusy)

                Button {
                    model.refreshServers()
                } label: {
                    Label(L2("Refresh"), systemImage: "arrow.clockwise")
                }
                .help(L2("Refresh Servers"))
                .disabled(model.isBusy)

                Button {
                    if let selectedServer {
                        model.removeServer(selectedServer)
                    }
                } label: {
                    Label(L2("Remove"), systemImage: "trash")
                }
                .help(L2("Remove Selected Server"))
                .disabled(model.isBusy || selectedServer == nil)
            }
            .controlGroupStyle(.navigation)
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                showingImportServerMetSheet = true
            } label: {
                Label(L2("Import .met"), systemImage: "arrow.down.circle")
            }
            .help(L2("Import server list from URL"))
            .disabled(model.isBusy)
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    model.startKad()
                } label: {
                    Label(L2("Start Kad"), systemImage: "play.fill")
                }
                .disabled(model.isBusy || !model.isBridgeOpSupported("kad-start"))

                Button {
                    model.stopKad()
                } label: {
                    Label(L2("Stop Kad"), systemImage: "stop.fill")
                }
                .disabled(model.isBusy || !model.isBridgeOpSupported("kad-stop"))

                Divider()

                Button {
                    showingKadBootstrapSheet = true
                } label: {
                    Label(L2("Bootstrap..."), systemImage: "point.3.filled.connected.trianglepath.dotted")
                }
                .disabled(model.isBusy || !model.isBridgeOpSupported("kad-bootstrap"))

                Button {
                    showingKadNodesSheet = true
                } label: {
                    Label(L2("Update nodes.dat..."), systemImage: "arrow.down.circle")
                }
                .disabled(model.isBusy || !model.isBridgeOpSupported("kad-update-from-url"))
            } label: {
                Label(L2("Kad"), systemImage: "point.3.filled.connected.trianglepath.dotted")
            }
            .help(L2("Kad controls"))
        }

        ToolbarItem(placement: .primaryAction) {
            ControlGroup {
                Button {
                    model.connectServer(selectedServer)
                } label: {
                    Label(L2("Connect"), systemImage: "link")
                }
                .help(L2("Connect Selected Server"))
                .disabled(model.isBusy || selectedServer == nil)

                Button {
                    model.disconnectServer()
                } label: {
                    Label(L2("Disconnect"), systemImage: "minus.circle")
                }
                .help(L2("Disconnect Current Server"))
                .disabled(model.isBusy)
            }
            .controlGroupStyle(.navigation)
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    showShutdownConfirmation = true
                } label: {
                    Label(L2("Shut Down Daemon"), systemImage: "power")
                }
                .disabled(model.isBusy || !model.isBridgeOpSupported("shutdown"))
            } label: {
                Label(L2("Server"), systemImage: "server.rack")
            }
            .help(L2("Server administration"))
        }
    }

    var body: some View {
        if embeddedInMainWindow {
            baseServersContent
        } else {
            baseServersContent
                .frame(minWidth: 1040, minHeight: 620)
        }
    }

    private var baseServersContent: some View {
        serversContentWithLifecycle
            .modifier(ServersSheetPresenter(
                model: model,
                showingAddServerSheet: $showingAddServerSheet,
                showingImportServerMetSheet: $showingImportServerMetSheet,
                showingKadBootstrapSheet: $showingKadBootstrapSheet,
                showingKadNodesSheet: $showingKadNodesSheet
            ))
    }

    private var serversContentWithLifecycle: some View {
        serversLayout
            .toolbar { serversToolbar }
            .alert(L2("Shut Down Daemon?"), isPresented: $showShutdownConfirmation) {
                Button(L2("Cancel"), role: .cancel) {}
                Button(L2("Shut Down"), role: .destructive) {
                    model.shutdownDaemon()
                }
            } message: {
                Text(L2("This will permanently shut down the remote aMule daemon. You will need to restart it manually."))
            }
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
    }

    private var serversLayout: some View {
        VStack(spacing: 0) {
            ServersTableView(
                servers: displayedServers,
                selectedServerID: $selectedServerID,
                sortOrder: $serverSortOrder
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollContentBackground(.hidden)

            Divider()
            ServersFooterView(
                selectedServerDescription: footerSelectedServerDescription,
                ed2kStatusText: footerEd2kStatusText,
                kadStatusText: footerKadStatusText,
                serverCountText: footerServerCountText
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func serverContextMenu(_ item: ServerItem) -> some View {
        Button(L2("Connect")) {
            model.connectServer(item)
        }
        Button(L2("Remove")) {
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

private struct ServersFooterView: View {
    let selectedServerDescription: String?
    let ed2kStatusText: String
    let kadStatusText: String
    let serverCountText: String

    var body: some View {
        HStack(spacing: 8) {
            if let selectedServerDescription {
                Text(L2("Description:"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(selectedServerDescription)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer()
            ServerConnectionStatusView(statusText: ed2kStatusText)
            Text(kadStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(serverCountText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
    }
}

private struct ServersSheetPresenter: ViewModifier {
    @ObservedObject var model: AppModel
    @Binding var showingAddServerSheet: Bool
    @Binding var showingImportServerMetSheet: Bool
    @Binding var showingKadBootstrapSheet: Bool
    @Binding var showingKadNodesSheet: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showingAddServerSheet) {
                AddServerSheetView(isBusy: model.isBusy) { address, name in
                    model.serverAddressInput = address
                    model.serverNameInput = name
                    model.addServer()
                    showingAddServerSheet = false
                }
            }
            .sheet(isPresented: $showingImportServerMetSheet) {
                ImportServerMetSheetView(isBusy: model.isBusy) { url in
                    model.updateServerListFromURL(url)
                    showingImportServerMetSheet = false
                }
            }
            .sheet(isPresented: $showingKadBootstrapSheet) {
                KadBootstrapSheetView(isBusy: model.isBusy) { ip, port in
                    model.bootstrapKad(ip: ip, port: port)
                    showingKadBootstrapSheet = false
                }
            }
            .sheet(isPresented: $showingKadNodesSheet) {
                KadNodesURLSheetView(isBusy: model.isBusy) { url in
                    model.updateKadNodesFromURL(url)
                    showingKadNodesSheet = false
                }
            }
    }
}

private struct ServersTableView: View {
    @EnvironmentObject private var model: AppModel

    let servers: [ServerItem]
    @Binding var selectedServerID: ServerItem.ID?
    @Binding var sortOrder: [KeyPathComparator<ServerItem>]

    var body: some View {
        Table(servers, selection: $selectedServerID, sortOrder: $sortOrder) {
            TableColumn(L2("Name"), value: \.name) { item in
                let connected = isConnectedServer(item)
                let row = ServerRowView.name(item: item, isConnected: connected)
                return row.contextMenu { serverContextMenu(item) }
            }
            .width(min: 180, ideal: 220, max: 420)

            TableColumn(L2("Address"), value: \.endpointText) { item in
                let row = ServerRowView.text(item.endpointText)
                return row.contextMenu { serverContextMenu(item) }
            }
            .width(170)

            TableColumn(L2("Users"), value: \.users) { item in
                let row = ServerRowView.text(item.usersText)
                return row.contextMenu { serverContextMenu(item) }
            }
            .width(95)

            TableColumn(L2("Files"), value: \.files) { item in
                let row = ServerRowView.number(item.files)
                return row.contextMenu { serverContextMenu(item) }
            }
            .width(90)

            TableColumn(L2("Ping"), value: \.ping) { item in
                let row = ServerRowView.ping(item.ping)
                return row.contextMenu { serverContextMenu(item) }
            }
            .width(90)

            TableColumn(L2("Failed"), value: \.failed) { item in
                let row = ServerRowView.number(item.failed)
                return row.contextMenu { serverContextMenu(item) }
            }
            .width(75)

            TableColumn(L2("Version"), value: \.version) { item in
                let row = ServerRowView.text(item.version)
                return row.contextMenu { serverContextMenu(item) }
            }
            .width(90)

            TableColumn(L2("Prio"), value: \.priority) { item in
                let row = ServerRowView.number(item.priority)
                return row.contextMenu { serverContextMenu(item) }
            }
            .width(70)

            TableColumn(L2("Static")) { item in
                let row = ServerRowView.isStatic(item.isStatic)
                return row.contextMenu { serverContextMenu(item) }
            }
            .width(70)
        }
    }

    private func serverContextMenu(_ item: ServerItem) -> some View {
        return Group {
            Button(L2("Connect")) {
                model.connectServer(item)
            }
            Button(L2("Remove")) {
                model.removeServer(item)
            }
            Divider()
            Button(item.isStatic ? L2("Remove Static Flag") : L2("Mark Static")) {
                model.setServerStatic(ecid: item.id, isStatic: !item.isStatic)
            }
            .disabled(model.isBusy || !model.isBridgeOpSupported("server-set-static"))
            Menu(L2("Priority")) {
                Button(L2("Low")) {
                    model.setServerPriority(ecid: item.id, priority: 1)
                }
                Button(L2("Normal")) {
                    model.setServerPriority(ecid: item.id, priority: 0)
                }
                Button(L2("High")) {
                    model.setServerPriority(ecid: item.id, priority: 2)
                }
            }
            .disabled(model.isBusy || !model.isBridgeOpSupported("server-set-priority"))
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
            Text(L2("Add Server"))
                .font(.headline)

            TextField(L2("Server address (IP:Port)"), text: $address)
                .textFieldStyle(.roundedBorder)

            TextField(L2("Name (optional)"), text: $name)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button(L2("Close")) {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(L2("Add Server")) {
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
            Text(L2("Import Server List"))
                .font(.headline)

            TextField("http://example.com/server.met", text: $url)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button(L2("Close")) {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(L2("Add")) {
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

private struct KadBootstrapSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let isBusy: Bool
    let onBootstrap: (_ ip: String, _ port: String) -> Void

    @State private var ip: String = ""
    @State private var port: String = ""

    private var trimmedIP: String {
        ip.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedPort: String {
        port.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L2("Bootstrap Kad"))
                .font(.headline)

            HStack(spacing: 8) {
                TextField(L2("IP address"), text: $ip)
                    .textFieldStyle(.roundedBorder)
                TextField(L2("Port"), text: $port)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
            }

            HStack {
                Button(L2("Close")) {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(L2("Bootstrap")) {
                    onBootstrap(trimmedIP, trimmedPort)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy || trimmedIP.isEmpty || trimmedPort.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 440)
    }
}

private struct KadNodesURLSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let isBusy: Bool
    let onUpdate: (_ url: String) -> Void

    @State private var url: String = ""

    private var trimmedURL: String {
        url.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L2("Update Kad nodes.dat"))
                .font(.headline)

            TextField("http://example.com/nodes.dat", text: $url)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button(L2("Close")) {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(L2("Download nodes.dat")) {
                    onUpdate(trimmedURL)
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
