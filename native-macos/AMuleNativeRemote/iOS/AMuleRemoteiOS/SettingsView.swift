#if canImport(UIKit)
import SwiftUI
import SharedModels
import SharedViews

struct SettingsView: View {
    @ObservedObject var model: IOSAppModel

    var body: some View {
        Form {
            Section {
                LabeledContent("eD2k") {
                    connectionLabel(model.status.ed2k)
                }
                LabeledContent("Kad") {
                    connectionLabel(model.status.kad)
                }
                LabeledContent("Download") {
                    Text(model.status.downloadSpeed)
                        .monospacedDigit()
                }
                LabeledContent("Upload") {
                    Text(model.status.uploadSpeed)
                        .monospacedDigit()
                }
            } header: {
                Text("Status")
            }

            TransferLimitsSection(model: model)

            FilenameCleanupSettingsSection()

            Section {
                NavigationLink {
                    AboutView(model: model)
                } label: {
                    Label("About aMule Remote", systemImage: "info.circle")
                }
            }
        }
    }

    private func connectionLabel(_ value: String) -> some View {
        let state = ConnectionStateParser.parse(value)
        let color: Color
        switch state {
        case .connected: color = .green
        case .disconnected: color = .red
        case .transitional, .unknown: color = .orange
        }
        return Text(value.isEmpty ? L("Unknown") : value)
            .foregroundStyle(color)
    }
}

private struct FilenameCleanupSettingsSection: View {
    @AppStorage(FilenameCleanupPreferences.storageKey) private var filenameCleanupPrefixesRaw = "[]"
    @State private var draft = ""

    private var prefixes: [String] {
        FilenameCleanupPreferences.decode(filenameCleanupPrefixesRaw)
    }

    var body: some View {
        Section {
            HStack {
                TextField("Prefix to remove", text: $draft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    addPrefix()
                } label: {
                    Label("Add", systemImage: "plus.circle")
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ForEach(prefixes, id: \.self) { prefix in
                HStack {
                    Text(prefix)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                    Spacer()
                    Button(role: .destructive) {
                        removePrefix(prefix)
                    } label: {
                        Label("Remove", systemImage: "minus.circle")
                    }
                    .labelStyle(.iconOnly)
                }
            }
        } header: {
            Text("Filename Cleanup")
        } footer: {
            Text("Matching is case-insensitive and literal. Spaces and punctuation are part of the prefix.")
        }
    }

    private func addPrefix() {
        filenameCleanupPrefixesRaw = FilenameCleanupPreferences.encode(prefixes + [draft])
        draft = ""
    }

    private func removePrefix(_ prefix: String) {
        filenameCleanupPrefixesRaw = FilenameCleanupPreferences.encode(prefixes.filter { $0 != prefix })
    }
}

struct ConnectionSettingsView: View {
    @ObservedObject var model: IOSAppModel

    var body: some View {
        Form {
            ConnectionSection(model: model)
        }
    }
}

private struct ConnectionSection: View {
    @ObservedObject var model: IOSAppModel

    private static let plainPortFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.usesGroupingSeparator = false
        formatter.allowsFloats = false
        return formatter
    }()

    var body: some View {
        Section {
            HStack(spacing: 8) {
                ConnectionStateDot(state: model.isSessionConnected ? .connected : .disconnected)
                Text(model.isSessionConnected ? "Connected" : "Disconnected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            TextField("Host", text: $model.host)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            TextField("Port", value: $model.port, formatter: Self.plainPortFormatter)
                .keyboardType(.numberPad)

            SecureField("Password", text: $model.password)
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.asciiCapable)
        } header: {
            Text("Connection")
        }

        Section {
            HStack {
                if model.isBusy {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
                if model.isSessionConnected {
                    Button("Disconnect", role: .destructive) {
                        model.disconnect()
                    }
                    .disabled(model.isBusy)
                }
                Button(model.isSessionConnected ? "Reconnect" : "Connect") {
                    model.connect()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy)
            }
        }

        if !model.lastError.isEmpty {
            Section {
                Text(model.lastError)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }
}

private struct TransferLimitsSection: View {
    @ObservedObject var model: IOSAppModel
    @State private var uploadInput: String = ""
    @State private var downloadInput: String = ""
    @State private var hasEdited = false

    private static let plainNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.usesGroupingSeparator = false
        formatter.allowsFloats = false
        formatter.minimum = 0
        return formatter
    }()

    private func formatLimit(_ kbps: Int) -> String {
        if kbps == 0 {
            return L("Unlimited")
        } else if kbps >= 1024 {
            let mbps = Double(kbps) / 1024.0
            if mbps == floor(mbps) {
                return "\(Int(mbps)) MB/s"
            }
            return String(format: "%.1f MB/s", mbps)
        } else {
            return "\(kbps) KB/s"
        }
    }

    var body: some View {
        Section {
            HStack {
                Text("Download")
                Spacer()
                TextField("0", text: $downloadInput)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .onAppear {
                        if !hasEdited { downloadInput = String(model.downloadLimitKBps) }
                    }
                Text("KB/s")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            HStack {
                Text("Upload")
                Spacer()
                TextField("0", text: $uploadInput)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .onAppear {
                        if !hasEdited { uploadInput = String(model.uploadLimitKBps) }
                    }
                Text("KB/s")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            HStack {
                if model.isBusy {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
                Button("Apply") {
                    applyLimits()
                }
                .disabled(model.isBusy || !model.isBridgeOpSupported("prefs-connection-set"))
            }
        } header: {
            Text("Transfer Limits")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("0 = unlimited. Current limits:")
                HStack(spacing: 12) {
                    Label(formatLimit(model.downloadLimitKBps), systemImage: "arrow.down")
                    Label(formatLimit(model.uploadLimitKBps), systemImage: "arrow.up")
                }
            }
        }
    }

    private func applyLimits() {
        hasEdited = true
        model.setTransferLimits(uploadText: uploadInput, downloadText: downloadInput)
    }
}

private struct AboutView: View {
    @ObservedObject var model: IOSAppModel

    var body: some View {
        List {
            Section {
                LabeledContent(L("App"), value: "aMule Remote")
                LabeledContent(L("Platform"), value: "iOS/iPadOS")
                LabeledContent(L("Connection")) {
                    Text(model.isSessionConnected ? L("Connected") : L("Not connected"))
                }
            } header: {
                Text(L("Information"))
            }

            Section {
                LabeledContent("ed2k://", value: L("Supported"))
                LabeledContent("magnet:?", value: L("Supported"))
            } header: {
                Text(L("URL Schemes"))
            }
        }
        .navigationTitle(L("About"))
    }
}

#if DEBUG
#Preview("Disconnected") {
    NavigationStack {
        SettingsView(model: IOSAppModel.previewDisconnected())
    }
}

#Preview("Connected") {
    NavigationStack {
        SettingsView(model: IOSAppModel.previewWithSettings())
    }
}
#endif
#endif
