import Foundation
import SwiftUI
import AppKit

extension Notification.Name {
    static let amuleIncomingLinksDidChange = Notification.Name("AMuleIncomingLinksDidChange")
}

enum LinkImportSupport {
    static func parseLinks(from text: String) -> [String] {
        var unique = Set<String>()
        var ordered: [String] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            guard line.lowercased().hasPrefix("ed2k://") || line.lowercased().hasPrefix("magnet:?") else { continue }
            if unique.insert(line).inserted {
                ordered.append(line)
            }
        }

        return ordered
    }

    static func normalizeLink(_ link: String) -> String {
        var normalized = link
        let lower = normalized.lowercased()

        if lower.hasPrefix("ed2k://%7c") {
            normalized = normalized.replacingOccurrences(of: "%7C", with: "|", options: .caseInsensitive)
        }

        if lower.hasPrefix("ed2k://"),
           normalized.contains("|h="),
           !normalized.contains("|/|h=") {
            normalized = normalized.replacingOccurrences(of: "|h=", with: "|/|h=")
        }

        return normalized
    }

    static func extractEd2kHash(from link: String) -> String? {
        let normalized = link.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            return nil
        }

        if normalized.lowercased().hasPrefix("magnet:?"),
           let components = URLComponents(string: normalized) {
            for item in components.queryItems ?? [] where item.name.lowercased() == "xt" {
                guard let value = item.value else { continue }
                let lower = value.lowercased()
                if lower.hasPrefix("urn:ed2k:") {
                    let hash = String(value.dropFirst("urn:ed2k:".count))
                    if isValidEd2kHash(hash) {
                        return hash.uppercased()
                    }
                }
            }
        }

        let decoded = normalized.removingPercentEncoding ?? normalized
        if let range = decoded.range(of: #"[0-9A-Fa-f]{32}"#, options: .regularExpression) {
            let hash = String(decoded[range])
            if isValidEd2kHash(hash) {
                return hash.uppercased()
            }
        }

        return nil
    }

    static func isValidEd2kHash(_ hash: String) -> Bool {
        guard hash.count == 32 else { return false }
        return hash.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 48...57, 65...70, 97...102:
                return true
            default:
                return false
            }
        }
    }
}

@MainActor
final class PendingIncomingLinkInbox {
    static let shared = PendingIncomingLinkInbox()

    private var links: [String] = []
    private var knownLinks = Set<String>()

    var hasPendingLinks: Bool {
        !links.isEmpty
    }

    func enqueue(_ rawInput: String) {
        let parsed = LinkImportSupport.parseLinks(from: rawInput)
        guard !parsed.isEmpty else { return }

        var didInsert = false
        for link in parsed where knownLinks.insert(link).inserted {
            links.append(link)
            didInsert = true
        }

        if didInsert {
            NotificationCenter.default.post(name: .amuleIncomingLinksDidChange, object: nil)
        }
    }

    func drain() -> [String] {
        let drained = links
        links.removeAll()
        knownLinks.removeAll()
        return drained
    }
}

private func L3(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func LF3(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), locale: .current, arguments: args)
}

@MainActor
final class AppModel: ObservableObject {
    @AppStorage("amule.bridgePath") var bridgePath: String = AMuleConnectionConfig.preferredDefaultPath()
    @AppStorage("amule.host") var host: String = "127.0.0.1"
    @AppStorage("amule.port") var port: Int = 4712
    @AppStorage("amule.password") var password: String = ""
    @AppStorage("amule.prefs.connection.maxDownload") var savedConnectionMaxDownload: Int = 0
    @AppStorage("amule.prefs.connection.maxUpload") var savedConnectionMaxUpload: Int = 0

    @Published var status: StatusSnapshot = .init()
    @Published var isSessionConnected = false
    @Published var searchQuery: String = ""
    @Published var searchScope: String = "global"
    @Published var searchResults: [SearchResult] = []
    @Published var searchProgress: Int = 0
    @Published var isSearchInProgress = false
    @Published var lastSearchRawOutput = ""
    @Published var downloads: [DownloadItem] = []
    @Published var downloadSourcesByHash: [String: [DownloadSourceItem]] = [:]
    @Published var servers: [ServerItem] = []
    @Published var serverAddressInput: String = ""
    @Published var serverNameInput: String = ""
    @Published var isBusy = false
    @Published var outputLog = ""
    @Published var lastDownloadsRawOutput = ""
    @Published var lastSourcesRawOutput = ""
    @Published var lastUploadsRawOutput = ""
    @Published var lastSharedFilesRawOutput = ""
    @Published var lastCoreLogRawOutput = ""
    @Published var lastCoreDebugLogRawOutput = ""
    @Published var lastConnectionPrefsRawOutput = ""
    @Published var lastCategoriesRawOutput = ""
    @Published var lastFriendsRawOutput = ""
    @Published var lastStatsTreeRawOutput = ""
    @Published var lastStatsGraphsRawOutput = ""
    @Published var lastServersRawOutput = ""
    @Published var lastError = ""
    @Published var isRefreshingSources = false
    @Published var shouldAutoRefreshDownloads = false
    @Published var addLinksPanelRequestID: Int = 0
    @Published var selectedDownloadID: String? = nil
    @Published var hudMessage: String = ""
    @Published var showHUD = false
    @Published var bridgeSchemaVersion: Int?
    @Published var bridgeOps: Set<String> = []
    @Published var uploads: [BridgeUploadPayload] = []
    @Published var sharedFiles: [BridgeSharedFilePayload] = []
    @Published var coreLogLines: [String] = []
    @Published var coreDebugLogLines: [String] = []
    @Published var connectionMaxDownloadKBps: Int = 0
    @Published var connectionMaxUploadKBps: Int = 0
    @Published var connectionMaxDownloadInput: String = "0"
    @Published var connectionMaxUploadInput: String = "0"
    @Published var categories: [BridgeCategoryPayload] = []
    @Published var friends: [BridgeFriendPayload] = []
    @Published var statsTree: BridgeStatsTreeNodePayload?
    @Published var statsGraphs: BridgeStatsGraphsPayload?
    @Published var statsGraphsLastTimestamp: Double?
    @Published var ipFilterURLInput: String = ""

    private var autoRefreshTask: Task<Void, Never>?
    private var hudDismissTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?

    var buildCommit: String {
        if let value = Bundle.main.object(forInfoDictionaryKey: "AMuleBuildCommit") as? String,
           !value.isEmpty {
            return value
        }
        return "dev"
    }

    var config: AMuleConnectionConfig {
        .init(bridgePath: bridgePath, host: host, port: port, password: password)
    }

    init() {
        connectionMaxDownloadKBps = savedConnectionMaxDownload
        connectionMaxUploadKBps = savedConnectionMaxUpload
        connectionMaxDownloadInput = String(savedConnectionMaxDownload)
        connectionMaxUploadInput = String(savedConnectionMaxUpload)

        for argument in CommandLine.arguments.dropFirst() {
            PendingIncomingLinkInbox.shared.enqueue(argument)
        }
    }

    func isBridgeOpSupported(_ op: String) -> Bool {
        bridgeOps.isEmpty || bridgeOps.contains(op)
    }

    func refreshBridgeCapabilities(logOutput: Bool = false, suppressErrors: Bool = true) async {
        do {
            let (schemaVersion, capabilities, raw) = try await AMuleECBridgeClient.capabilities(config: config)
            await MainActor.run {
                self.bridgeSchemaVersion = schemaVersion
                self.bridgeOps = Set(capabilities.ops)
                if logOutput {
                    self.appendLog("$ capabilities\n\(raw)")
                }
            }
        } catch {
            await MainActor.run {
                if !suppressErrors {
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    func ensurePreferredBridgePath() {
        let current = bridgePath.trimmingCharacters(in: .whitespacesAndNewlines)
        if current.isEmpty ||
            current.hasSuffix("/amulecmd") ||
            !FileManager.default.isExecutableFile(atPath: current) {
            bridgePath = AMuleConnectionConfig.preferredDefaultPath()
        }
    }

    func requestAddLinksPanel() {
        addLinksPanelRequestID &+= 1
    }

    func flushIncomingLinksIfAny() {
        guard isSessionConnected else { return }

        let links = PendingIncomingLinkInbox.shared.drain()
        guard !links.isEmpty else { return }

        let rawInput = links.joined(separator: "\n")
        appendLog("$ incoming-links\n\(rawInput)")
        addLinks(rawInput)
    }

    func connectAll() {
        run(label: "connect") {
            try await self.connectNow()
        }
    }

    func disconnectAll() {
        run(label: "disconnect") {
            let (_, raw) = try await AMuleECBridgeClient.disconnect(config: self.config)
            await MainActor.run {
                self.appendLog("$ disconnect\n\(raw)")
                self.isSessionConnected = false
            }
            await self.refreshStatus(logOutput: false)
        }
    }

    func refreshStatus(logOutput: Bool = true, suppressErrors: Bool = false) async {
        do {
            let (bridgeStatus, raw) = try await AMuleECBridgeClient.status(config: config)
            await MainActor.run {
                self.status = StatusSnapshot.fromBridge(bridgeStatus)
                if logOutput {
                    self.appendLog("$ status\n\(raw)")
                }
                self.isSessionConnected = self.status.looksConnected
            }
        } catch {
            await MainActor.run {
                if !suppressErrors {
                    self.lastError = error.localizedDescription
                }
                self.isSessionConnected = false
            }
        }
    }

    func performSearch() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        guard !isSearchInProgress else { return }

        lastError = ""
        searchProgress = 0
        searchResults = []
        isSearchInProgress = true

        let scope = searchScope
        let currentConfig = config

        searchTask?.cancel()
        searchTask = Task {
            defer {
                self.isSearchInProgress = false
                self.searchTask = nil
            }

            do {
                let (progress, payload, raw) = try await AMuleECBridgeClient.search(
                    scope: scope,
                    query: query,
                    polls: 12,
                    pollIntervalMs: 900,
                    config: currentConfig
                )
                let parsed = SearchResult.fromBridge(payload)

                await MainActor.run {
                    self.searchProgress = max(0, min(100, progress))
                    self.searchResults = parsed
                    self.lastSearchRawOutput = raw
                    self.appendLog("$ search \(scope) \(query)\n\(raw)")
                }
            } catch {
                await MainActor.run {
                    if self.isSearchInProgress {
                        self.lastError = error.localizedDescription
                        self.appendLog("! search failed\n\(error.localizedDescription)")
                    }
                }
            }
        }
    }

    func stopSearch() {
        guard isSearchInProgress else { return }
        searchTask?.cancel()
        searchTask = nil

        Task {
            do {
                let (_, raw) = try await AMuleECBridgeClient.searchStop(config: self.config)
                await MainActor.run {
                    self.appendLog("$ search-stop\n\(raw)")
                    self.isSearchInProgress = false
                }
            } catch {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                    self.appendLog("! search-stop failed\n\(error.localizedDescription)")
                    self.isSearchInProgress = false
                }
            }
        }
    }

    func downloadResult(_ result: SearchResult) {
        downloadResults([result])
    }

    func downloadResults(_ results: [SearchResult]) {
        let unique = Dictionary(grouping: results, by: \.hash).compactMap { $0.value.first }
        guard !unique.isEmpty else { return }

        presentHUD(message: LF3("Adding %lld download(s)...", Int64(unique.count)), autoDismissAfter: nil)

        run(label: "download") {
            var successCount = 0
            var failureCount = 0

            for result in unique {
                do {
                    let (_, raw) = try await AMuleECBridgeClient.download(hash: result.hash, config: self.config)
                    await MainActor.run {
                        self.appendLog("$ download \(result.hash)\n\(raw)")
                    }
                    successCount += 1
                } catch {
                    failureCount += 1
                    await MainActor.run {
                        self.appendLog("! download \(result.hash)\n\(error.localizedDescription)")
                    }
                }
            }
            try await self.refreshDownloadsNow()
            await self.refreshStatus(logOutput: false)

            await MainActor.run {
                self.presentHUD(message: LF3("Added %lld download(s)", Int64(successCount)))
                if failureCount > 0 {
                    self.lastError = LF3(
                        "Added %lld download(s), failed %lld.",
                        Int64(successCount),
                        Int64(failureCount)
                    )
                }
            }
        }
    }

    func addLinks(_ rawInput: String) {
        let links = LinkImportSupport.parseLinks(from: rawInput)
        guard !links.isEmpty else {
            lastError = L3("No valid links found.")
            return
        }

        presentHUD(message: LF3("Adding %lld link(s)...", Int64(links.count)), autoDismissAfter: nil)

        run(label: "add-link") {
            let normalizedLinks = links.map { LinkImportSupport.normalizeLink($0) }
            let requestedHashes = Set(normalizedLinks.compactMap { LinkImportSupport.extractEd2kHash(from: $0) })
            let beforeHashes = Set(self.downloads.map { $0.id.uppercased() })

            var successCount = 0
            var failureCount = 0

            for (index, link) in links.enumerated() {
                do {
                    let normalized = normalizedLinks[index]
                    let (_, raw) = try await AMuleECBridgeClient.addLink(link: normalized, config: self.config)
                    await MainActor.run {
                        self.appendLog("$ add-link \(normalized)\n\(raw)")
                    }
                    successCount += 1
                } catch {
                    failureCount += 1
                    await MainActor.run {
                        self.appendLog("! add-link \(link)\n\(error.localizedDescription)")
                    }
                }
            }

            var actualAddedCount = 0
            if successCount > 0 {
                try await self.refreshDownloadsNow(logOutput: false)
                let afterHashes = Set(self.downloads.map { $0.id.uppercased() })

                if requestedHashes.isEmpty {
                    actualAddedCount = max(0, afterHashes.count - beforeHashes.count)
                } else {
                    actualAddedCount = requestedHashes.reduce(into: 0) { total, hash in
                        if !beforeHashes.contains(hash) && afterHashes.contains(hash) {
                            total += 1
                        }
                    }
                }

                await self.refreshStatus(logOutput: false, suppressErrors: true)
            }

            await MainActor.run {
                self.presentHUD(message: LF3("Added %lld link(s)", Int64(actualAddedCount)))
            }

            if failureCount > 0 {
                await MainActor.run {
                    self.lastError = LF3(
                        "Added %lld link(s), failed %lld.",
                        Int64(actualAddedCount),
                        Int64(failureCount)
                    )
                }
            }
        }
    }

    func refreshDownloads() {
        run(label: "downloads") {
            try await self.refreshDownloadsNow()
        }
    }

    func refreshDownloadSources(for item: DownloadItem) {
        if item.isCompletedLike {
            // Completed files are no longer in the active queue, so per-file
            // source queries are expected to be unavailable.
            downloadSourcesByHash[item.id] = []
            isRefreshingSources = false
            return
        }

        isRefreshingSources = true
        lastError = ""
        Task {
            do {
                try await self.refreshDownloadSourcesNow(for: item)
            } catch {
                await MainActor.run {
                    let message = error.localizedDescription
                    if message.contains("File not found in download queue") {
                        self.downloadSourcesByHash[item.id] = []
                    } else {
                        self.lastError = message
                        self.appendLog("! sources failed\n\(message)")
                    }
                }
            }
            await MainActor.run {
                self.isRefreshingSources = false
            }
        }
    }

    func sources(for item: DownloadItem?) -> [DownloadSourceItem] {
        guard let item else { return [] }
        return downloadSourcesByHash[item.id] ?? []
    }

    func refreshServers() {
        run(label: "servers") {
            try await self.refreshServersNow()
        }
    }

    func addServer() {
        let address = serverAddressInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = serverNameInput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !address.isEmpty else {
            lastError = L3("Server address is required (e.g. 1.2.3.4:4661).")
            return
        }

        run(label: "server-add") {
            let (_, raw) = try await AMuleECBridgeClient.serverAdd(
                address: address,
                name: name.isEmpty ? nil : name,
                config: self.config
            )
            await MainActor.run {
                self.appendLog("$ server-add \(address)\n\(raw)")
                self.serverAddressInput = ""
                self.serverNameInput = ""
            }
            try await self.refreshServersNow(logOutput: false)
        }
    }

    func connectServer(_ server: ServerItem?) {
        run(label: "server-connect") {
            let ip = server?.ip
            let port = server?.port
            let (_, raw) = try await AMuleECBridgeClient.serverConnect(ip: ip, port: port, config: self.config)
            await MainActor.run {
                if let server {
                    self.appendLog("$ server-connect \(server.address)\n\(raw)")
                } else {
                    self.appendLog("$ server-connect\n\(raw)")
                }
            }
            await self.refreshStatus(logOutput: false)
            try await self.refreshServersNow(logOutput: false)
        }
    }

    func disconnectServer() {
        run(label: "server-disconnect") {
            let (_, raw) = try await AMuleECBridgeClient.serverDisconnect(config: self.config)
            await MainActor.run {
                self.appendLog("$ server-disconnect\n\(raw)")
            }
            await self.refreshStatus(logOutput: false)
            try await self.refreshServersNow(logOutput: false)
        }
    }

    func removeServer(_ server: ServerItem) {
        guard !server.ip.isEmpty, server.port > 0 else {
            lastError = L3("Selected server has invalid endpoint information.")
            return
        }

        run(label: "server-remove") {
            let (_, raw) = try await AMuleECBridgeClient.serverRemove(ip: server.ip, port: server.port, config: self.config)
            await MainActor.run {
                self.appendLog("$ server-remove \(server.address)\n\(raw)")
            }
            try await self.refreshServersNow(logOutput: false)
        }
    }

    func updateServerListFromURL(_ rawURL: String) {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = L3("Server list URL is required.")
            return
        }
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            lastError = L3("Invalid server list URL. Use http:// or https://.")
            return
        }

        run(label: "server-update-from-url") {
            let (_, raw) = try await AMuleECBridgeClient.serverUpdateFromURL(url: trimmed, config: self.config)
            await MainActor.run {
                self.appendLog("$ server-update-from-url \(trimmed)\n\(raw)")
            }
            try await self.refreshServersNow(logOutput: false)
        }
    }

    func updateKadNodesFromURL(_ rawURL: String) {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = L3("nodes.dat URL is required.")
            return
        }
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            lastError = L3("Invalid nodes.dat URL. Use http:// or https://.")
            return
        }

        run(label: "kad-update-from-url") {
            let (_, raw) = try await AMuleECBridgeClient.kadUpdateFromURL(url: trimmed, config: self.config)
            await MainActor.run {
                self.appendLog("$ kad-update-from-url \(trimmed)\n\(raw)")
            }
            await self.refreshStatus(logOutput: false, suppressErrors: true)
        }
    }

    func refreshUploads() {
        guard isBridgeOpSupported("uploads") else { return }
        run(label: "uploads") {
            try await self.refreshUploadsNow()
        }
    }

    func refreshSharedFiles() {
        guard isBridgeOpSupported("shared-files") else { return }
        run(label: "shared-files") {
            try await self.refreshSharedFilesNow()
        }
    }

    func reloadSharedFiles() {
        guard isBridgeOpSupported("shared-files-reload") else { return }
        run(label: "shared-files-reload") {
            let (_, raw) = try await AMuleECBridgeClient.sharedFilesReload(config: self.config)
            await MainActor.run {
                self.appendLog("$ shared-files-reload\n\(raw)")
            }
            if self.isBridgeOpSupported("shared-files") {
                try await self.refreshSharedFilesNow(logOutput: false, suppressErrors: true)
            }
        }
    }

    func refreshCoreLog() {
        guard isBridgeOpSupported("log") else { return }
        run(label: "log") {
            try await self.refreshCoreLogNow()
        }
    }

    func refreshCoreDebugLog() {
        guard isBridgeOpSupported("debug-log") else { return }
        run(label: "debug-log") {
            try await self.refreshCoreDebugLogNow()
        }
    }

    func startKad() {
        guard isBridgeOpSupported("kad-start") else { return }
        run(label: "kad-start") {
            let (_, raw) = try await AMuleECBridgeClient.kadStart(config: self.config)
            await MainActor.run {
                self.appendLog("$ kad-start\n\(raw)")
            }
            await self.refreshStatus(logOutput: false, suppressErrors: true)
        }
    }

    func stopKad() {
        guard isBridgeOpSupported("kad-stop") else { return }
        run(label: "kad-stop") {
            let (_, raw) = try await AMuleECBridgeClient.kadStop(config: self.config)
            await MainActor.run {
                self.appendLog("$ kad-stop\n\(raw)")
            }
            await self.refreshStatus(logOutput: false, suppressErrors: true)
        }
    }

    func bootstrapKad(ip rawIP: String, port rawPort: String) {
        guard isBridgeOpSupported("kad-bootstrap") else { return }

        let ip = rawIP.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidIPv4(ip) else {
            lastError = L3("Invalid Kad bootstrap IP address.")
            return
        }

        let trimmedPort = rawPort.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let port = Int(trimmedPort), (1...65535).contains(port) else {
            lastError = L3("Invalid Kad bootstrap port.")
            return
        }

        run(label: "kad-bootstrap") {
            let (_, raw) = try await AMuleECBridgeClient.kadBootstrap(ip: ip, port: port, config: self.config)
            await MainActor.run {
                self.appendLog("$ kad-bootstrap --server-ip \(ip) --server-port \(port)\n\(raw)")
            }
            await self.refreshStatus(logOutput: false, suppressErrors: true)
        }
    }

    func refreshConnectionPrefs() {
        guard isBridgeOpSupported("prefs-connection-get") else { return }
        run(label: "prefs-connection-get") {
            try await self.refreshConnectionPrefsNow()
        }
    }

    func setConnectionSpeedLimits(maxDL rawMaxDL: String, maxUL rawMaxUL: String) {
        guard isBridgeOpSupported("prefs-connection-set") else { return }

        let maxDLText = rawMaxDL.trimmingCharacters(in: .whitespacesAndNewlines)
        let maxULText = rawMaxUL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let maxDL = Int(maxDLText), maxDL >= 0 else {
            lastError = L3("Invalid download speed limit. Use a non-negative integer.")
            return
        }
        guard let maxUL = Int(maxULText), maxUL >= 0 else {
            lastError = L3("Invalid upload speed limit. Use a non-negative integer.")
            return
        }

        run(label: "prefs-connection-set") {
            let (_, raw) = try await AMuleECBridgeClient.prefsConnectionSet(
                maxDownload: maxDL,
                maxUpload: maxUL,
                config: self.config
            )
            await MainActor.run {
                self.appendLog("$ prefs-connection-set --max-dl \(maxDL) --max-ul \(maxUL)\n\(raw)")
            }
            if self.isBridgeOpSupported("prefs-connection-get") {
                try await self.refreshConnectionPrefsNow(logOutput: false, suppressErrors: true)
            }
        }
    }

    func refreshCategories() {
        guard isBridgeOpSupported("categories") else { return }
        run(label: "categories") {
            try await self.refreshCategoriesNow()
        }
    }

    func createCategory(name: String, path: String, comment: String, color: Int, priority: Int) {
        guard isBridgeOpSupported("category-create") else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = L3("Category name is required.")
            return
        }

        run(label: "category-create") {
            let (_, raw) = try await AMuleECBridgeClient.categoryCreate(
                name: trimmed,
                path: path,
                comment: comment,
                color: color,
                priority: priority,
                config: self.config
            )
            await MainActor.run {
                self.appendLog("$ category-create --name \(trimmed)\n\(raw)")
            }
            if self.isBridgeOpSupported("categories") {
                try await self.refreshCategoriesNow(logOutput: false, suppressErrors: true)
            }
        }
    }

    func deleteCategory(id: Int) {
        guard isBridgeOpSupported("category-delete") else { return }
        run(label: "category-delete") {
            let (_, raw) = try await AMuleECBridgeClient.categoryDelete(categoryID: id, config: self.config)
            await MainActor.run {
                self.appendLog("$ category-delete --category \(id)\n\(raw)")
            }
            if self.isBridgeOpSupported("categories") {
                try await self.refreshCategoriesNow(logOutput: false, suppressErrors: true)
            }
        }
    }

    func refreshFriends() {
        guard isBridgeOpSupported("friends") else { return }
        run(label: "friends") {
            try await self.refreshFriendsNow()
        }
    }

    func removeFriend(id: Int) {
        guard isBridgeOpSupported("friend-remove") else { return }
        run(label: "friend-remove") {
            let (_, raw) = try await AMuleECBridgeClient.friendRemove(friendID: id, config: self.config)
            await MainActor.run {
                self.appendLog("$ friend-remove --friend-id \(id)\n\(raw)")
            }
            if self.isBridgeOpSupported("friends") {
                try await self.refreshFriendsNow(logOutput: false, suppressErrors: true)
            }
        }
    }

    func setFriendSlot(id: Int, enabled: Bool) {
        guard isBridgeOpSupported("friend-slot") else { return }
        run(label: "friend-slot") {
            let (_, raw) = try await AMuleECBridgeClient.friendSlot(friendID: id, enabled: enabled, config: self.config)
            await MainActor.run {
                self.appendLog("$ friend-slot --friend-id \(id) --friend-slot \(enabled ? 1 : 0)\n\(raw)")
            }
            if self.isBridgeOpSupported("friends") {
                try await self.refreshFriendsNow(logOutput: false, suppressErrors: true)
            }
        }
    }

    func reloadIpFilter() {
        guard isBridgeOpSupported("ipfilter-reload") else { return }
        run(label: "ipfilter-reload") {
            let (_, raw) = try await AMuleECBridgeClient.ipfilterReload(config: self.config)
            await MainActor.run {
                self.appendLog("$ ipfilter-reload\n\(raw)")
            }
        }
    }

    func updateIpFilterFromURL(_ rawURL: String) {
        guard isBridgeOpSupported("ipfilter-update") else { return }
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            guard let url = URL(string: trimmed),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https" else {
                lastError = L3("Invalid IP filter URL. Use http:// or https://.")
                return
            }
        }

        run(label: "ipfilter-update") {
            let (_, raw) = try await AMuleECBridgeClient.ipfilterUpdate(url: trimmed.isEmpty ? nil : trimmed, config: self.config)
            await MainActor.run {
                if trimmed.isEmpty {
                    self.appendLog("$ ipfilter-update\n\(raw)")
                } else {
                    self.appendLog("$ ipfilter-update --ipfilter-url \(trimmed)\n\(raw)")
                }
            }
        }
    }

    func refreshStatsTree(capping: Int? = nil) {
        guard isBridgeOpSupported("stats-tree") else { return }
        run(label: "stats-tree") {
            try await self.refreshStatsTreeNow(capping: capping)
        }
    }

    func refreshStatsGraphs(width: Int = 480, scale: Int = 1) {
        guard isBridgeOpSupported("stats-graphs") else { return }
        run(label: "stats-graphs") {
            try await self.refreshStatsGraphsNow(width: width, scale: scale)
        }
    }

    func resetLog() {
        outputLog = ""
    }

    func copyLogToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputLog, forType: .string)
    }

    func copyDownloadsRawToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastDownloadsRawOutput, forType: .string)
    }

    func copySearchRawToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastSearchRawOutput, forType: .string)
    }

    func copyServersRawToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastServersRawOutput, forType: .string)
    }

    func copySourcesRawToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastSourcesRawOutput, forType: .string)
    }

    func copyUploadsRawToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastUploadsRawOutput, forType: .string)
    }

    func copySharedFilesRawToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastSharedFilesRawOutput, forType: .string)
    }

    func copyCoreLogRawToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastCoreLogRawOutput, forType: .string)
    }

    func copyCoreDebugLogRawToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastCoreDebugLogRawOutput, forType: .string)
    }

    func copyDownloadLinkToClipboard(_ item: DownloadItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.ed2kLink, forType: .string)
    }

    func clearCompletedDownloads(_ items: [DownloadItem]) {
        let ecids = items.map(\.ecid)
        guard !ecids.isEmpty else { return }

        run(label: "clear-completed") {
            let (_, raw) = try await AMuleECBridgeClient.clearCompleted(ecids: ecids, config: self.config)
            await MainActor.run {
                self.appendLog("$ clear-completed (\(ecids.count))\n\(raw)")
            }
            try await self.refreshDownloadsNow(logOutput: false)
            await self.refreshStatus(logOutput: false)
        }
    }

    func pauseDownload(_ item: DownloadItem) {
        run(label: "pause") {
            try await self.runDownloadAction(.pause, item)
        }
    }

    func pauseDownloads(_ items: [DownloadItem]) {
        run(label: "pause") {
            try await self.runDownloadActions(.pause, items)
        }
    }

    func resumeDownload(_ item: DownloadItem) {
        run(label: "resume") {
            try await self.runDownloadAction(.resume, item)
        }
    }

    func resumeDownloads(_ items: [DownloadItem]) {
        run(label: "resume") {
            try await self.runDownloadActions(.resume, items)
        }
    }

    func removeDownload(_ item: DownloadItem) {
        run(label: "cancel") {
            try await self.runDownloadAction(.cancel, item)
        }
    }

    func removeDownloads(_ items: [DownloadItem]) {
        run(label: "cancel") {
            try await self.runDownloadActions(.cancel, items)
        }
    }

    func renameDownload(_ item: DownloadItem, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = L3("File name cannot be empty.")
            return
        }
        guard trimmed != item.name else {
            return
        }

        run(label: "rename") {
            let (_, raw) = try await AMuleECBridgeClient.rename(hash: item.id, name: trimmed, config: self.config)
            await MainActor.run {
                self.appendLog("$ rename \(item.id) \(trimmed)\n\(raw)")
            }
            try await self.refreshDownloadsNow(logOutput: false)
        }
    }

    func setDownloadPriority(_ item: DownloadItem, _ priority: String) {
        run(label: "priority") {
            try await self.runDownloadAction(.priority(priority), item)
        }
    }

    func startAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task {
            var tick: Int = 0
            while !Task.isCancelled {
                if self.isSessionConnected {
                    await self.refreshStatus(logOutput: false, suppressErrors: true)
                    if self.shouldAutoRefreshDownloads {
                        try? await self.refreshDownloadsNow(logOutput: false, suppressErrors: true)
                    }
                    if tick % 5 == 0 {
                        try? await self.refreshServersNow(logOutput: false, suppressErrors: true)
                    }
                }
                tick += 1
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    func setDownloadAutoRefreshEnabled(_ enabled: Bool) {
        shouldAutoRefreshDownloads = enabled
    }

    private func run(label: String, _ work: @escaping () async throws -> Void) {
        isBusy = true
        lastError = ""
        Task {
            do {
                try await work()
            } catch {
                await MainActor.run {
                    if self.showHUD, self.hudDismissTask == nil {
                        self.hideHUD()
                    }
                    self.lastError = error.localizedDescription
                    self.appendLog("! \(label) failed\n\(error.localizedDescription)")
                }
            }
            await MainActor.run {
                self.isBusy = false
            }
        }
    }

    private func refreshDownloadsNow(logOutput: Bool = true, suppressErrors: Bool = false) async throws {
        do {
            let (payload, raw) = try await AMuleECBridgeClient.downloads(config: config)
            let parsed = DownloadItem.fromBridge(payload)
            await MainActor.run {
                self.downloads = parsed
                self.lastDownloadsRawOutput = raw
                if logOutput {
                    self.appendLog("$ downloads\n\(raw)")
                }
            }
        } catch {
            await MainActor.run {
                if !suppressErrors {
                    self.lastError = error.localizedDescription
                }
            }
            throw error
        }
    }

    private func refreshDownloadSourcesNow(for item: DownloadItem, logOutput: Bool = true) async throws {
        let (payload, raw) = try await AMuleECBridgeClient.sources(hash: item.id, config: config)
        let parsed = DownloadSourceItem.fromBridge(payload)
        await MainActor.run {
            self.downloadSourcesByHash[item.id] = parsed
            self.lastSourcesRawOutput = raw
            if logOutput {
                self.appendLog("$ sources \(item.id)\n\(raw)")
            }
        }
    }

    private func refreshServersNow(logOutput: Bool = true, suppressErrors: Bool = false) async throws {
        do {
            let (payload, raw) = try await AMuleECBridgeClient.servers(config: config)
            let parsed = ServerItem.fromBridge(payload)
            await MainActor.run {
                self.servers = parsed
                self.lastServersRawOutput = raw
                if logOutput {
                    self.appendLog("$ servers\n\(raw)")
                }
            }
        } catch {
            await MainActor.run {
                if !suppressErrors {
                    self.lastError = error.localizedDescription
                }
            }
            throw error
        }
    }

    private func refreshUploadsNow(logOutput: Bool = true, suppressErrors: Bool = false) async throws {
        do {
            let (payload, raw) = try await AMuleECBridgeClient.uploads(config: config)
            await MainActor.run {
                self.uploads = payload
                self.lastUploadsRawOutput = raw
                if logOutput {
                    self.appendLog("$ uploads\n\(raw)")
                }
            }
        } catch {
            await MainActor.run {
                if !suppressErrors {
                    self.lastError = error.localizedDescription
                }
            }
            throw error
        }
    }

    private func refreshSharedFilesNow(logOutput: Bool = true, suppressErrors: Bool = false) async throws {
        do {
            let (payload, raw) = try await AMuleECBridgeClient.sharedFiles(config: config)
            await MainActor.run {
                self.sharedFiles = payload
                self.lastSharedFilesRawOutput = raw
                if logOutput {
                    self.appendLog("$ shared-files\n\(raw)")
                }
            }
        } catch {
            await MainActor.run {
                if !suppressErrors {
                    self.lastError = error.localizedDescription
                }
            }
            throw error
        }
    }

    private func refreshCoreLogNow(logOutput: Bool = true, suppressErrors: Bool = false) async throws {
        do {
            let (payload, raw) = try await AMuleECBridgeClient.log(config: config)
            await MainActor.run {
                self.coreLogLines = payload.lines
                self.lastCoreLogRawOutput = raw
                if logOutput {
                    self.appendLog("$ log\n\(raw)")
                }
            }
        } catch {
            await MainActor.run {
                if !suppressErrors {
                    self.lastError = error.localizedDescription
                }
            }
            throw error
        }
    }

    private func refreshCoreDebugLogNow(logOutput: Bool = true, suppressErrors: Bool = false) async throws {
        do {
            let (payload, raw) = try await AMuleECBridgeClient.debugLog(config: config)
            await MainActor.run {
                self.coreDebugLogLines = payload.lines
                self.lastCoreDebugLogRawOutput = raw
                if logOutput {
                    self.appendLog("$ debug-log\n\(raw)")
                }
            }
        } catch {
            await MainActor.run {
                if !suppressErrors {
                    self.lastError = error.localizedDescription
                }
            }
            throw error
        }
    }

    private func refreshConnectionPrefsNow(logOutput: Bool = true, suppressErrors: Bool = false) async throws {
        do {
            let (payload, raw) = try await AMuleECBridgeClient.prefsConnectionGet(config: config)
            await MainActor.run {
                self.connectionMaxDownloadKBps = payload.maxDownload
                self.connectionMaxUploadKBps = payload.maxUpload
                self.connectionMaxDownloadInput = String(payload.maxDownload)
                self.connectionMaxUploadInput = String(payload.maxUpload)
                self.savedConnectionMaxDownload = payload.maxDownload
                self.savedConnectionMaxUpload = payload.maxUpload
                self.lastConnectionPrefsRawOutput = raw
                if logOutput {
                    self.appendLog("$ prefs-connection-get\n\(raw)")
                }
            }
        } catch {
            await MainActor.run {
                if !suppressErrors {
                    self.lastError = error.localizedDescription
                }
            }
            throw error
        }
    }

    private func refreshCategoriesNow(logOutput: Bool = true, suppressErrors: Bool = false) async throws {
        do {
            let (payload, raw) = try await AMuleECBridgeClient.categories(config: config)
            await MainActor.run {
                self.categories = payload
                self.lastCategoriesRawOutput = raw
                if logOutput {
                    self.appendLog("$ categories\n\(raw)")
                }
            }
        } catch {
            await MainActor.run {
                if !suppressErrors {
                    self.lastError = error.localizedDescription
                }
            }
            throw error
        }
    }

    private func refreshFriendsNow(logOutput: Bool = true, suppressErrors: Bool = false) async throws {
        do {
            let (payload, raw) = try await AMuleECBridgeClient.friends(config: config)
            await MainActor.run {
                self.friends = payload
                self.lastFriendsRawOutput = raw
                if logOutput {
                    self.appendLog("$ friends\n\(raw)")
                }
            }
        } catch {
            await MainActor.run {
                if !suppressErrors {
                    self.lastError = error.localizedDescription
                }
            }
            throw error
        }
    }

    private func refreshStatsTreeNow(capping: Int? = nil, logOutput: Bool = true, suppressErrors: Bool = false) async throws {
        do {
            let (payload, raw) = try await AMuleECBridgeClient.statsTree(capping: capping, config: config)
            await MainActor.run {
                self.statsTree = payload
                self.lastStatsTreeRawOutput = raw
                if logOutput {
                    self.appendLog("$ stats-tree\n\(raw)")
                }
            }
        } catch {
            await MainActor.run {
                if !suppressErrors {
                    self.lastError = error.localizedDescription
                }
            }
            throw error
        }
    }

    private func refreshStatsGraphsNow(width: Int, scale: Int, logOutput: Bool = true, suppressErrors: Bool = false) async throws {
        do {
            let (payload, raw) = try await AMuleECBridgeClient.statsGraphs(
                width: width,
                scale: scale,
                last: statsGraphsLastTimestamp,
                config: config
            )
            await MainActor.run {
                self.statsGraphs = payload
                self.statsGraphsLastTimestamp = payload.last
                self.lastStatsGraphsRawOutput = raw
                if logOutput {
                    self.appendLog("$ stats-graphs --stats-width \(width) --stats-scale \(scale)\n\(raw)")
                }
            }
        } catch {
            await MainActor.run {
                if !suppressErrors {
                    self.lastError = error.localizedDescription
                }
            }
            throw error
        }
    }

    private func connectNow() async throws {
        let (_, raw) = try await AMuleECBridgeClient.connect(config: self.config)
        await MainActor.run {
            self.appendLog("$ connect\n\(raw)")
            self.isSessionConnected = true
        }
        await self.refreshBridgeCapabilities(logOutput: false, suppressErrors: true)
        await self.refreshStatus(logOutput: false)
        try await self.refreshDownloadsNow()
        try await self.refreshServersNow(logOutput: false, suppressErrors: true)
    }

    private enum DownloadAction {
        case pause
        case resume
        case cancel
        case priority(String)
    }

    private func runDownloadAction(_ action: DownloadAction, _ item: DownloadItem) async throws {
        let (commandLabel, raw) = try await invokeDownloadAction(action, item)

        await MainActor.run {
            self.appendLog("$ \(commandLabel)\n\(raw)")
        }

        try await self.refreshDownloadsNow()
        await self.refreshStatus(logOutput: false)
    }

    private func runDownloadActions(_ action: DownloadAction, _ items: [DownloadItem]) async throws {
        guard !items.isEmpty else { return }
        for item in items {
            let (commandLabel, raw) = try await invokeDownloadAction(action, item)
            await MainActor.run {
                self.appendLog("$ \(commandLabel)\n\(raw)")
            }
        }
        try await self.refreshDownloadsNow()
        await self.refreshStatus(logOutput: false)
    }

    private func invokeDownloadAction(_ action: DownloadAction, _ item: DownloadItem) async throws -> (String, String) {
        let raw: String
        let commandLabel: String

        switch action {
        case .pause:
            raw = try await AMuleECBridgeClient.pause(hash: item.id, config: config).raw
            commandLabel = "pause \(item.id)"
        case .resume:
            raw = try await AMuleECBridgeClient.resume(hash: item.id, config: config).raw
            commandLabel = "resume \(item.id)"
        case .cancel:
            raw = try await AMuleECBridgeClient.cancel(hash: item.id, config: config).raw
            commandLabel = "cancel \(item.id)"
        case .priority(let value):
            raw = try await AMuleECBridgeClient.priority(hash: item.id, value: value, config: config).raw
            commandLabel = "priority \(value) \(item.id)"
        }
        return (commandLabel, raw)
    }

    private func appendLog(_ message: String) {
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        outputLog = "[\(stamp)]\n\(message)\n\n" + outputLog
    }

    private func isValidIPv4(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        for part in parts {
            guard let octet = Int(part), (0...255).contains(octet) else {
                return false
            }
        }
        return true
    }

    private func presentHUD(message: String) {
        presentHUD(message: message, autoDismissAfter: 2_000_000_000)
    }

    private func presentHUD(message: String, autoDismissAfter nanoseconds: UInt64?) {
        hudDismissTask?.cancel()
        hudDismissTask = nil
        hudMessage = message
        withAnimation(.easeOut(duration: 0.15)) {
            showHUD = true
        }

        guard let nanoseconds else { return }

        hudDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                self.hudDismissTask = nil
                withAnimation(.easeIn(duration: 0.18)) {
                    self.showHUD = false
                }
            }
        }
    }

    private func hideHUD() {
        hudDismissTask?.cancel()
        hudDismissTask = nil
        withAnimation(.easeIn(duration: 0.18)) {
            showHUD = false
        }
    }
}
