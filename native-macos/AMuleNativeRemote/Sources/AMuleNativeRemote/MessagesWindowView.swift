import SwiftUI

struct MessagesWindowView: View {
    @EnvironmentObject private var model: AppModel
    @State private var draftMessage = ""

    var body: some View {
        NavigationSplitView {
            List {
                Text("Messages unavailable")
                    .foregroundStyle(.secondary)
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            VStack(spacing: 0) {
                List {
                    Text("Remote chat unavailable")
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack(spacing: 8) {
                    TextField("Message", text: $draftMessage)
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)
                    Button {
                    } label: {
                        Label("Send", systemImage: "paperplane")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(true)
                }
                .padding(12)
            }
        }
        .frame(minWidth: 760, minHeight: 500)
        .disabled(!model.isRemoteMessagesSupported)
    }
}
