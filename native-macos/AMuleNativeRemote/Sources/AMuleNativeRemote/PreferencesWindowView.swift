import SwiftUI
import AppKit
import SharedViews
import SharedModels
import SharedServices

enum PreferenceTab: CaseIterable, Identifiable, Hashable {
    case connection
    case files
    case servers
    case security
    case remote
    case interface
    case maintenance

    static let representativeRenderTabs: [PreferenceTab] = [
        .connection,
        .files,
        .interface,
        .maintenance
    ]

    var id: Self { self }

    var title: String {
        switch self {
        case .connection:
            return L("Connection")
        case .files:
            return L("Files")
        case .servers:
            return L("Servers")
        case .security:
            return L("Security")
        case .remote:
            return L("Remote")
        case .interface:
            return L("Interface")
        case .maintenance:
            return L("Maintenance")
        }
    }

    var systemImage: String {
        switch self {
        case .connection:
            return "network"
        case .files:
            return "folder"
        case .servers:
            return "server.rack"
        case .security:
            return "lock.shield"
        case .remote:
            return "globe"
        case .interface:
            return "sidebar.left"
        case .maintenance:
            return "wrench.and.screwdriver"
        }
    }

    var evidenceName: String {
        switch self {
        case .connection:
            return "connection"
        case .files:
            return "files"
        case .servers:
            return "servers"
        case .security:
            return "security"
        case .remote:
            return "remote"
        case .interface:
            return "interface"
        case .maintenance:
            return "maintenance"
        }
    }
}

struct PreferencesWindowView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage(FilenameCleanupPreferences.storageKey) private var filenameCleanupPrefixesRaw = "[]"
    @AppStorage("amule.ui.showCategoriesPage") private var showCategoriesPage = true
    @AppStorage("amule.ui.showFriendsPage") private var showFriendsPage = true
    @AppStorage("amule.ui.showUploadsPage") private var showUploadsPage = true
    @State private var selectedTab: PreferenceTab
    @State private var filenameCleanupPrefixDraft = ""

    init(initialTab: PreferenceTab = .connection) {
        _selectedTab = State(initialValue: initialTab)
    }

    private var filenameCleanupPrefixes: [String] {
        FilenameCleanupPreferences.decode(filenameCleanupPrefixesRaw)
    }

    var body: some View {
        selectedSection
        .frame(width: 700, height: 560)
        .scenePadding()
        .background {
            Color(nsColor: .windowBackgroundColor)
            PreferenceWindowConfigurator(selectedTab: $selectedTab)
        }
        .task {
            if model.isBridgeOpSupported("prefs-connection-get") {
                model.refreshConnectionPrefs()
            }
        }
    }

    @ViewBuilder
    private var selectedSection: some View {
        switch selectedTab {
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
        case .interface:
            interfaceSection
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
            } header: {
                Text(L("Transfer Limits"))
            } footer: {
                Text(L("Values are in KiB/s. Use 0 for unlimited speed."))
            }

            Section {
                preferenceTextField("TCP port", text: $model.connectionTCPPortInput, placeholder: "4662")
                preferenceTextField("UDP port", text: $model.connectionUDPPortInput, placeholder: "4672")
                Toggle(L("UDP enabled"), isOn: $model.connectionUDPEnabled)
                Toggle(L("ED2K network"), isOn: $model.connectionED2KEnabled)
                Toggle(L("Kademlia network"), isOn: $model.connectionKADEnabled)
            } header: {
                Text(L("Networks"))
            } footer: {
                Text(L("These values are read from and written to the daemon connection preferences."))
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
                Toggle(L("Save sources"), isOn: $model.saveSources)
                Toggle(L("Extract metadata"), isOn: $model.extractMetadata)
            } header: {
                Text(L("New Downloads"))
            }

            Section {
                Toggle(L("Auto upload priority"), isOn: $model.autoUploadPriority)
                Toggle(L("Allocate full file size"), isOn: $model.allocateFullFileSize)
                Toggle(L("Check free space"), isOn: $model.checkFreeSpace)
                preferenceTextField("Min free space MB", text: $model.minFreeDiskSpaceInput, placeholder: "0")
                Toggle(L("Create sparse files"), isOn: $model.createSparseFiles)
            } header: {
                Text(L("Storage"))
            } footer: {
                Text(L("Sparse files and free-space checks apply when the daemon creates temporary part files."))
            }

            Section {
                applyButton("Apply File Preferences") {
                    model.setFilePrefs()
                }
            } header: {
                Text(L("Apply"))
            }
        }
        .formStyle(.grouped)
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
            } header: {
                Text(L("Server List Updates"))
            }

            Section {
                Toggle(L("Use priority system"), isOn: $model.useServerPrioritySystem)
                Toggle(L("Smart low ID check"), isOn: $model.smartIDCheck)
                Toggle(L("Safe server connect"), isOn: $model.safeServerConnect)
                Toggle(L("Auto-connect static only"), isOn: $model.autoConnectStaticOnly)
                Toggle(L("Manual high priority"), isOn: $model.manualHighPriority)
            } header: {
                Text(L("Connection Policy"))
            }

            Section {
                applyButton("Apply Servers") {
                    model.setServersPrefs()
                }
            } header: {
                Text(L("Apply"))
            }
        }
        .formStyle(.grouped)
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
            } header: {
                Text(L("IP Filtering"))
            }

            Section {
                Toggle(L("Secure identification"), isOn: $model.secureIdentEnabled)
                Toggle(L("Obfuscation supported"), isOn: $model.obfuscationSupported)
                Toggle(L("Obfuscation requested"), isOn: $model.obfuscationRequested)
                Toggle(L("Obfuscation required"), isOn: $model.obfuscationRequired)
            } header: {
                Text(L("Protocol Protection"))
            }

            Section {
                applyButton("Apply Security") {
                    model.setSecurityPrefs()
                }
            } header: {
                Text(L("Apply"))
            }
        }
        .formStyle(.grouped)
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
                Text(L("Statistics display preferences are not exposed by amuled remote preferences."))
                    .foregroundStyle(.secondary)
                Text(L("Graph update interval and display limits remain app-side presentation choices."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(L("Statistics"))
            }
        }
        .formStyle(.grouped)
    }

    private var interfaceSection: some View {
        Form {
            Section {
                Toggle(L("Show Uploads page"), isOn: $showUploadsPage)
                Toggle(L("Show Categories page"), isOn: $showCategoriesPage)
                Toggle(L("Show Friends page"), isOn: $showFriendsPage)
            } header: {
                Text(L("Sidebar Pages"))
            } footer: {
                Text(L("Hide pages that are not useful for this daemon. The selection is local to this app."))
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Maintenance

    private var maintenanceSection: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Text(L("Prefix to remove"))
                    Spacer(minLength: 24)
                    TextField(L("Prefix to remove"), text: $filenameCleanupPrefixDraft)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .frame(width: 240)
                    Button(L("Add")) {
                        addFilenameCleanupPrefix()
                    }
                    .buttonStyle(.bordered)
                    .disabled(filenameCleanupPrefixDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                HStack(spacing: 12) {
                    Text(L("IP filter URL"))
                    Spacer(minLength: 24)
                    TextField("https://example.com/ipfilter.dat", text: $model.ipFilterURLInput)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .frame(width: 280)
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
    }

    // MARK: - Helpers

    private func limitField(title: String, text: Binding<String>, value: Int, placeholder: String) -> some View {
        HStack(spacing: 12) {
            Text(L(title))
            Spacer(minLength: 24)
            HStack {
                TextField(placeholder, text: text)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
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
        HStack(spacing: 12) {
            Text(L(title))
            Spacer(minLength: 24)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .frame(width: 280)
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

private struct PreferenceWindowConfigurator: NSViewRepresentable {
    @Binding var selectedTab: PreferenceTab

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configure(window: view.window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.selectedTab = $selectedTab
        DispatchQueue.main.async {
            configure(window: view.window, coordinator: context.coordinator)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedTab: $selectedTab)
    }

    private func configure(window: NSWindow?, coordinator: Coordinator) {
        guard let window else { return }
        let toolbar: NSToolbar
        if let existingToolbar = window.toolbar,
           existingToolbar.identifier == Coordinator.toolbarIdentifier {
            toolbar = existingToolbar
        } else {
            toolbar = NSToolbar(identifier: Coordinator.toolbarIdentifier)
            toolbar.delegate = coordinator
            toolbar.allowsUserCustomization = false
            toolbar.autosavesConfiguration = false
            toolbar.sizeMode = .regular
            window.toolbar = toolbar
        }

        toolbar.delegate = coordinator
        toolbar.selectedItemIdentifier = selectedTab.toolbarItemIdentifier
        toolbar.displayMode = .iconAndLabel
        toolbar.sizeMode = .regular
        toolbar.allowsUserCustomization = false
        window.toolbarStyle = .preference
        window.toolbar?.displayMode = .iconAndLabel
        window.toolbar?.sizeMode = .regular
        window.toolbar?.allowsUserCustomization = false
    }

    final class Coordinator: NSObject, NSToolbarDelegate {
        static let toolbarIdentifier = NSToolbar.Identifier("AMulePreferencesToolbar")
        var selectedTab: Binding<PreferenceTab>

        init(selectedTab: Binding<PreferenceTab>) {
            self.selectedTab = selectedTab
        }

        func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            PreferenceTab.allCases.map(\.toolbarItemIdentifier)
        }

        func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            PreferenceTab.allCases.map(\.toolbarItemIdentifier)
        }

        func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            PreferenceTab.allCases.map(\.toolbarItemIdentifier)
        }

        func toolbar(
            _ toolbar: NSToolbar,
            itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
            willBeInsertedIntoToolbar flag: Bool
        ) -> NSToolbarItem? {
            guard let tab = PreferenceTab(toolbarItemIdentifier: itemIdentifier) else { return nil }
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = tab.title
            item.paletteLabel = tab.title
            item.toolTip = tab.title
            item.image = NSImage(systemSymbolName: tab.systemImage, accessibilityDescription: tab.title)
            item.target = self
            item.action = #selector(selectPreferenceTab(_:))
            return item
        }

        @MainActor
        @objc private func selectPreferenceTab(_ sender: NSToolbarItem) {
            guard let tab = PreferenceTab(toolbarItemIdentifier: sender.itemIdentifier) else { return }
            selectedTab.wrappedValue = tab
        }
    }
}

private extension PreferenceTab {
    var toolbarItemIdentifier: NSToolbarItem.Identifier {
        NSToolbarItem.Identifier("AMulePreferencesToolbar.\(evidenceName)")
    }

    init?(toolbarItemIdentifier: NSToolbarItem.Identifier) {
        guard let tab = Self.allCases.first(where: { $0.toolbarItemIdentifier == toolbarItemIdentifier }) else {
            return nil
        }
        self = tab
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
