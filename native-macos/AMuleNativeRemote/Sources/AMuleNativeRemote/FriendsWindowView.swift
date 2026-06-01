import SwiftUI
import AppKit
#if canImport(SharedUI)
import SharedUI
#endif

private func L2(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func LF2(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), locale: .current, arguments: args)
}

struct FriendsWindowView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    model.refreshFriends()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy || !model.isBridgeOpSupported("friends"))
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
        .background(GlassEffectBackground(material: .underWindowBackground).ignoresSafeArea())
        .background(
            WindowAppearanceConfigurator(
                windowTitle: "Friends",
                hideTitle: false,
                transparentTitlebar: true,
                fullSizeContentView: true,
                toolbarStyle: .automatic,
                makeWindowTransparent: true,
                ensureToolbarWhenTransparentTitlebar: false
            )
        )
        .task { model.refreshFriends() }
    }
}
