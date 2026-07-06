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
                Section("Connection") {
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
                        preferenceTextField("TCP port", text: $model.connectionTCPPortInput, placeholder: "4662")
                        preferenceTextField("UDP port", text: $model.connectionUDPPortInput, placeholder: "4672")
                        Toggle("UDP enabled", isOn: $model.connectionUDPEnabled)
                        Toggle("ED2K network", isOn: $model.connectionED2KEnabled)
                        Toggle("Kademlia network", isOn: $model.connectionKADEnabled)
                        Text("Values are in KiB/s. Use 0 for unlimited speed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        applyButton("Apply Connection") {
                            model.setConnectionSpeedLimits(
                                maxDL: model.connectionMaxDownloadInput,
                                maxUL: model.connectionMaxUploadInput
                            )
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Directories and Files") {
                    VStack(alignment: .leading, spacing: 12) {
                        preferenceTextField("Incoming", text: $model.incomingDirectoryInput, placeholder: "/path/to/incoming")
                        preferenceTextField("Temp", text: $model.tempDirectoryInput, placeholder: "/path/to/temp")
                        Toggle("Share hidden files", isOn: $model.shareHiddenFiles)
                        Text("Shared directories")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $model.sharedDirectoriesInput)
                            .font(.body.monospaced())
                            .frame(minHeight: 72)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.secondary.opacity(0.25))
                            )
                        applyButton("Apply Directories") {
                            model.setDirectoriesPrefs(
                                incoming: model.incomingDirectoryInput,
                                temp: model.tempDirectoryInput,
                                sharedDirectories: model.sharedDirectoriesInput
                            )
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Servers") {
                    VStack(alignment: .leading, spacing: 12) {
                        preferenceTextField("server.met URL", text: $model.serverUpdateURLInput, placeholder: "https://example.com/server.met")
                        preferenceTextField("Dead retries", text: $model.deadServerRetriesInput, placeholder: "3")
                        Toggle("Auto-update server list", isOn: $model.autoUpdateServers)
                        Toggle("Remove dead servers", isOn: $model.removeDeadServers)
                        Toggle("Add servers from servers", isOn: $model.addServersFromServer)
                        Toggle("Add servers from clients", isOn: $model.addServersFromClient)
                        Toggle("Use priority system", isOn: $model.useServerPrioritySystem)
                        Toggle("Smart low ID check", isOn: $model.smartIDCheck)
                        Toggle("Safe server connect", isOn: $model.safeServerConnect)
                        Toggle("Auto-connect static only", isOn: $model.autoConnectStaticOnly)
                        Toggle("Manual high priority", isOn: $model.manualHighPriority)
                        applyButton("Apply Servers") {
                            model.setServersPrefs()
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Security") {
                    VStack(alignment: .leading, spacing: 12) {
                        preferenceTextField("IP filter level", text: $model.ipFilterLevelInput, placeholder: "127")
                        preferenceTextField("IP filter URL", text: $model.ipFilterUpdateURLInput, placeholder: "https://example.com/ipfilter.dat")
                        Toggle("Filter clients", isOn: $model.filterClients)
                        Toggle("Filter servers", isOn: $model.filterServers)
                        Toggle("Auto-update IP filter", isOn: $model.ipFilterAutoUpdate)
                        Toggle("Filter LAN IPs", isOn: $model.filterLanIPs)
                        Toggle("Secure identification", isOn: $model.secureIdentEnabled)
                        Toggle("Obfuscation supported", isOn: $model.obfuscationSupported)
                        Toggle("Obfuscation requested", isOn: $model.obfuscationRequested)
                        Toggle("Obfuscation required", isOn: $model.obfuscationRequired)
                        applyButton("Apply Security") {
                            model.setSecurityPrefs()
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Remote Controls") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Webserver enabled", isOn: $model.webServerEnabled)
                        preferenceTextField("Webserver port", text: $model.webServerPortInput, placeholder: "4711")
                        Toggle("Guest user enabled", isOn: $model.webServerGuestEnabled)
                        Toggle("Use gzip", isOn: $model.webServerUseGzip)
                        preferenceTextField("Refresh seconds", text: $model.webServerRefreshInput, placeholder: "120")
                        preferenceTextField("Template", text: $model.webServerTemplateInput, placeholder: "default")
                        Text("External connection password and auth hashes are not exposed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        applyButton("Apply Remote Controls") {
                            model.setRemoteControlPrefs()
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Statistics") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Remote preference support", isOn: $model.remotePrefsStatisticsSupported)
                            .disabled(true)
                        Text("Graph update interval and display limits are not present in the upstream remote preferences packet.")
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
        }
        .frame(minWidth: 720, minHeight: 620)
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

    private func preferenceTextField(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .frame(width: 136, alignment: .leading)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 360)
            Spacer()
        }
    }

    private func applyButton(_ title: String, action: @escaping () -> Void) -> some View {
        HStack {
            Spacer()
            Button(title, action: action)
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy || !model.isBridgeOpSupported("prefs-connection-set"))
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
