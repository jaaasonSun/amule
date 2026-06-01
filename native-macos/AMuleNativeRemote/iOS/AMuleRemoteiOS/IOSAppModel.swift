#if canImport(UIKit)
import SwiftUI
import AMuleRemoteIOSShared
import SharedCore
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
    private let connectionService = IOSConnectionService()
    private let downloadService = IOSDownloadService()
    private let searchService = IOSSearchService()
    private let serverService = IOSServerService()

    var config: AMuleConnectionConfig {
        .init(host: host, port: port, password: password)
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
        connectionService.startLifecycleServices(model: self)
    }

    func stopLifecycleServices() {
        connectionService.stopLifecycleServices(model: self)
    }

    func connect() {
        connectionService.connect(model: self)
    }

    func runStartupStep<T>(_ label: String, _ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch {
            throw IOSConnectionStartupError(step: label, underlying: error)
        }
    }

    func disconnect() {
        connectionService.disconnect(model: self)
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
        downloadService.refreshDownloads(model: self)
    }

    func refreshServers() {
        serverService.refreshServers(model: self)
    }

    func addLinks(_ rawInput: String) {
        searchService.addLinks(rawInput, model: self)
    }

    func enqueueIncomingLink(_ rawInput: String) {
        searchService.enqueueIncomingLink(rawInput, model: self)
    }

    func flushIncomingLinks() {
        searchService.flushIncomingLinks(model: self)
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
        searchService.downloadSearchResult(result, model: self)
    }

    func performSearch(query: String, scope: String? = nil) {
        searchService.performSearch(query: query, scope: scope, model: self)
    }

    func pauseDownload(_ item: DownloadItem) {
        downloadService.pauseDownload(item, model: self)
    }

    func resumeDownload(_ item: DownloadItem) {
        downloadService.resumeDownload(item, model: self)
    }

    func renameDownload(_ item: DownloadItem, to newName: String) {
        downloadService.renameDownload(item, to: newName, model: self)
    }

    func removeDownload(_ item: DownloadItem) {
        downloadService.removeDownload(item, model: self)
    }

    func connectServer(_ server: ServerItem?) {
        serverService.connectServer(server, model: self)
    }

    func connectUserServer(_ server: UserServer) {
        serverService.connectUserServer(server, model: self)
    }

    func disconnectServer() {
        serverService.disconnectServer(model: self)
    }

    func addServer(name: String, ip: String, port: Int) {
        serverService.addServer(name: name, ip: ip, port: port, model: self)
    }

    func addRemoteServer(address: String, name: String?) {
        serverService.addRemoteServer(address: address, name: name, model: self)
    }

    func editUserServer(_ server: UserServer, newName: String, newIP: String, newPort: Int) {
        serverService.editUserServer(server, newName: newName, newIP: newIP, newPort: newPort, model: self)
    }

    func removeUserServer(_ server: UserServer) {
        serverService.removeUserServer(server, model: self)
    }

    func removeRemoteServer(_ server: ServerItem) {
        serverService.removeRemoteServer(server, model: self)
    }

    func updateRemoteServers(from url: String) {
        serverService.updateRemoteServers(from: url, model: self)
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
                let (sourcePayloads, _) = try await bridge.sources(hash: item.id, config: config)
                let sourceItems = DownloadSourceItem.fromBridge(sourcePayloads)
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

    var bridgeClient: BridgeProtocol { bridge }

    var deepLinkInboxHandler: DeepLinkHandling { deepLinkHandler }

    var appLifecycleService: AppLifecycleProtocol { appLifecycle }

    var localNetworkErrorPresenter: LocalNetworkErrorPresentation { localNetworkErrors }

    func loadUserServers() {
        guard let data = UserDefaults.standard.data(forKey: userServersStorageKey) else { return }
        let decoded = try? JSONDecoder().decode([UserServer].self, from: data)
        userServers = decoded ?? []
    }

    func persistUserServers() {
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

    func normalizedEndpoint(ip: String, port: Int) -> String {
        let trimmedIP = ip.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedIP.isEmpty, port > 0 else { return "" }
        return "\(trimmedIP):\(port)"
    }

    func remoteServersIfSupported(by ops: [String], config: AMuleConnectionConfig) async throws -> [BridgeServerPayload] {
        guard BridgeCapabilityGate.isSupported("servers", by: Set(ops)) else { return [] }
        let (payloads, _) = try await bridge.servers(config: config)
        return payloads
    }

    func startAutoRefresh(intervalNanoseconds: UInt64 = 5_000_000_000) {
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

    func stopAutoRefresh() {
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

    func reconnectAfterForegroundTransition() {
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

    static func linkImportFeedback(_ outcome: LinkImportOutcome) -> String? {
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
