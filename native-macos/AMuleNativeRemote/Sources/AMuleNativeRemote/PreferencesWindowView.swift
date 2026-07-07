import SwiftUI
import AppKit
import SharedViews
import SharedModels
import SharedServices

struct PreferencesWindowView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage(FilenameCleanupPreferences.storageKey) private var filenameCleanupPrefixesRaw = "[]"
    @State private var filenameCleanupPrefixDraft = ""
    @State private var selectedSection: PreferencesSection = .connection

    private var filenameCleanupPrefixes: [String] {
        FilenameCleanupPreferences.decode(filenameCleanupPrefixesRaw)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                ForEach(PreferencesSection.allCases) { section in
                    Label(section.localizedTitle, systemImage: section.symbolName)
                        .tag(section)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 240)
        } detail: {
            detailView
        }
        .task {
            if model.isBridgeOpSupported("prefs-connection-get") {
                model.refreshConnectionPrefs()
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedSection {
        case .connection:
            connectionSection
        case .files:
            filesSection
        case .servers:
            serversSection
        case .security:
            securitySection
        case .remote:
            remoteSection
        case .maintenance:
            maintenanceSection
        }
    }

    // MARK: - Connection

    private var connectionSection: some View {
        Form {
            Section {
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
                Toggle(L("UDP enabled"), isOn: $model.connectionUDPEnabled)
                Toggle(L("ED2K network"), isOn: $model.connectionED2KEnabled)
                Toggle(L("Kademlia network"), isOn: $model.connectionKADEnabled)
            } header: {
                Text(L("Bandwidth and Networks"))
            } footer: {
                Text(L("Values are in KiB/s. Use 0 for unlimited speed."))
            }

            Section {
                applyButton("Apply Connection") {
                    model.setConnectionSpeedLimits(
                        maxDL: model.connectionMaxDownloadInput,
                        maxUL: model.connectionMaxUploadInput
                    )
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L("Connection"))
    }

    // MARK: - Files

    private var filesSection: some View {
        Form {
            Section {
                preferenceTextField("Incoming", text: $model.incomingDirectoryInput, placeholder: "/path/to/incoming")
                preferenceTextField("Temp", text: $model.tempDirectoryInput, placeholder: "/path/to/temp")
                Toggle(L("Share hidden files"), isOn: $model.shareHiddenFiles)
            } header: {
                Text(L("Directories"))
            }

            Section {
                TextEditor(text: $model.sharedDirectoriesInput)
                    .font(.body.monospaced())
                    .frame(minHeight: 96)
                applyButton("Apply Directories") {
                    model.setDirectoriesPrefs(
                        incoming: model.incomingDirectoryInput,
                        temp: model.tempDirectoryInput,
                        sharedDirectories: model.sharedDirectoriesInput
                    )
                }
            } header: {
                Text(L("Shared directories"))
            } footer: {
                Text(L("One directory per line."))
            }

            Section {
                Toggle(L("Pause new files"), isOn: $model.newFilesPaused)
                Toggle(L("Auto download priority"), isOn: $model.autoDownloadPriority)
                Toggle(L("Preview priority"), isOn: $model.previewPriority)
                Toggle(L("Auto upload priority"), isOn: $model.autoUploadPriority)
                Toggle(L("Save sources"), isOn: $model.saveSources)
                Toggle(L("Extract metadata"), isOn: $model.extractMetadata)
                Toggle(L("Allocate full file size"), isOn: $model.allocateFullFileSize)
                Toggle(L("Check free space"), isOn: $model.checkFreeSpace)
                preferenceTextField("Min free space MB", text: $model.minFreeDiskSpaceInput, placeholder: "0")
                Toggle(L("Create sparse files"), isOn: $model.createSparseFiles)
                applyButton("Apply File Preferences") {
                    model.setFilePrefs()
                }
            } header: {
                Text(L("File behavior"))
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L("Files"))
    }

    // MARK: - Servers

    private var serversSection: some View {
        Form {
            Section {
                preferenceTextField("server.met URL", text: $model.serverUpdateURLInput, placeholder: "https://example.com/server.met")
                preferenceTextField("Dead retries", text: $model.deadServerRetriesInput, placeholder: "3")
                Toggle(L("Auto-update server list"), isOn: $model.autoUpdateServers)
                Toggle(L("Remove dead servers"), isOn: $model.removeDeadServers)
                Toggle(L("Add servers from servers"), isOn: $model.addServersFromServer)
                Toggle(L("Add servers from clients"), isOn: $model.addServersFromClient)
                Toggle(L("Use priority system"), isOn: $model.useServerPrioritySystem)
                Toggle(L("Smart low ID check"), isOn: $model.smartIDCheck)
                Toggle(L("Safe server connect"), isOn: $model.safeServerConnect)
                Toggle(L("Auto-connect static only"), isOn: $model.autoConnectStaticOnly)
                Toggle(L("Manual high priority"), isOn: $model.manualHighPriority)
                applyButton("Apply Servers") {
                    model.setServersPrefs()
                }
            } header: {
                Text(L("Server list options"))
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L("Servers"))
    }

    // MARK: - Security

    private var securitySection: some View {
        Form {
            Section {
                preferenceTextField("IP filter level", text: $model.ipFilterLevelInput, placeholder: "127")
                preferenceTextField("IP filter URL", text: $model.ipFilterUpdateURLInput, placeholder: "https://example.com/ipfilter.dat")
                Toggle(L("Filter clients"), isOn: $model.filterClients)
                Toggle(L("Filter servers"), isOn: $model.filterServers)
                Toggle(L("Auto-update IP filter"), isOn: $model.ipFilterAutoUpdate)
                Toggle(L("Filter LAN IPs"), isOn: $model.filterLanIPs)
                Toggle(L("Secure identification"), isOn: $model.secureIdentEnabled)
                Toggle(L("Obfuscation supported"), isOn: $model.obfuscationSupported)
                Toggle(L("Obfuscation requested"), isOn: $model.obfuscationRequested)
                Toggle(L("Obfuscation required"), isOn: $model.obfuscationRequired)
                applyButton("Apply Security") {
                    model.setSecurityPrefs()
                }
            } header: {
                Text(L("Filters and obfuscation"))
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L("Security"))
    }

    // MARK: - Remote

    private var remoteSection: some View {
        Form {
            Section {
                Toggle(L("Webserver enabled"), isOn: $model.webServerEnabled)
                preferenceTextField("Webserver port", text: $model.webServerPortInput, placeholder: "4711")
                Toggle(L("Guest user enabled"), isOn: $model.webServerGuestEnabled)
                Toggle(L("Use gzip"), isOn: $model.webServerUseGzip)
                preferenceTextField("Refresh seconds", text: $model.webServerRefreshInput, placeholder: "120")
                preferenceTextField("Template", text: $model.webServerTemplateInput, placeholder: "default")
                applyButton("Apply Remote Controls") {
                    model.setRemoteControlPrefs()
                }
            } header: {
                Text(L("Webserver settings"))
            } footer: {
                Text(L("External connection password and auth hashes are not exposed."))
            }

            Section {
                Text(L("Remote preference support is not configurable."))
                    .foregroundStyle(.secondary)
                Text(L("Graph update interval and display limits are not present in the upstream remote preferences packet."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(L("Statistics"))
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L("Remote"))
    }

    // MARK: - Maintenance

    private var maintenanceSection: some View {
        Form {
            Section {
                LabeledContent(L("Prefix to remove")) {
                    HStack {
                        TextField(L("Prefix to remove"), text: $filenameCleanupPrefixDraft)
                            .textFieldStyle(.roundedBorder)
                        Button(L("Add")) {
                            addFilenameCleanupPrefix()
                        }
                        .buttonStyle(.bordered)
                        .disabled(filenameCleanupPrefixDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if filenameCleanupPrefixes.isEmpty {
                    Text(L("No filename prefixes are configured."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filenameCleanupPrefixes, id: \.self) { prefix in
                        LabeledContent(prefix) {
                            Button {
                                removeFilenameCleanupPrefix(prefix)
                            } label: {
                                Label(L("Remove"), systemImage: "minus.circle")
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                        }
                    }
                }
            } header: {
                Text(L("Filename Cleanup"))
            } footer: {
                Text(L("Matching is case-insensitive and literal. Spaces and punctuation are part of the prefix."))
            }

            Section {
                LabeledContent(L("IP filter URL")) {
                    TextField("https://example.com/ipfilter.dat", text: $model.ipFilterURLInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 360)
                        .disabled(model.isBusy || !model.isBridgeOpSupported("ipfilter-update"))
                }

                HStack {
                    Button(L("Update")) {
                        model.updateIpFilterFromURL(model.ipFilterURLInput)
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isBusy || !model.isBridgeOpSupported("ipfilter-update"))

                    Button(L("Reload")) {
                        model.reloadIpFilter()
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isBusy || !model.isBridgeOpSupported("ipfilter-reload"))
                }
            } header: {
                Text(L("IP Filter"))
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L("Maintenance"))
    }

    // MARK: - Helpers

    private func limitField(title: String, text: Binding<String>, value: Int, placeholder: String) -> some View {
        LabeledContent(L(title)) {
            HStack {
                TextField(placeholder, text: text)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                Text(L("KiB/s"))
                    .foregroundStyle(.secondary)
                Text(LF("Current: %d", value))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func preferenceTextField(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        LabeledContent(L(title)) {
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 360)
        }
    }

    private func applyButton(_ title: String, action: @escaping () -> Void) -> some View {
        HStack {
            Spacer()
            Button(L(title), action: action)
                .buttonStyle(.bordered)
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

// MARK: - Sidebar Sections

private enum PreferencesSection: String, CaseIterable, Identifiable, Hashable {
    case connection
    case files
    case servers
    case security
    case remote
    case maintenance

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .connection: return L("Connection")
        case .files: return L("Files")
        case .servers: return L("Servers")
        case .security: return L("Security")
        case .remote: return L("Remote")
        case .maintenance: return L("Maintenance")
        }
    }

    var symbolName: String {
        switch self {
        case .connection: return "network"
        case .files: return "folder"
        case .servers: return "server.rack"
        case .security: return "lock.shield"
        case .remote: return "globe"
        case .maintenance: return "wrench.and.screwdriver"
        }
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