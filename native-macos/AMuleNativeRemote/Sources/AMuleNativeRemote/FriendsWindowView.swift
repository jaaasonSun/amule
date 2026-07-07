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

struct FriendsWindowView: View {
    @EnvironmentObject private var model: AppModel
    let embeddedInMainWindow: Bool
    @State private var selectedFriendID: Int?
    @State private var showingAddFriendSheet = false
    @State private var friendHash = ""
    @State private var friendIP = ""
    @State private var friendPort = ""
    @State private var friendName = ""

    init(embeddedInMainWindow: Bool = false) {
        self.embeddedInMainWindow = embeddedInMainWindow
    }

    var body: some View {
        content
            .frame(
                minWidth: embeddedInMainWindow ? nil : 760,
                minHeight: embeddedInMainWindow ? nil : 500
            )
            .task { model.refreshFriends() }
            .sheet(isPresented: $showingAddFriendSheet) {
                AddFriendSheetView(
                    hash: $friendHash,
                    ip: $friendIP,
                    port: $friendPort,
                    name: $friendName,
                    isBusy: model.isBusy,
                    canAdd: model.isBridgeOpSupported("friend-add")
                ) {
                    guard AddFriendSheetView.validate(hash: friendHash, ip: friendIP, port: friendPort, name: friendName) != nil else {
                        return
                    }
                    model.addFriend(hash: friendHash, ip: friendIP, port: friendPort, name: friendName)
                    friendHash = ""
                    friendIP = ""
                    friendPort = ""
                    friendName = ""
                    showingAddFriendSheet = false
                }
                .presentationDetents([.height(260)])
                .presentationDragIndicator(.hidden)
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showingAddFriendSheet = true
                    } label: {
                        Label("Add", systemImage: "person.badge.plus")
                    }
                    .help("Add Friend")
                    .disabled(model.isBusy || !model.isBridgeOpSupported("friend-add"))

                    Button {
                        model.refreshFriends()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .help("Refresh Friends")
                    .disabled(model.isBusy || !model.isBridgeOpSupported("friends"))

                    Button {
                        if let selectedFriendID {
                            model.removeFriend(id: selectedFriendID)
                            self.selectedFriendID = nil
                        }
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    .help("Remove Selected Friend")
                    .disabled(model.isBusy || selectedFriendID == nil || !model.isBridgeOpSupported("friend-remove"))
                }
            }
            .onChange(of: model.friends) {
                if let selectedFriendID,
                   !model.friends.contains(where: { $0.id == selectedFriendID }) {
                    self.selectedFriendID = nil
                }
            }
    }

    private var content: some View {
        VStack(spacing: 0) {
            if model.friends.isEmpty {
                Text("No friends available.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(18)
            } else {
                List(model.friends, id: \.id, selection: $selectedFriendID) { friend in
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
                            Text(friend.friendSlot ? "Friend slot enabled" : "Friend slot disabled")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(.vertical, 2)
                    .tag(friend.id)
                    .contextMenu {
                        Button(friend.friendSlot ? "Disable Friend Slot" : "Enable Friend Slot") {
                            model.setFriendSlot(id: friend.id, enabled: !friend.friendSlot)
                        }
                        .disabled(model.isBusy || !model.isBridgeOpSupported("friend-slot"))

                        Button("Remove", role: .destructive) {
                            model.removeFriend(id: friend.id)
                            if selectedFriendID == friend.id {
                                selectedFriendID = nil
                            }
                        }
                        .disabled(model.isBusy || !model.isBridgeOpSupported("friend-remove"))
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

private struct AddFriendSheetView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var hash: String
    @Binding var ip: String
    @Binding var port: String
    @Binding var name: String
    let isBusy: Bool
    let canAdd: Bool
    let add: () -> Void
    @State private var validationMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add Friend")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text("Hash")
                        .foregroundStyle(.secondary)
                    TextField("Client hash", text: $hash)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("IP")
                        .foregroundStyle(.secondary)
                    TextField("Address", text: $ip)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Port")
                        .foregroundStyle(.secondary)
                    TextField("Port", text: $port)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Name")
                        .foregroundStyle(.secondary)
                    TextField("Display name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    if let _ = Self.validate(hash: hash, ip: ip, port: port, name: name) {
                        validationMessage = nil
                        add()
                        dismiss()
                    } else {
                        validationMessage = currentValidationMessage
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isBusy || !canAdd)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    static func validate(hash: String, ip: String, port: String, name: String) -> FriendAddInput.Request? {
        try? FriendAddInput(hash: hash, ip: ip, port: port, name: name).validated()
    }

    private var currentValidationMessage: String {
        do {
            _ = try FriendAddInput(hash: hash, ip: ip, port: port, name: name).validated()
            return ""
        } catch let error as FriendAddInput.ValidationError {
            return error.localizedMessage
        } catch {
            return L3("Friend input is invalid.")
        }
    }
}
