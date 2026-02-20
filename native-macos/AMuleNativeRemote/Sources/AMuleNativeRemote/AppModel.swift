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
    @Published var searchScope: String = "kad"
    @Published var searchResults: [SearchResult] = []
    @Published var searchStatusMessage: String = ""
    @Published var lastSearchRawOutput = ""
    @Published var downloads: [DownloadItem] = []
    @Published var isBusy = false
    @Published var outputLog = ""
    @Published var lastDownloadsRawOutput = ""
    @Published var lastError = ""

    private var autoRefreshTask: Task<Void, Never>?

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

        run(label: "search") {
            await MainActor.run {
                self.searchStatusMessage = "Searching..."
            }

            let (progress, payload, raw) = try await AMuleECBridgeClient.search(
                scope: self.searchScope,
                query: query,
                polls: 12,
                pollIntervalMs: 900,
                config: self.config
            )
            let parsed = SearchResult.fromBridge(payload)

            await MainActor.run {
                self.searchResults = parsed
                self.lastSearchRawOutput = raw
                if parsed.isEmpty {
                    self.searchStatusMessage = "No results yet (\(progress)% complete)."
                } else {
                    self.searchStatusMessage = "Found \(parsed.count) result(s), progress \(progress)%."
                }
                self.appendLog("$ search \(self.searchScope) \(query)\n\(raw)")
            }
        }
    }

    func downloadResult(_ result: SearchResult) {
        run(label: "download") {
            let (_, raw) = try await AMuleECBridgeClient.download(hash: result.hash, config: self.config)
            await MainActor.run {
                self.appendLog("$ download \(result.hash)\n\(raw)")
            }
            try await self.refreshDownloadsNow()
            await self.refreshStatus(logOutput: false)
        }
    }

    func refreshDownloads() {
        run(label: "downloads") {
            try await self.refreshDownloadsNow()
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

    func pauseDownload(_ item: DownloadItem) {
        run(label: "pause") {
            try await self.runDownloadAction(.pause, item)
        }
    }

    func resumeDownload(_ item: DownloadItem) {
        run(label: "resume") {
            try await self.runDownloadAction(.resume, item)
        }
    }

    func removeDownload(_ item: DownloadItem) {
        run(label: "cancel") {
            try await self.runDownloadAction(.cancel, item)
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
            while !Task.isCancelled {
                if self.isSessionConnected {
                    await self.refreshStatus(logOutput: false, suppressErrors: true)
                    try? await self.refreshDownloadsNow(logOutput: false, suppressErrors: true)
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
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

    private func connectNow() async throws {
        let (_, raw) = try await AMuleECBridgeClient.connect(config: self.config)
        await MainActor.run {
            self.appendLog("$ connect\n\(raw)")
            self.isSessionConnected = true
        }
        await self.refreshStatus(logOutput: false)
        try await self.refreshDownloadsNow()
    }

    private enum DownloadAction {
        case pause
        case resume
        case cancel
        case priority(String)
    }

    private func runDownloadAction(_ action: DownloadAction, _ item: DownloadItem) async throws {
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

        await MainActor.run {
            self.appendLog("$ \(commandLabel)\n\(raw)")
        }

        try await self.refreshDownloadsNow()
        await self.refreshStatus(logOutput: false)
    }

    private func appendLog(_ message: String) {
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        outputLog = "[\(stamp)]\n\(message)\n\n" + outputLog
    }
}
