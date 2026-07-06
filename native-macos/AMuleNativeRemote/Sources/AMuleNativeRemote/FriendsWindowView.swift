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
    @State private var friendHash = ""
    @State private var friendIP = ""
    @State private var friendPort = ""
    @State private var friendName = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    model.refreshFriends()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy || !model.isBridgeOpSupported("friends"))

                TextField("Hash", text: $friendHash)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                    .disabled(model.isBusy || !model.isBridgeOpSupported("friend-add"))
                TextField("IP", text: $friendIP)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 110)
                    .disabled(model.isBusy || !model.isBridgeOpSupported("friend-add"))
                TextField("Port", text: $friendPort)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 64)
                    .disabled(model.isBusy || !model.isBridgeOpSupported("friend-add"))
                TextField("Name", text: $friendName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 110)
                    .disabled(model.isBusy || !model.isBridgeOpSupported("friend-add"))
                Button {
                    model.addFriend(hash: friendHash, ip: friendIP, port: friendPort, name: friendName)
                } label: {
                    Label("Add", systemImage: "person.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy || !model.isBridgeOpSupported("friend-add"))

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if model.friends.isEmpty {
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
                            Button {
                                model.requestFriendSharedList(id: friend.id)
                            } label: {
                                Label("Shared", systemImage: "folder")
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.isBusy || !model.isBridgeOpSupported("friend-shared"))

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
        .task { model.refreshFriends() }
    }
}
