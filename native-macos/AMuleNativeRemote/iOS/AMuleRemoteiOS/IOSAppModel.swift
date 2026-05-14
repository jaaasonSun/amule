#if canImport(UIKit)
import SwiftUI
import AMuleRemoteIOSShared

struct UserServer: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let ip: String
    let port: Int

    init(id: UUID = UUID(), name: String, ip: String, port: Int) {
        self.id = id
        self.name = name
        self.ip = ip
        self.port = port
    }

    var endpointText: String {
        port > 0 ? "\(ip):\(port)" : ip
    }
}

@MainActor
final class IOSAppModel: ObservableObject {
    @AppStorage("amule.host") var host: String = "127.0.0.1"
    @AppStorage("amule.port") var port: Int = 4712
    @Published var password: String {
        didSet {
            persistPassword()
        }
    }

    @Published var isSessionConnected = false
    @Published var isBusy = false
    @Published var lastError = ""
    @Published var status = StatusSnapshot()
    @Published var downloads: [DownloadItem] = []
    @Published var searchResults: [SearchResult] = []
    @Published var searchProgress = 0
    @Published var isSearchInProgress = false
    @Published var searchScope: String = "kad"
    @Published var servers: [ServerItem] = []
    @Published var bridgeOps: Set<String> = []
    @Published var bridgeVersion: String = ""
    @Published var bridgeClientName: String = ""
    @Published var bridgeDefaultHost: String = ""
    @Published var bridgeDefaultPort: Int = 0
    @Published var connectedServerId: Int?
    @Published var downloadSourcesByHash: [String: [DownloadSourceItem]] = [:]
    @Published var isRefreshingSources = false
    @Published var uploadLimitKBps: Int = 0
    @Published var downloadLimitKBps: Int = 0
    @Published var downloadFeedback: String?
    @Published var userServers: [UserServer] = []

    private let bridge: BridgeProtocol
    private let credentialStorage: CredentialStorage
    private let deepLinkHandler: IOSDeepLinkHandler
    private let appLifecycle: AppLifecycleProtocol
    private let localNetworkErrors: LocalNetworkErrorPresentation
    private let pasteboardShare: PasteboardShare
    private let shareSheetPresenter: ShareSheetPresenting
    private let passwordStorageKey = "amule.password"
    private let userServersStorageKey = "amule.user-servers"
    private var autoRefreshTask: Task<Void, Never>?

    var config: AMuleConnectionConfig {
        .init(bridgePath: "", host: host, port: port, password: password)
    }

    init(
        bridge: BridgeProtocol = platformDefaultBridgeAdapter(),
        credentialStorage: CredentialStorage = platformDefaultCredentialStorage(),
        deepLinkHandler: IOSDeepLinkHandler = platformDefaultDeepLinkHandler() as! IOSDeepLinkHandler,
        appLifecycle: AppLifecycleProtocol = platformDefaultAppLifecycleService(),
        localNetworkErrors: LocalNetworkErrorPresentation = platformDefaultLocalNetworkErrorPresentation(),
        pasteboardShare: PasteboardShare = platformDefaultPasteboardShare(),
        shareSheetPresenter: ShareSheetPresenting = IOSShareSheetPresenter()
    ) {
        self.bridge = bridge
        self.credentialStorage = credentialStorage
        self.deepLinkHandler = deepLinkHandler
        self.appLifecycle = appLifecycle
        self.localNetworkErrors = localNetworkErrors
        self.pasteboardShare = pasteboardShare
        self.shareSheetPresenter = shareSheetPresenter
        self.password = credentialStorage.readCredential(forKey: passwordStorageKey) ?? ""
        loadUserServers()
    }

    func startLifecycleServices() {
        appLifecycle.start()
    }

    func stopLifecycleServices() {
        appLifecycle.stop()
        stopAutoRefresh()
    }

    func connect() {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty else {
            lastError = "Host is required."
            isSessionConnected = false
            return
        }

        guard (1...65535).contains(port) else {
            lastError = "Invalid port. Enter a value between 1 and 65535."
            isSessionConnected = false
            return
        }

        host = trimmedHost
        isBusy = true
        lastError = ""
        Task {
            do {
                let _ = try await bridge.connect(config: config)
                let (_, capabilities, _) = try await bridge.capabilities(config: config)
                let (bridgeStatus, _) = try await bridge.status(config: config)
                let (downloadPayloads, _) = try await bridge.downloads(config: config)
await MainActor.run {
                    self.isSessionConnected = true
                    self.bridgeOps = Set(capabilities.ops)
                    self.bridgeVersion = capabilities.bridgeVersion
                    self.bridgeClientName = capabilities.clientName
                    self.bridgeDefaultHost = capabilities.defaultHost
                    self.bridgeDefaultPort = capabilities.defaultPort
                    self.status = StatusSnapshot.fromBridge(bridgeStatus)
                    self.downloads = DownloadItem.fromBridge(downloadPayloads)
                    self.isBusy = false
                    self.startAutoRefresh()
                    self.flushIncomingLinks()
                    self.fetchTransferLimits()
                }
            } catch {
                await MainActor.run {
                    self.lastError = self.localNetworkErrors.userFacingMessage(for: error)
                    self.isSessionConnected = false
                    self.isBusy = false
                    self.stopAutoRefresh()
                }
            }
        }
    }

    func disconnect() {
        isBusy = true
        Task {
            do {
                let _ = try await bridge.disconnect(config: config)
                await MainActor.run {
                    self.isSessionConnected = false
                    self.bridgeOps = []
                    self.bridgeVersion = ""
                    self.bridgeClientName = ""
                    self.bridgeDefaultHost = ""
                    self.bridgeDefaultPort = 0
                    self.status = StatusSnapshot()
                    self.bridgeOps = []
                    self.bridgeVersion = ""
                    self.bridgeClientName = ""
                    self.bridgeDefaultHost = ""
                    self.bridgeDefaultPort = 0
                    self.isBusy = false
                    self.stopAutoRefresh()
                }
            } catch {
                await MainActor.run {
                    self.lastError = self.localNetworkErrors.userFacingMessage(for: error)
                    self.isBusy = false
                }
            }
        }
    }

    func refreshStatus() {
        Task {
            do {
                let (bridgeStatus, _) = try await bridge.status(config: config)
                await MainActor.run {
                    self.status = StatusSnapshot.fromBridge(bridgeStatus)
                    self.isSessionConnected = bridgeStatus.connected
                    if !bridgeStatus.connected {
                        self.stopAutoRefresh()
                    }
                }
            } catch {
                await MainActor.run {
                    self.lastError = self.localNetworkErrors.userFacingMessage(for: error)
                }
            }
        }
    }

    func refreshDownloads() {
        Task {
            do {
                let (payloads, _) = try await bridge.downloads(config: config)
                await MainActor.run {
                    self.downloads = DownloadItem.fromBridge(payloads)
                }
            } catch {
                await MainActor.run {
                    self.lastError = self.localNetworkErrors.userFacingMessage(for: error)
                }
            }
        }
    }

    func addLinks(_ rawInput: String) {
        let links = LinkImportSupport.parseLinks(from: rawInput)
        guard !links.isEmpty else {
            lastError = "No valid links found."
            return
        }

        isBusy = true
        Task {
            for link in links {
                do {
                    let normalized = LinkImportSupport.normalizeLink(link)
                    let _ = try await bridge.addLink(link: normalized, config: config)
                } catch {
                    await MainActor.run {
                        self.lastError = self.localNetworkErrors.userFacingMessage(for: error)
                    }
                }
            }

            do {
                let (payloads, _) = try await bridge.downloads(config: config)
                await MainActor.run {
                    self.downloads = DownloadItem.fromBridge(payloads)
                    self.isBusy = false
                }
            } catch {
                await MainActor.run {
                    self.isBusy = false
                }
            }
        }
    }

    func enqueueIncomingLink(_ rawInput: String) {
        deepLinkHandler.enqueueIncomingLink(rawInput)
        if isSessionConnected {
            flushIncomingLinks()
        }
    }

    func flushIncomingLinks() {
        let links = deepLinkHandler.drainIncomingLinks()
        guard !links.isEmpty else { return }
        addLinks(links.joined(separator: "\n"))
    }

    func handleOpenURL(_ url: URL) {
        deepLinkHandler.handleOpenURL(url)
        if isSessionConnected {
            flushIncomingLinks()
        }
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        switch appLifecycle.handleScenePhaseChange(phase, isSessionConnected: isSessionConnected) {
        case .pauseAutoRefresh:
            stopAutoRefresh()
        case .resumeAutoRefresh(let shouldReconnect):
            if shouldReconnect {
                reconnectAfterForegroundTransition()
            } else if isSessionConnected {
                startAutoRefresh()
            }
        case .none:
            break
        }
    }

    func downloadSearchResult(_ result: SearchResult) {
        guard !result.hash.isEmpty else {
            lastError = "Cannot download: missing file hash."
            return
        }
        isBusy = true
        Task {
            do {
                let _ = try await bridge.download(hash: result.hash, config: config)
                await MainActor.run {
                    self.downloadFeedback = "Added to downloads: \(result.name)"
                    self.isBusy = false
                }
                self.refreshDownloads()
            } catch {
                await MainActor.run {
                    self.lastError = self.localNetworkErrors.userFacingMessage(for: error)
                    self.isBusy = false
                }
            }
        }
    }

    func performSearch(query: String, scope: String? = nil) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isSearchInProgress else { return }

        let effectiveScope = scope ?? searchScope
        isSearchInProgress = true
        searchProgress = 0
        lastError = ""

        Task {
            do {
                let (progress, results, _) = try await bridge.search(
                    scope: effectiveScope,
                    query: trimmed,
                    polls: 12,
                    pollIntervalMs: 900,
                    config: config
                )
                await MainActor.run {
                    self.searchProgress = max(0, min(100, progress))
                    self.searchResults = SearchResult.fromBridge(results)
                    self.isSearchInProgress = false
                }
            } catch {
                await MainActor.run {
                    self.lastError = self.localNetworkErrors.userFacingMessage(for: error)
                    self.isSearchInProgress = false
                }
            }
        }
    }

    func pauseDownload(_ item: DownloadItem) {
        Task {
            let _ = try await bridge.pause(hash: item.id, config: config)
            await refreshDownloads()
        }
    }

    func resumeDownload(_ item: DownloadItem) {
        Task {
            let _ = try await bridge.resume(hash: item.id, config: config)
            await refreshDownloads()
        }
    }

    func removeDownload(_ item: DownloadItem) {
        guard !item.id.isEmpty else {
            lastError = "Cannot remove download: missing file hash."
            return
        }

        isBusy = true
        lastError = ""
        Task {
            do {
                let _ = try await bridge.cancel(hash: item.id, config: config)
                let (payloads, _) = try await bridge.downloads(config: config)
                await MainActor.run {
                    self.downloads = DownloadItem.fromBridge(payloads)
                    self.isBusy = false
                }
            } catch {
                await MainActor.run {
                    self.lastError = self.localNetworkErrors.userFacingMessage(for: error)
                    self.isBusy = false
                }
            }
        }
    }

func connectServer(_ server: ServerItem?) {
        Task {
            do {
                let _ = try await bridge.serverConnect(ip: server?.ip, port: server?.port, config: config)
                await refreshStatus()
            } catch {
                await MainActor.run {
                    self.lastError = self.localNetworkErrors.userFacingMessage(for: error)
                }
            }
        }
    }

    func connectUserServer(_ server: UserServer) {
        Task {
            do {
                let _ = try await bridge.serverConnect(ip: server.ip, port: server.port, config: config)
                await refreshStatus()
            } catch {
                await MainActor.run {
                    self.lastError = self.localNetworkErrors.userFacingMessage(for: error)
                }
            }
        }
    }

    func disconnectServer() {
        Task {
            do {
                let _ = try await bridge.serverConnect(ip: nil, port: nil, config: config)
                await refreshStatus()
            } catch {
                await MainActor.run {
                    self.lastError = self.localNetworkErrors.userFacingMessage(for: error)
                }
            }
        }
    }

    func addServer(name: String, ip: String, port: Int) {
        let server = UserServer(name: name, ip: ip, port: port)
        userServers.append(server)
        persistUserServers()
    }

    func editUserServer(_ server: UserServer, newName: String, newIP: String, newPort: Int) {
        guard let index = userServers.firstIndex(of: server) else { return }
        userServers[index] = UserServer(name: newName, ip: newIP, port: newPort)
        persistUserServers()
    }

    func removeUserServer(_ server: UserServer) {
        userServers.removeAll { $0 == server }
        persistUserServers()
    }

    func isBridgeOpSupported(_ op: String) -> Bool {
        BridgeCapabilityGate.isSupported(op, by: bridgeOps)
    }

    func sources(for item: DownloadItem?) -> [DownloadSourceItem] {
        guard let item else { return [] }
        return downloadSourcesByHash[item.id] ?? []
    }

    func refreshDownloadSources(for item: DownloadItem) {
        if item.isCompletedLike {
            downloadSourcesByHash[item.id] = []
            isRefreshingSources = false
            return
        }

        isRefreshingSources = true
        Task {
            do {
                let (sourceItems, _) = try await bridge.sources(hash: item.id, config: config)
                await MainActor.run {
                    self.downloadSourcesByHash[item.id] = sourceItems
                    self.isRefreshingSources = false
                }
            } catch {
                await MainActor.run {
                    self.lastError = self.localNetworkErrors.userFacingMessage(for: error)
                    self.isRefreshingSources = false
                }
            }
        }
    }

    func fetchTransferLimits() {
        guard isBridgeOpSupported("prefs-connection-get") else { return }
        Task {
            do {
                let (payload, _) = try await bridge.prefsConnectionGet(config: config)
                await MainActor.run {
                    self.downloadLimitKBps = payload.maxDownload
                    self.uploadLimitKBps = payload.maxUpload
                }
            } catch {
                await MainActor.run {
                    self.lastError = self.localNetworkErrors.userFacingMessage(for: error)
                }
            }
        }
    }

    func setTransferLimits(uploadKBps: Int, downloadKBps: Int) {
        guard isBridgeOpSupported("prefs-connection-set") else {
            lastError = "Setting transfer limits is not supported by this server."
            return
        }
        isBusy = true
        Task {
            do {
                let _ = try await bridge.prefsConnectionSet(maxDownload: downloadKBps, maxUpload: uploadKBps, config: config)
                await MainActor.run {
                    self.uploadLimitKBps = uploadKBps
                    self.downloadLimitKBps = downloadKBps
                    self.isBusy = false
                }
                if self.isBridgeOpSupported("prefs-connection-get") {
                    self.fetchTransferLimits()
                }
            } catch {
                await MainActor.run {
                    self.lastError = self.localNetworkErrors.userFacingMessage(for: error)
                    self.isBusy = false
                }
            }
        }
    }

    func copyDownloadLinkToClipboard(_ item: DownloadItem) {
        pasteboardShare.writeString(item.ed2kLink)
    }

    func shareDownloadLink(_ item: DownloadItem) {
        shareSheetPresenter.present(items: [item.ed2kLink])
    }

    private func loadUserServers() {
        guard let data = UserDefaults.standard.data(forKey: userServersStorageKey) else { return }
        let decoded = try? JSONDecoder().decode([UserServer].self, from: data)
        userServers = decoded ?? []
    }

    private func persistUserServers() {
        let data = (try? JSONEncoder().encode(userServers)) ?? Data()
        UserDefaults.standard.set(data, forKey: userServersStorageKey)
    }

    private func persistPassword() {
        if password.isEmpty {
            credentialStorage.deleteCredential(forKey: passwordStorageKey)
        } else {
            credentialStorage.writeCredential(password, forKey: passwordStorageKey)
        }
    }

    private func startAutoRefresh(intervalNanoseconds: UInt64 = 5_000_000_000) {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task {
            while !Task.isCancelled {
                guard self.isSessionConnected else { break }

                do {
                    try await self.refreshSessionSnapshot()
                } catch {
                    await MainActor.run {
                        self.lastError = self.localNetworkErrors.userFacingMessage(for: error)
                        self.isSessionConnected = false
                        self.autoRefreshTask?.cancel()
                        self.autoRefreshTask = nil
                    }
                    break
                }

                try? await Task.sleep(nanoseconds: intervalNanoseconds)
            }
        }
    }

    private func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    private func refreshSessionSnapshot() async throws {
        let (bridgeStatus, _) = try await bridge.status(config: config)
        let (payloads, _) = try await bridge.downloads(config: config)
        await MainActor.run {
            self.status = StatusSnapshot.fromBridge(bridgeStatus)
            self.downloads = DownloadItem.fromBridge(payloads)
            self.isSessionConnected = bridgeStatus.connected
        }
    }

    private func reconnectAfterForegroundTransition() {
        guard appLifecycle.isNetworkReachable else {
            lastError = "Connection timed out. Please check the host and port."
            return
        }

        if isSessionConnected {
            startAutoRefresh()
            refreshStatus()
            refreshDownloads()
            flushIncomingLinks()
        } else {
            connect()
        }
    }
}
#endif
