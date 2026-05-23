import SwiftUI
import SharedUI

#if canImport(UIKit)

/// iOS-native downloads view using TabView navigation and shared UI components.
/// This view consumes shared components (DownloadRowContent, ConnectionStateIndicator,
/// MetricChipView, EmptyStateView, etc.) while using iOS-native navigation patterns.
struct IOSDownloadsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedTab = 0
    @State private var addLinksDraft = ""
    @State private var showAddLinksSheet = false
    @State private var showLoginSheet = false
    @State private var showKadSheet = false
    @State private var kadNodesURL = "http://upd.emule-security.org/nodes.dat"

    private enum DownloadFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case downloading = "Downloading"
        case pending = "Pending"
        case paused = "Paused"
        case completed = "Completed"

        var id: String { rawValue }

        var localizedTitle: String { NSLocalizedString(rawValue, comment: "") }

        var symbolName: String {
            switch self {
            case .all: return "tray.full"
            case .downloading: return "arrow.down"
            case .pending: return "clock"
            case .paused: return "pause"
            case .completed: return "checkmark"
            }
        }
    }

    var body: some View {
        NavigationStack {
            downloadList
                .navigationTitle("Downloads")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showAddLinksSheet = true
                        } label: {
                            Label("Add Links", systemImage: "plus")
                        }
                        .disabled(model.isBusy)
                    }
                }
                .sheet(isPresented: $showAddLinksSheet) {
                    NavigationStack {
                        LinkImportPanelContent(
                            draft: $addLinksDraft,
                            isBusy: model.isBusy,
                            onImport: {
                                model.addLinks(addLinksDraft)
                                showAddLinksSheet = false
                            },
                            onClear: { addLinksDraft = "" }
                        )
                        .padding(16)
                        .navigationTitle("Add eD2k Links")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showAddLinksSheet = false }
                            }
                        }
                    }
                }
                .sheet(isPresented: $showLoginSheet) {
                    NavigationStack {
                        ConnectionPanelContent(
                            host: $model.host,
                            port: $model.port,
                            password: $model.password,
                            isConnected: model.isSessionConnected,
                            isBusy: model.isBusy,
                            onConnect: { model.connectAll() },
                            onDisconnect: { model.disconnectAll() },
                            onClose: { showLoginSheet = false }
                        )
                        .padding(16)
                        .navigationTitle("Connect")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                }
                .sheet(isPresented: $showKadSheet) {
                    NavigationStack {
                        KadPanelContent(
                            nodesURL: $kadNodesURL,
                            kadStatusText: ConnectionStateLocalizer.localizedText(for: ConnectionStateParser.parse(model.status.kad)),
                            kadConnectionState: ConnectionStateParser.parse(model.status.kad),
                            isRefreshing: false,
                            isBusy: model.isBusy,
                            onRefresh: { Task { await model.refreshStatus(logOutput: false, suppressErrors: true) } },
                            onUpdateNodes: { model.updateKadNodesFromURL(kadNodesURL) },
                            onClose: { showKadSheet = false }
                        )
                        .padding(16)
                        .navigationTitle("Kad")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                }
        }
        .onAppear {
            model.setDownloadAutoRefreshEnabled(true)
        }
        .onDisappear {
            model.setDownloadAutoRefreshEnabled(false)
        }
        .task {
            model.ensurePreferredBridgePath()
            await model.refreshBridgeCapabilities(logOutput: false, suppressErrors: true)
            model.startAutoRefresh()
            await model.refreshStatus(logOutput: false, suppressErrors: true)
            model.refreshDownloads()
            model.refreshServers()
            showLoginSheet = !model.isSessionConnected
            model.flushIncomingLinksIfAny()
        }
        .onChange(of: model.isSessionConnected) { _, connected in
            if connected {
                showLoginSheet = false
                model.flushIncomingLinksIfAny()
            }
        }
        .onChange(of: model.addLinksPanelRequestID) {
            showAddLinksSheet = true
        }
    }

    private var downloadList: some View {
        Group {
            if filteredDownloads.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: "No Downloads",
                    subtitle: filterSubtitle
                )
            } else {
                List(filteredDownloads) { item in
                    NavigationLink(value: item) {
                        DownloadRowContent(
                            item: item,
                            name: item.name,
                            progressText: item.progressText,
                            speedText: item.speedBytes > 0 ? item.speedText : "",
                            sourcesText: item.sourcesText,
                            progressColors: item.progressColors,
                            progressDisplayValue: item.progressDisplayValue
                        )
                    }
                }
            }
        }
    }

    private var filteredDownloads: [DownloadItem] {
        let filtered: [DownloadItem]
        switch selectedTab {
        case 0: filtered = model.downloads
        case 1: filtered = model.downloads.filter { DownloadClassification.isDownloading($0) }
        case 2: filtered = model.downloads.filter { DownloadClassification.isPending($0) }
        case 3: filtered = model.downloads.filter { DownloadClassification.isPaused($0) }
        case 4: filtered = model.downloads.filter { DownloadClassification.isCompleted($0) }
        default: filtered = model.downloads
        }
        return filtered
    }

    private var filterSubtitle: String {
        switch selectedTab {
        case 0: return "Downloads will appear here"
        case 1: return "Active downloads will appear here"
        case 2: return "Queued downloads will appear here"
        case 3: return "Paused downloads will appear here"
        case 4: return "Completed downloads will appear here"
        default: return ""
        }
    }
}

/// iOS-native connection status footer using shared components.
struct IOSConnectionFooter: View {
    @EnvironmentObject private var model: AppModel
    let onServerTap: () -> Void
    let onEd2kTap: () -> Void
    let onKadTap: () -> Void

    var body: some View {
        ConnectionFooterBar(
            serverState: model.isSessionConnected ? .connected : .disconnected,
            ed2kState: ConnectionStateParser.parse(model.status.ed2k),
            kadState: ConnectionStateParser.parse(model.status.kad),
            ed2kStatusText: ED2kBadgeFormatter.compactBadgeValue(model.status.ed2k),
            downloadSpeed: model.status.downloadSpeed,
            uploadSpeed: model.status.uploadSpeed,
            onServerTap: onServerTap,
            onEd2kTap: onEd2kTap,
            onKadTap: onKadTap
        )
    }
}

#endif