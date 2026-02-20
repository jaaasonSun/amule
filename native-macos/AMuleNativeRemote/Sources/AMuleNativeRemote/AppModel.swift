import Foundation
import SwiftUI
import AppKit

@MainActor
final class AppModel: ObservableObject {
    @AppStorage("amule.commandPath") var commandPath: String = AMuleConnectionConfig.preferredDefaultPath()
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
        .init(commandPath: commandPath, host: host, port: port, password: password)
    }

    func ensurePreferredCommandPath() {
        guard let bundled = AMuleConnectionConfig.bundledCommandPath else {
            return
        }
        let current = commandPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if current.isEmpty ||
            current == AMuleConnectionConfig.legacyFallbackCommandPath ||
            !FileManager.default.isExecutableFile(atPath: current) {
            commandPath = bundled
        }
    }

    func connectAll() {
        run(label: "connect") {
            try await self.connectNow()
        }
    }

    func disconnectAll() {
        run(label: "disconnect") {
            let output = try await AMuleCmdClient.runCommand("disconnect", config: self.config)
            await MainActor.run {
                self.appendLog("$ disconnect\n\(output)")
                self.isSessionConnected = false
            }
            await self.refreshStatus(logOutput: false)
        }
    }

    func refreshStatus(logOutput: Bool = true, suppressErrors: Bool = false) async {
        do {
            let output = try await AMuleCmdClient.runCommand("status", config: config)
            await MainActor.run {
                self.status = StatusSnapshot.fromOutput(output)
                if logOutput {
                    self.appendLog("$ status\n\(output)")
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
            let cmd = "search \(self.searchScope) \(query)"
            var commands = [cmd]
            for _ in 0..<10 {
                commands.append("progress")
                commands.append("results")
            }
            let transcript = try await AMuleCmdClient.runScriptWithDelays(
                commands,
                delayBetweenCommandsNanoseconds: 900_000_000,
                config: self.config
            )
            let parsed = CommandOutputParser.parseSearchResults(transcript)

            await MainActor.run {
                self.searchResults = parsed
                self.lastSearchRawOutput = transcript
                self.searchStatusMessage = parsed.isEmpty ? "No results yet. Try again in a few seconds." : "Found \(parsed.count) result(s)."
                self.appendLog(transcript)
            }
        }
    }

    func downloadResult(_ result: SearchResult) {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        run(label: "download") {
            let commands = [
                "search \(self.searchScope) \(query)",
                "results",
                "download \(result.id)",
                "show dl"
            ]
            let output = try await AMuleCmdClient.runScript(commands, config: self.config)
            let parsed = CommandOutputParser.parseDownloads(output)
            await MainActor.run {
                self.downloads = parsed
                self.appendLog("$ \(commands.joined(separator: " ; "))\n\(output)")
            }
            await self.refreshStatus(logOutput: false)
        }
    }

    func refreshDownloads() {
        run(label: "show dl") {
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
            try await self.runDownloadAction("pause \(item.id)")
        }
    }

    func resumeDownload(_ item: DownloadItem) {
        run(label: "resume") {
            try await self.runDownloadAction("resume \(item.id)")
        }
    }

    func removeDownload(_ item: DownloadItem) {
        run(label: "cancel") {
            try await self.runDownloadAction("cancel \(item.id)")
        }
    }

    func setDownloadPriority(_ item: DownloadItem, _ priority: String) {
        run(label: "priority") {
            try await self.runDownloadAction("priority \(priority) \(item.id)")
        }
    }

    func startAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task {
            while !Task.isCancelled {
                if self.isSessionConnected {
                    await self.refreshStatus(logOutput: false, suppressErrors: true)
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
                }
            }
            await MainActor.run {
                self.isBusy = false
            }
        }
    }

    private func refreshDownloadsNow() async throws {
        let output = try await AMuleCmdClient.runCommand("show dl", config: config)
        let parsed = CommandOutputParser.parseDownloads(output)
        await MainActor.run {
            self.downloads = parsed
            self.lastDownloadsRawOutput = output
            self.appendLog("$ show dl\n\(output)")
        }
    }

    private func connectNow() async throws {
        let output = try await AMuleCmdClient.runCommand("connect", config: self.config)
        await MainActor.run {
            self.appendLog("$ connect\n\(output)")
            self.isSessionConnected = true
        }
        await self.refreshStatus(logOutput: false)
        try await self.refreshDownloadsNow()
    }

    private func runDownloadAction(_ actionCommand: String) async throws {
        let output = try await AMuleCmdClient.runScript([actionCommand, "show dl"], config: config)
        let parsed = CommandOutputParser.parseDownloads(output)
        await MainActor.run {
            self.downloads = parsed
            self.lastDownloadsRawOutput = output
            self.appendLog("$ \(actionCommand) ; show dl\n\(output)")
        }
        await self.refreshStatus(logOutput: false)
    }

    private func appendLog(_ message: String) {
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        outputLog = "[\(stamp)]\n\(message)\n\n" + outputLog
    }
}
