#if canImport(UIKit)
import SwiftUI
import AMuleRemoteIOSShared
import SharedUI

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

private struct IOSConnectionStartupError: LocalizedError {
    let step: String
    let underlying: Error

    var errorDescription: String? {
        LF("Connection failed while trying to %@.\n\n%@", L(step), underlying.localizedDescription)
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
    private let deepLinkHandler: DeepLinkHandling
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
        deepLinkHandler: DeepLinkHandling = platformDefaultDeepLinkHandler(),
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
        reconnectAfterForegroundTransition()
    }

    func stopLifecycleServices() {
        appLifecycle.stop()
        stopAutoRefresh()
    }

    func connect() {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty else {
            lastError = L("Host is required.")
            isSessionConnected = false
            return
        }

        guard (1...65535).contains(port) else {
            lastError = L("Invalid port. Enter a value between 1 and 65535.")
            isSessionConnected = false
            return
        }

        host = trimmedHost
        isBusy = true
        lastError = ""
        let config = self.config
        let bridge = self.bridge
        Task {
            do {
                let _ = try await self.runStartupStep("authenticate") {
                    try await bridge.connect(config: config)
                }
                let (_, capabilities, _) = try await self.runStartupStep("load capabilities") {
                    try await bridge.capabilities(config: config)
                }
                let (bridgeStatus, _) = try await self.runStartupStep("load status") {
                    try await bridge.status(config: config)
                }
                let (downloadPayloads, _) = try await self.runStartupStep("load downloads") {
                    try await bridge.downloads(config: config)
                }
                let remoteServerPayloads = try await self.runStartupStep(
                    "load servers"
                ) {
                    try await self.remoteServersIfSupported(by: capabilities.ops, config: config)
                }
await MainActor.run {
                    self.isSessionConnected = true
                    self.bridgeOps = Set(capabilities.ops)
                    self.bridgeVersion = capabilities.bridgeVersion
                    self.bridgeClientName = capabilities.clientName
                    self.bridgeDefaultHost = capabilities.defaultHost
                    self.bridgeDefaultPort = capabilities.defaultPort
                    self.status = StatusSnapshot.fromBridge(bridgeStatus)
                    self.downloads = DownloadItem.fromBridge(downloadPayloads)
                    self.servers = ServerItem.fromBridge(remoteServerPayloads)
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

    private func runStartupStep<T>(_ label: String, _ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch {
            throw IOSConnectionStartupError(step: label, underlying: error)
        }
    }

    func disconnect() {
        isBusy = true
        let config = self.config
        let bridge = self.bridge
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
                    self.servers = []
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
        let config = self.config
        let bridge = self.bridge
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
        let config = self.config
        let bridge = self.bridge
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

    func refreshServers() {
        guard isBridgeOpSupported("servers") else {
            servers = []
            return
        }
        let config = self.config
        let bridge = self.bridge
        Task {
            do {
                let (payloads, _) = try await bridge.servers(config: config)
                await MainActor.run {
                    self.servers = ServerItem.fromBridge(payloads)
                }
            } catch {
                await MainActor.run {
                    self.lastError = self.localNetworkErrors.userFacingMessage(for: error)
                }
            }
        }
    }

    func addLinks(_ rawInput: String) {
        guard let importPlan = LinkImportPlan(rawInput: rawInput) else {
            lastError = L("No valid links found.")
            return
        }

        isBusy = true
        lastError = ""
        downloadFeedback = LF("%lld link(s) queued for import", Int64(importPlan.count))
        let config = self.config
        let bridge = self.bridge
        Task {
            var successCount = 0
            var failureCount = 0
            for normalized in importPlan.normalizedLinks {
                do {
                    let _ = try await bridge.addLink(link: normalized, config: config)
                    successCount += 1
                } catch {
                    failureCount += 1
                    await MainActor.run {
                        self.lastError = self.localNetworkErrors.userFacingMessage(for: error)
                    }
                }
            }

            do {
                let (payloads, _) = try await bridge.downloads(config: config)
                await MainActor.run {
                    self.downloads = DownloadItem.fromBridge(payloads)
                    self.downloadFeedback = Self.linkImportFeedback(
                        LinkImportOutcome(successCount: successCount, failureCount: failureCount)
                    )
                    self.isBusy = false
                }
            } catch {
                await MainActor.run {
                    self.downloadFeedback = Self.linkImportFeedback(
                        LinkImportOutcome(successCount: successCount, failureCount: failureCount)
                    )
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
            lastError = L("Cannot download: missing file hash.")
            return
        }
        isBusy = true
        let config = self.config
        let bridge = self.bridge
        Task {
            do {
                let _ = try await bridge.download(hash: result.hash, config: config)
                await MainActor.run {
                    self.downloadFeedback = LF("Added to downloads: %@", result.name)
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

        let config = self.config
        let bridge = self.bridge
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
        let config = self.config
        let bridge = self.bridge
        Task {
            let _ = try await bridge.pause(hash: item.id, config: config)
            await refreshDownloads()
        }
    }

    func resumeDownload(_ item: DownloadItem) {
        let config = self.config
        let bridge = self.bridge
        Task {
            let _ = try await bridge.resume(hash: item.id, config: config)
            await refreshDownloads()
        }
    }

    func renameDownload(_ item: DownloadItem, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !item.id.isEmpty else {
            lastError = L("Cannot rename download: missing file hash.")
            return
        }
        guard !trimmed.isEmpty else {
            lastError = L("New file name is required.")
            return
        }
        guard trimmed != item.name else { return }

        isBusy = true
        lastError = ""
        let config = self.config
        let bridge = self.bridge
        Task {
            do {
                let _ = try await bridge.rename(hash: item.id, name: trimmed, config: config)
                try? await Task.sleep(nanoseconds: 300_000_000)
                let (payloads, _) = try await bridge.downloads(config: config)
                let refreshedDownloads = DownloadItem.fromBridge(payloads)
                let didApply = RenameVerification.wasApplied(
                    downloadID: item.id,
                    newName: trimmed,
                    downloads: refreshedDownloads
                )
                await MainActor.run {
                    self.downloads = refreshedDownloads
                    self.lastError = didApply
                        ? ""
                        : L("Rename request was sent, but the filename was not changed.")
                    self.isBusy = false
                }
            } catch {
                do {
                    let (payloads, _) = try await bridge.downloads(config: config)
                    let refreshedDownloads = DownloadItem.fromBridge(payloads)
                    let didApply = RenameVerification.wasApplied(
                        downloadID: item.id,
                        newName: trimmed,
                        downloads: refreshedDownloads
                    )
                    await MainActor.run {
                        self.downloads = refreshedDownloads
                        self.lastError = didApply
                            ? ""
                            : "\(self.localNetworkErrors.userFacingMessage(for: error)) \(L("The filename was not changed."))"
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
    }

    func removeDownload(_ item: DownloadItem) {
        guard !item.id.isEmpty else {
            lastError = L("Cannot remove download: missing file hash.")
            return
        }

        isBusy = true
        lastError = ""
        let config = self.config
        let bridge = self.bridge
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
        guard isBridgeOpSupported("server-connect") else {
            lastError = L("Connecting to daemon servers is not supported by this bridge.")
            return
        }
        let config = self.config
        let bridge = self.bridge
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
        guard isBridgeOpSupported("server-connect") else {
            lastError = L("Connecting to local bookmarks is not supported by this bridge.")
            return
        }
        let config = self.config
        let bridge = self.bridge
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
        guard isBridgeOpSupported("server-disconnect") else {
            lastError = L("Disconnecting from daemon servers is not supported by this bridge.")
            return
        }
        let config = self.config
        let bridge = self.bridge
        Task {
            do {
                let _ = try await bridge.serverDisconnect(config: config)
                await refreshStatus()
            } catch {
                await MainActor.run {
                    self.lastError = self.localNetworkErrors.userFacingMessage(for: error)
                }
            }
        }
    }

    func addServer(name: String, ip: String, port: Int) {
        let endpoint = normalizedEndpoint(ip: ip, port: port)
        guard !endpoint.isEmpty else { return }
        guard !userServers.contains(where: { normalizedEndpoint(ip: $0.ip, port: $0.port) == endpoint }) else {
            lastError = "That local server bookmark already exists."
            return
        }
        let server = UserServer(name: name, ip: ip, port: port)
        userServers.append(server)
        persistUserServers()
    }

    func addRemoteServer(address: String, name: String?) {
        guard isBridgeOpSupported("server-add") else {
            lastError = L("Adding daemon servers is not supported by this bridge.")
            return
        }
        let config = self.config
        let bridge = self.bridge
        Task {
            do {
                let _ = try await bridge.serverAdd(address: address, name: name, config: config)
                await MainActor.run { self.refreshServers() }
            } catch {
                await MainActor.run {
                    self.lastError = self.localNetworkErrors.userFacingMessage(for: error)
                }
            }
        }
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

    func removeRemoteServer(_ server: ServerItem) {
        guard isBridgeOpSupported("server-remove") else {
            lastError = L("Removing daemon servers is not supported by this bridge.")
            return
        }
        let config = self.config
        let bridge = self.bridge
        Task {
            do {
                let _ = try await bridge.serverRemove(ip: server.ip, port: server.port, config: config)
                await MainActor.run { self.refreshServers() }
            } catch {
                await MainActor.run {
                    self.lastError = self.localNetworkErrors.userFacingMessage(for: error)
                }
            }
        }
    }

    func updateRemoteServers(from url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard isBridgeOpSupported("server-update-from-url") else {
            lastError = L("Updating daemon servers from URL is not supported by this bridge.")
            return
        }
        let config = self.config
        let bridge = self.bridge
        Task {
            do {
                let _ = try await bridge.serverUpdateFromURL(url: trimmed, config: config)
                await MainActor.run { self.refreshServers() }
            } catch {
                await MainActor.run {
                    self.lastError = self.localNetworkErrors.userFacingMessage(for: error)
                }
            }
        }
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
        let config = self.config
        let bridge = self.bridge
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
        let config = self.config
        let bridge = self.bridge
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
            lastError = L("Setting transfer limits is not supported by this server.")
            return
        }
        isBusy = true
        let config = self.config
        let bridge = self.bridge
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

    func setTransferLimits(uploadText: String, downloadText: String) {
        guard isBridgeOpSupported("prefs-connection-set") else {
            lastError = L("Setting transfer limits is not supported by this server.")
            return
        }

        let limits: TransferLimitSettings
        do {
            limits = try TransferLimitSettings(downloadText: downloadText, uploadText: uploadText)
        } catch TransferLimitValidationError.invalidDownload {
            lastError = L("Invalid download speed limit. Use a non-negative integer.")
            return
        } catch TransferLimitValidationError.invalidUpload {
            lastError = L("Invalid upload speed limit. Use a non-negative integer.")
            return
        } catch {
            lastError = localNetworkErrors.userFacingMessage(for: error)
            return
        }

        setTransferLimits(uploadKBps: limits.maxUpload, downloadKBps: limits.maxDownload)
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

    private func normalizedEndpoint(ip: String, port: Int) -> String {
        let trimmedIP = ip.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedIP.isEmpty, port > 0 else { return "" }
        return "\(trimmedIP):\(port)"
    }

    private func remoteServersIfSupported(by ops: [String], config: AMuleConnectionConfig) async throws -> [BridgeServerPayload] {
        guard BridgeCapabilityGate.isSupported("servers", by: Set(ops)) else { return [] }
        let (payloads, _) = try await bridge.servers(config: config)
        return payloads
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
        let config = self.config
        let bridge = self.bridge
        let (bridgeStatus, _) = try await bridge.status(config: config)
        let (payloads, _) = try await bridge.downloads(config: config)
        let serverPayloads: [BridgeServerPayload]
        if isBridgeOpSupported("servers") {
            let (servers, _) = try await bridge.servers(config: config)
            serverPayloads = servers
        } else {
            serverPayloads = []
        }
        await MainActor.run {
            self.status = StatusSnapshot.fromBridge(bridgeStatus)
            self.downloads = DownloadItem.fromBridge(payloads)
            self.servers = ServerItem.fromBridge(serverPayloads)
            self.isSessionConnected = bridgeStatus.connected
        }
    }

    private func reconnectAfterForegroundTransition() {
        guard !isBusy else { return }

        guard appLifecycle.isNetworkReachable else {
            lastError = L("Connection timed out. Please check the host and port.")
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

    private static func linkImportFeedback(_ outcome: LinkImportOutcome) -> String? {
        switch (outcome.successCount, outcome.failureCount) {
        case (0, 0):
            return nil
        case (let success, 0):
            return LF("%lld link(s) added", Int64(success))
        case (0, let failure):
            return LF("%lld link(s) failed", Int64(failure))
        case (let success, let failure):
            return LF("%lld link(s) added, %lld failed", Int64(success), Int64(failure))
        }
    }
}
#endif
