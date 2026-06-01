#if canImport(UIKit)
import SwiftUI
import SharedViews

enum AppTab: String, CaseIterable, Identifiable {
    case downloads
    case search
    case servers
    case settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .downloads: return L("Downloads")
        case .search: return L("Search")
        case .servers: return L("Servers")
        case .settings: return L("Settings")
        }
    }

    var systemImage: String {
        switch self {
        case .downloads: return "arrow.down.circle"
        case .search: return "magnifyingglass"
        case .servers: return "server.rack"
        case .settings: return "gearshape"
        }
    }
}

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var model: IOSAppModel
    @State private var selectedTab: AppTab = .downloads
    @State private var presentedIPhoneSheet: AppTab?
    @State private var isConnectionDialogPresented = false
    @State private var connectionHostDraft = ""
    @State private var connectionPortDraft = ""
    @State private var connectionPasswordDraft = ""

    var body: some View {
        Group {
            if rootLayout == .sidebarDetail {
                ipadLayout
            } else {
                iphoneLayout
            }
        }
        .overlay {
            if let feedback = model.downloadFeedback {
                AddLinksHUD(message: feedback)
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .task(id: feedback) {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            if model.downloadFeedback == feedback {
                                model.downloadFeedback = nil
                            }
                        }
                    }
            }
        }
        .onOpenURL { url in
            model.handleOpenURL(url)
        }
        .task {
            model.startLifecycleServices()
        }
        .onDisappear {
            model.stopLifecycleServices()
        }
        .onChange(of: model.isSessionConnected) { _, connected in
            if connected {
                model.flushIncomingLinks()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            model.handleScenePhaseChange(newPhase)
        }
        .alert("aMule Remote Error", isPresented: errorAlertBinding) {
            Button("OK") {
                model.lastError = ""
            }
        } message: {
            Text(model.lastError)
        }
        .alert("Connection", isPresented: $isConnectionDialogPresented) {
            TextField("Host", text: $connectionHostDraft)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            TextField("Port", text: $connectionPortDraft)
                .keyboardType(.numberPad)

            SecureField("Password", text: $connectionPasswordDraft)
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if model.isSessionConnected {
                Button("Disconnect", role: .destructive) {
                    model.disconnect()
                }
            }

            Button(model.isSessionConnected ? "Reconnect" : "Connect") {
                applyConnectionDraftsAndConnect()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(connectionDialogMessage)
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { !model.lastError.isEmpty },
            set: { isPresented in
                if !isPresented {
                    model.lastError = ""
                }
            }
        )
    }

    private var iphoneLayout: some View {
        NavigationStack {
            DownloadsView(
                model: model,
                onShowConnection: showConnectionDialog,
                onShowSearch: { presentedIPhoneSheet = .search },
                onShowServers: { presentedIPhoneSheet = .servers },
                onShowSettings: { presentedIPhoneSheet = .settings }
            )
            .navigationTitle(Text("Downloads"))
        }
        .sheet(item: $presentedIPhoneSheet) { tab in
            NavigationStack {
                detailView(for: tab)
                    .navigationTitle(tab.label)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                presentedIPhoneSheet = nil
                            }
                        }
                    }
            }
        }
    }

    private var ipadLayout: some View {
        NavigationSplitView {
            List(AppTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Label(tab.label, systemImage: tab.systemImage)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("aMule Remote")
        } detail: {
            NavigationStack {
                detailView(for: selectedTab)
            }
        }
    }

    @ViewBuilder
    private func detailView(for tab: AppTab) -> some View {
        switch tab {
        case .downloads:
            DownloadsView(
                model: model,
                presentation: downloadsPresentation,
                onShowConnection: showConnectionDialog
            )
                .navigationTitle(Text("Downloads"))
        case .search:
            SearchView(model: model)
                .navigationTitle(Text("Search"))
        case .servers:
            ServersView(model: model)
                .navigationTitle(Text("Servers"))
        case .settings:
            SettingsView(model: model)
                .navigationTitle(Text("Settings"))
        }
    }

    private var connectionDialogMessage: String {
        if !model.lastError.isEmpty {
            return model.lastError
        }
        return model.isSessionConnected ? L("Connected") : L("Disconnected")
    }

    private var rootLayout: IOSRootLayout {
        IOSLayoutPolicy.rootLayout(device: deviceClass, horizontalSize: sizeClass)
    }

    private var downloadsPresentation: DownloadsViewPresentation {
        IOSLayoutPolicy.downloadsPresentation(device: deviceClass, horizontalSize: sizeClass)
    }

    private var deviceClass: IOSDeviceClass {
        UIDevice.current.userInterfaceIdiom == .pad ? .pad : .phone
    }

    private var sizeClass: IOSHorizontalSize {
        horizontalSizeClass == .regular ? .regular : .compact
    }

    private func showConnectionDialog() {
        connectionHostDraft = model.host
        connectionPortDraft = String(model.port)
        connectionPasswordDraft = model.password
        isConnectionDialogPresented = true
    }

    private func applyConnectionDraftsAndConnect() {
        let trimmedHost = connectionHostDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let port = Int(connectionPortDraft.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            model.lastError = L("Invalid port. Enter a value between 1 and 65535.")
            return
        }
        model.host = trimmedHost
        model.port = port
        model.password = connectionPasswordDraft
        model.connect()
    }
}

#Preview {
    ContentView(model: IOSAppModel())
}
#endif
