import SwiftUI

struct ServerLogsWindowView: View {
    @EnvironmentObject private var model: AppModel

    private var serverInfoText: String {
        model.serverInfoLines.joined(separator: "\n")
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Button {
                    model.refreshServerInfo()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(model.isBusy || !model.isBridgeOpSupported("server-info"))

                Button {
                    model.clearServerInfo()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(model.isBusy || !model.isBridgeOpSupported("clear-server-info"))

                Spacer()
            }

            ScrollView {
                Text(serverInfoText)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(14)
        .frame(minWidth: 720, minHeight: 420)
        .task {
            model.refreshServerInfo()
        }
    }
}
