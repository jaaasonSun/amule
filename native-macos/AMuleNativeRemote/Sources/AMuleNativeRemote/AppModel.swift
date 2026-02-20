import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @AppStorage("amule.commandPath") var commandPath: String = AMuleConnectionConfig.preferredDefaultPath()
    @AppStorage("amule.host") var host: String = "127.0.0.1"
    @AppStorage("amule.port") var port: Int = 4712
    @AppStorage("amule.password") var password: String = ""

    @Published var status: StatusSnapshot = .init()
    @Published var searchQuery: String = ""
    @Published var searchScope: String = "kad"
    @Published var searchResults: [SearchResult] = []
    @Published var downloads: [DownloadItem] = []
    @Published var isBusy = false
    @Published var outputLog = ""
    @Published var lastError = ""

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
            let output = try await AMuleCmdClient.runCommand("connect", config: self.config)
            await MainActor.run {
                self.appendLog("$ connect\n\(output)")
            }
            await self.refreshStatus()
        }
    }

    func disconnectAll() {
        run(label: "disconnect") {
            let output = try await AMuleCmdClient.runCommand("disconnect", config: self.config)
            await MainActor.run {
                self.appendLog("$ disconnect\n\(output)")
            }
            await self.refreshStatus()
        }
    }

    func refreshStatus() async {
        do {
            let output = try await AMuleCmdClient.runCommand("status", config: config)
            await MainActor.run {
                self.status = StatusSnapshot.fromOutput(output)
                self.appendLog("$ status\n\(output)")
            }
        } catch {
            await MainActor.run {
                self.lastError = error.localizedDescription
            }
        }
    }

    func performSearch() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        run(label: "search") {
            let cmd = "search \(self.searchScope) \(query)"
            let output = try await AMuleCmdClient.runScript([cmd, "results"], config: self.config)
            let parsed = CommandOutputParser.parseSearchResults(output)
            await MainActor.run {
                self.searchResults = parsed
                self.appendLog("$ \(cmd) + results\n\(output)")
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
            await self.refreshStatus()
        }
    }

    func refreshDownloads() {
        run(label: "show dl") {
            let output = try await AMuleCmdClient.runCommand("show dl", config: self.config)
            let parsed = CommandOutputParser.parseDownloads(output)
            await MainActor.run {
                self.downloads = parsed
                self.appendLog("$ show dl\n\(output)")
            }
        }
    }

    func resetLog() {
        outputLog = ""
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

    private func appendLog(_ message: String) {
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        outputLog = "[\(stamp)]\n\(message)\n\n" + outputLog
    }
}
