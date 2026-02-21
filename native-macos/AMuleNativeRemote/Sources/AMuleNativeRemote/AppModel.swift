import Foundation
import SwiftUI
import AppKit

@MainActor
final class AppModel: ObservableObject {
    @AppStorage("amule.bridgePath") var bridgePath: String = AMuleConnectionConfig.preferredDefaultPath()
    @AppStorage("amule.host") var host: String = "127.0.0.1"
    @AppStorage("amule.port") var port: Int = 4712
    @AppStorage("amule.password") var password: String = ""

    @Published var status: StatusSnapshot = .init()
    @Published var isSessionConnected = false
    @Published var searchQuery: String = ""
    @Published var searchScope: String = "global"
    @Published var searchResults: [SearchResult] = []
    @Published var searchStatusMessage: String = ""
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
    @Published var lastServersRawOutput = ""
    @Published var lastError = ""
    @Published var isRefreshingSources = false
    @Published var shouldAutoRefreshDownloads = false
    @Published var addLinksPanelRequestID: Int = 0
    @Published var selectedDownloadID: String? = nil
    @Published var hudMessage: String = ""
    @Published var showHUD = false

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
        searchStatusMessage = "Searching..."
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
                    if parsed.isEmpty {
                        self.searchStatusMessage = "No results yet (\(self.searchProgress)% complete)."
                    } else {
                        self.searchStatusMessage = "Found \(parsed.count) result(s), progress \(self.searchProgress)%."
                    }
                    self.appendLog("$ search \(scope) \(query)\n\(raw)")
                }
            } catch {
                await MainActor.run {
                    if self.isSearchInProgress {
                        self.lastError = error.localizedDescription
                        self.appendLog("! search failed\n\(error.localizedDescription)")
                        if self.searchStatusMessage.isEmpty || self.searchStatusMessage == "Searching..." {
                            self.searchStatusMessage = "Search failed"
                        }
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
                    self.searchStatusMessage = "Search stopped (\(self.searchProgress)% complete)."
                    self.isSearchInProgress = false
                }
            } catch {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                    self.appendLog("! search-stop failed\n\(error.localizedDescription)")
                    self.searchStatusMessage = "Search stop failed"
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

        run(label: "download") {
            for result in unique {
                let (_, raw) = try await AMuleECBridgeClient.download(hash: result.hash, config: self.config)
                await MainActor.run {
                    self.appendLog("$ download \(result.hash)\n\(raw)")
                }
            }
            try await self.refreshDownloadsNow()
            await self.refreshStatus(logOutput: false)
        }
    }

    func addLinks(_ rawInput: String) {
        let links = parseLinks(from: rawInput)
        guard !links.isEmpty else {
            lastError = "No valid links found."
            return
        }

        run(label: "add-link") {
            let normalizedLinks = links.map { self.normalizeLink($0) }
            let requestedHashes = Set(normalizedLinks.compactMap { self.extractEd2kHash(from: $0) })
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
                self.presentHUD(message: "Added \(actualAddedCount) link(s)")
            }

            if failureCount > 0 {
                await MainActor.run {
                    self.lastError = "Added \(actualAddedCount) link(s), failed \(failureCount)."
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
            lastError = "Server address is required (e.g. 1.2.3.4:4661)."
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
            lastError = "Selected server has invalid endpoint information."
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
            lastError = "File name cannot be empty."
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

    private func connectNow() async throws {
        let (_, raw) = try await AMuleECBridgeClient.connect(config: self.config)
        await MainActor.run {
            self.appendLog("$ connect\n\(raw)")
            self.isSessionConnected = true
        }
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

    private func parseLinks(from text: String) -> [String] {
        var unique = Set<String>()
        var ordered: [String] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            guard line.lowercased().hasPrefix("ed2k://") || line.lowercased().hasPrefix("magnet:?") else { continue }
            if !unique.contains(line) {
                unique.insert(line)
                ordered.append(line)
            }
        }

        return ordered
    }

    private func normalizeLink(_ link: String) -> String {
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

    private func extractEd2kHash(from link: String) -> String? {
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

    private func isValidEd2kHash(_ hash: String) -> Bool {
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

    private func presentHUD(message: String) {
        hudDismissTask?.cancel()
        hudMessage = message
        withAnimation(.easeOut(duration: 0.15)) {
            showHUD = true
        }

        hudDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                withAnimation(.easeIn(duration: 0.18)) {
                    self.showHUD = false
                }
            }
        }
    }
}
