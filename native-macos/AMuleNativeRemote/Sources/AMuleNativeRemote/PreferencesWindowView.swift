import SwiftUI
import AppKit
import SharedViews
import SharedModels
import SharedServices

struct PreferencesWindowView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage(FilenameCleanupPreferences.storageKey) private var filenameCleanupPrefixesRaw = "[]"
    @State private var filenameCleanupPrefixDraft = ""

    private var filenameCleanupPrefixes: [String] {
        FilenameCleanupPreferences.decode(filenameCleanupPrefixesRaw)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    model.refreshConnectionPrefs()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy || !model.isBridgeOpSupported("prefs-connection-get"))

                Spacer()
                if model.isBusy {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            Form {
                Section("Connection Speed Limits") {
                    VStack(alignment: .leading, spacing: 14) {
                        limitField(
                            title: "Download",
                            text: $model.connectionMaxDownloadInput,
                            value: model.connectionMaxDownloadKBps,
                            placeholder: "0"
                        )
                        limitField(
                            title: "Upload",
                            text: $model.connectionMaxUploadInput,
                            value: model.connectionMaxUploadKBps,
                            placeholder: "0"
                        )
                        Text("Values are in KiB/s. Use 0 for unlimited speed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                Section("Filename Cleanup") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            TextField("Prefix to remove", text: $filenameCleanupPrefixDraft)
                                .textFieldStyle(.roundedBorder)
                            Button("Add") {
                                addFilenameCleanupPrefix()
                            }
                            .buttonStyle(.bordered)
                            .disabled(filenameCleanupPrefixDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        if filenameCleanupPrefixes.isEmpty {
                            Text("No filename prefixes are configured.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(filenameCleanupPrefixes, id: \.self) { prefix in
                                HStack(spacing: 8) {
                                    Text(prefix)
                                        .font(.body.monospaced())
                                        .textSelection(.enabled)
                                    Spacer()
                                    Button {
                                        removeFilenameCleanupPrefix(prefix)
                                    } label: {
                                        Label("Remove", systemImage: "minus.circle")
                                    }
                                    .labelStyle(.iconOnly)
                                    .buttonStyle(.borderless)
                                }
                            }
                        }

                        Text("Matching is case-insensitive and literal. Spaces and punctuation are part of the prefix.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                Section("IP Filter") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("https://example.com/ipfilter.dat", text: $model.ipFilterURLInput)
                            .textFieldStyle(.roundedBorder)
                            .disabled(model.isBusy || !model.isBridgeOpSupported("ipfilter-update"))

                        HStack(spacing: 10) {
                            Button("Update") {
                                model.updateIpFilterFromURL(model.ipFilterURLInput)
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.isBusy || !model.isBridgeOpSupported("ipfilter-update"))

                            Button("Reload") {
                                model.reloadIpFilter()
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.isBusy || !model.isBridgeOpSupported("ipfilter-reload"))
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Apply") {
                    model.setConnectionSpeedLimits(
                        maxDL: model.connectionMaxDownloadInput,
                        maxUL: model.connectionMaxUploadInput
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy || !model.isBridgeOpSupported("prefs-connection-set"))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(minWidth: 640, minHeight: 420)
        .background(GlassEffectBackground(material: .underWindowBackground).ignoresSafeArea())
        .background(
            WindowAppearanceConfigurator(
                windowTitle: "Preferences",
                hideTitle: false,
                transparentTitlebar: true,
                fullSizeContentView: true,
                toolbarStyle: .automatic,
                makeWindowTransparent: true,
                ensureToolbarWhenTransparentTitlebar: false
            )
        )
        .task {
            if model.isBridgeOpSupported("prefs-connection-get") {
                model.refreshConnectionPrefs()
            }
        }
    }

    private func limitField(title: String, text: Binding<String>, value: Int, placeholder: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .frame(width: 96, alignment: .leading)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 180)
            Text("KiB/s")
                .foregroundStyle(.secondary)
            Spacer()
            Text("Current: \(value)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func addFilenameCleanupPrefix() {
        filenameCleanupPrefixesRaw = FilenameCleanupPreferences.encode(
            filenameCleanupPrefixes + [filenameCleanupPrefixDraft]
        )
        filenameCleanupPrefixDraft = ""
    }

    private func removeFilenameCleanupPrefix(_ prefix: String) {
        filenameCleanupPrefixesRaw = FilenameCleanupPreferences.encode(
            filenameCleanupPrefixes.filter { $0 != prefix }
        )
    }
}

#if DEBUG
#Preview("Disconnected Preferences") {
    PreferencesWindowView()
        .environmentObject(AppModel.previewDisconnected())
}

#Preview("Connected with Limits") {
    PreferencesWindowView()
        .environmentObject(AppModel.previewWithPreferences())
}
#endif
