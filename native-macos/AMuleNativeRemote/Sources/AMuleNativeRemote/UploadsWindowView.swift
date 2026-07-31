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

struct UploadsWindowView: View {
    @EnvironmentObject private var model: AppModel
    let embeddedInMainWindow: Bool

    init(embeddedInMainWindow: Bool = false) {
        self.embeddedInMainWindow = embeddedInMainWindow
    }

    var body: some View {
        content
            .frame(
                minWidth: embeddedInMainWindow ? nil : 760,
                minHeight: embeddedInMainWindow ? nil : 500
            )
            .task { model.refreshUploads() }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        model.refreshUploads()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .help("Refresh Uploads")
                    .disabled(model.isBusy || !model.isBridgeOpSupported("uploads"))
                }
            }
    }

    private var content: some View {
        VStack(spacing: 0) {
            if model.uploads.isEmpty {
                Text("No active uploads.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(18)
            } else {
                List(model.uploads, id: \.clientID) { upload in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(upload.clientName.isEmpty ? "Client \(upload.clientID)" : upload.clientName)
                                .font(.headline)
                            Spacer()
                            Text("↑ \(AMuleFormatter.speed(bytesPerSecond: upload.speedUp))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(upload.userIP):\(upload.userPort)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.inset)
            }
        }
    }
}
