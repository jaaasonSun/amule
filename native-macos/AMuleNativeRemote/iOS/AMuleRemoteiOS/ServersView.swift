#if canImport(UIKit)
import SwiftUI
import SharedModels
import SharedServices

struct ServersView: View {
    @ObservedObject var model: IOSAppModel
    @State private var showingAddSheet = false
    @State private var editingServer: UserServer?
    @State private var serverToDelete: UserServer?
    @State private var remoteServerToDelete: ServerItem?
    @State private var showingDeleteConfirmation = false
    @State private var showingRemoteDeleteConfirmation = false
    @State private var showingUpdateURLPrompt = false
    @State private var serverListURL = ""

    var body: some View {
        List {
            if model.isSessionConnected && !model.servers.isEmpty {
                Section {
                    ForEach(model.servers) { server in
                        ServerRow(server: server, model: model)
                            .swipeActions(edge: .leading) {
                                Button {
                                    model.connectServer(server)
                                } label: {
                                    Label("Connect", systemImage: "link")
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    remoteServerToDelete = server
                                    showingRemoteDeleteConfirmation = true
                                } label: {
                                    Label("Remove Remote", systemImage: "trash")
                                }
                            }
                            .onTapGesture {
                                model.connectServer(server)
                            }
                    }
                } header: {
                    Text("Daemon Server List")
                } footer: {
                    Text("These servers are read from the connected aMule daemon. Connect and remove actions mutate the daemon, not your local bookmarks.")
                }
            }

            Section {
                if model.userServers.isEmpty && (model.servers.isEmpty || !model.isSessionConnected) {
                    ContentUnavailableView(
                        "No Servers",
                        systemImage: "server.rack",
                        description: Text(model.isSessionConnected
                            ? L("Tap + to add a local bookmark.")
                            : L("Connect to aMule to see daemon servers, or tap + to add a local bookmark."))
                    )
                } else {
                    ForEach(model.userServers) { server in
                        UserServerRow(server: server, model: model)
                            .swipeActions(edge: .leading) {
                                Button {
                                    model.connectUserServer(server)
                                } label: {
                                    Label("Connect", systemImage: "link")
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .trailing) {
                                Button {
                                    editingServer = server
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.orange)

                                Button(role: .destructive) {
                                    serverToDelete = server
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .onTapGesture {
                                model.connectUserServer(server)
                            }
                    }
                }
            } header: {
                Text("Local Bookmarks")
            } footer: {
                Text("Bookmarks are stored only on this device. Use Connect to ask the daemon to connect to that endpoint.")
            }

            if model.isSessionConnected {
                Section {
                    Button {
                        serverListURL = ""
                        showingUpdateURLPrompt = true
                    } label: {
                        Label("Update Daemon Servers from URL", systemImage: "arrow.down.doc")
                    }

                    Button {
                        model.disconnectServer()
                    } label: {
                        Label("Disconnect from Server", systemImage: "link.badge.minus")
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .listStyle(.plain)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.refreshServers()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(!model.isSessionConnected || model.isBusy)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Server", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            ServerFormView(mode: .add) { name, ip, port in
                model.addServer(name: name, ip: ip, port: port)
                showingAddSheet = false
            }
        }
        .sheet(item: $editingServer) { server in
            ServerFormView(mode: .edit(server)) { name, ip, port in
                model.editUserServer(server, newName: name, newIP: ip, newPort: port)
                editingServer = nil
            }
        }
        .alert("Delete Server?", isPresented: $showingDeleteConfirmation, presenting: serverToDelete) { server in
            Button("Delete", role: .destructive) {
                model.removeUserServer(server)
                serverToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                serverToDelete = nil
            }
        } message: { server in
            Text(LF("Remove %@ from your server list?", server.name.isEmpty ? server.ip : server.name))
        }
        .alert("Remove Remote Server?", isPresented: $showingRemoteDeleteConfirmation, presenting: remoteServerToDelete) { server in
            Button("Remove from Daemon", role: .destructive) {
                model.removeRemoteServer(server)
                remoteServerToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                remoteServerToDelete = nil
            }
        } message: { server in
            Text(LF("Remove %@ from the connected daemon server list? This does not delete local bookmarks.", server.name.isEmpty ? server.endpointText : server.name))
        }
        .alert("Update Daemon Servers", isPresented: $showingUpdateURLPrompt) {
            TextField("server.met URL", text: $serverListURL)
                .textContentType(.URL)
                .keyboardType(.URL)
                .autocorrectionDisabled()
            Button("Update") {
                model.updateRemoteServers(from: serverListURL)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Fetch a server.met list into the connected daemon. Local bookmarks are unchanged.")
        }
        .task {
            if model.isSessionConnected {
                model.refreshServers()
            }
        }
    }
}

private struct ServerRow: View {
    let server: ServerItem
    @ObservedObject var model: IOSAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(server.name.isEmpty ? server.endpointText : server.name)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text(server.usersText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text(server.endpointText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if server.files > 0 {
                    Text(LF("%lld files", server.files))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct UserServerRow: View {
    let server: UserServer
    @ObservedObject var model: IOSAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "server.rack")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(server.name.isEmpty ? server.ip : server.name)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text(server.endpointText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

enum ServerFormMode {
    case add
    case edit(UserServer)
}

struct ServerFormView: View {
    let mode: ServerFormMode
    let onSave: (String, String, Int) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var ip: String = ""
    @State private var port: String = "4661"

    init(mode: ServerFormMode, onSave: @escaping (String, String, Int) -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .add:
            _name = State(initialValue: "")
            _ip = State(initialValue: "")
            _port = State(initialValue: "4661")
        case .edit(let server):
            _name = State(initialValue: server.name)
            _ip = State(initialValue: server.ip)
            _port = State(initialValue: String(server.port))
        }
    }

    private var isFormValid: Bool {
        let trimmedIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIP.isEmpty else { return false }
        guard let portValue = Int(port), (1...65535).contains(portValue) else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Server Details") {
                    TextField("Name (optional)", text: $name)
                        .textContentType(.name)
                    TextField("IP Address", text: $ip)
                        .textContentType(.URL)
                        .keyboardType(.decimalPad)
                        .autocorrectionDisabled()
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle(mode.isEdit ? "Edit Server" : "Add Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
                        let portValue = Int(port) ?? 4661
                        onSave(
                            name.trimmingCharacters(in: .whitespacesAndNewlines),
                            trimmedIP,
                            portValue
                        )
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }
}

extension ServerFormMode {
    var isEdit: Bool {
        if case .edit = self { return true }
        return false
    }
}

#Preview {
    NavigationStack {
        ServersView(model: IOSAppModel())
    }
}
#endif
