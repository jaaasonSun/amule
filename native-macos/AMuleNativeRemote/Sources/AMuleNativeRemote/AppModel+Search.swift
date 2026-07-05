import Foundation
import AMuleECClient
import SharedModels
import SharedServices

extension AppModel {
    func performSearch() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        guard !isSearchInProgress else { return }

        let request: ECSearchRequest
        do {
            request = try searchOptions.ecRequest(scope: searchScope, query: query)
        } catch SearchOptionsError.invalidNumber(let value) {
            lastError = LF3("Invalid search number: %@", value)
            appendLog("! search failed\n\(lastError)")
            return
        } catch {
            lastError = error.localizedDescription
            appendLog("! search failed\n\(error.localizedDescription)")
            return
        }

        lastError = ""
        searchProgress = 0
        searchResults = []
        isSearchInProgress = true

        let currentConfig = config

        searchTask?.cancel()
        searchTask = Task {
            defer {
                self.isSearchInProgress = false
                self.searchTask = nil
            }

            do {
                let (progress, payload, raw) = try await self.bridge.search(
                    request: request,
                    polls: 12,
                    pollIntervalMs: 900,
                    config: currentConfig
                )
                let parsed = SearchResult.fromBridge(payload)

                await MainActor.run {
                    self.searchProgress = max(0, min(100, progress))
                    self.searchResults = parsed
                    self.lastSearchRawOutput = raw
                    self.appendLog("$ search \(request.scope) \(request.query)\n\(raw)")
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
                let (_, raw) = try await self.bridge.searchStop(config: self.config)
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
                    let (_, raw) = try await self.bridge.download(hash: result.hash, config: self.config)
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
}
