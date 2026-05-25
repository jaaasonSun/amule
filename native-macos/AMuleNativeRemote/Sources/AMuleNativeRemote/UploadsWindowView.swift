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

struct UploadsWindowView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    model.refreshUploads()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy || !model.isBridgeOpSupported("uploads"))

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if !model.isBridgeOpSupported("uploads") {
                Text("Uploads are unsupported by this bridge.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(18)
            } else if model.uploads.isEmpty {
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
                            Text("↑ \(upload.speedUp)")
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
        .frame(minWidth: 760, minHeight: 500)
        .background(GlassEffectBackground(material: .underWindowBackground).ignoresSafeArea())
        .background(
            WindowAppearanceConfigurator(
                windowTitle: "Uploads",
                hideTitle: false,
                transparentTitlebar: true,
                fullSizeContentView: true,
                toolbarStyle: .automatic,
                makeWindowTransparent: true,
                ensureToolbarWhenTransparentTitlebar: false
            )
        )
        .task { model.refreshUploads() }
    }
}
