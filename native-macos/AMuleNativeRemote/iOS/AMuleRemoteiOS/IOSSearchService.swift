#if canImport(UIKit)
import SwiftUI
import AMuleRemoteIOSShared
import AMuleECClient
import SharedUI

@MainActor
struct IOSSearchService {
    func addLinks(_ rawInput: String, model: IOSAppModel) {
        guard let importPlan = LinkImportPlan(rawInput: rawInput) else {
            model.lastError = L("No valid links found.")
            return
        }

        model.isBusy = true
        model.lastError = ""
        model.downloadFeedback = LF("%lld link(s) queued for import", Int64(importPlan.count))
        let config = model.config
        let bridge = model.bridgeClient
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
                        model.lastError = model.localNetworkErrorPresenter.userFacingMessage(for: error)
                    }
                }
            }

            do {
                let (payloads, _) = try await bridge.downloads(config: config)
                await MainActor.run {
                    model.downloads = DownloadItem.fromBridge(payloads)
                    model.downloadFeedback = IOSAppModel.linkImportFeedback(
                        LinkImportOutcome(successCount: successCount, failureCount: failureCount)
                    )
                    model.isBusy = false
                }
            } catch {
                await MainActor.run {
                    model.downloadFeedback = IOSAppModel.linkImportFeedback(
                        LinkImportOutcome(successCount: successCount, failureCount: failureCount)
                    )
                    model.isBusy = false
                }
            }
        }
    }

    func enqueueIncomingLink(_ rawInput: String, model: IOSAppModel) {
        model.deepLinkInboxHandler.enqueueIncomingLink(rawInput)
        if model.isSessionConnected {
            flushIncomingLinks(model: model)
        }
    }

    func flushIncomingLinks(model: IOSAppModel) {
        let links = model.deepLinkInboxHandler.drainIncomingLinks()
        guard !links.isEmpty else { return }
        addLinks(links.joined(separator: "\n"), model: model)
    }

    func performSearch(query: String, scope: String?, model: IOSAppModel) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !model.isSearchInProgress else { return }

        let effectiveScope = scope ?? model.searchScope
        model.isSearchInProgress = true
        model.searchProgress = 0
        model.lastError = ""

        let config = model.config
        let bridge = model.bridgeClient
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
                    model.searchProgress = max(0, min(100, progress))
                    model.searchResults = SearchResult.fromBridge(results)
                    model.isSearchInProgress = false
                }
            } catch {
                await MainActor.run {
                    model.lastError = model.localNetworkErrorPresenter.userFacingMessage(for: error)
                    model.isSearchInProgress = false
                }
            }
        }
    }

    func downloadSearchResult(_ result: SearchResult, model: IOSAppModel) {
        guard !result.hash.isEmpty else {
            model.lastError = L("Cannot download: missing file hash.")
            return
        }
        model.isBusy = true
        let config = model.config
        let bridge = model.bridgeClient
        Task {
            do {
                let _ = try await bridge.download(hash: result.hash, config: config)
                await MainActor.run {
                    model.downloadFeedback = LF("Added to downloads: %@", result.name)
                    model.isBusy = false
                }
                await MainActor.run {
                    model.refreshDownloads()
                }
            } catch {
                await MainActor.run {
                    model.lastError = model.localNetworkErrorPresenter.userFacingMessage(for: error)
                    model.isBusy = false
                }
            }
        }
    }
}
#endif
