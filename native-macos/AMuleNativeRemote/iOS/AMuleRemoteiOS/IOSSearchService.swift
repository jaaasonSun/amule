#if canImport(UIKit)
import SwiftUI
import AMuleECClient
import SharedModels
import SharedServices
import SharedViews

@MainActor
struct IOSSearchService {
    func addLinks(_ rawInput: String, model: IOSAppModel) {
        let diagnostics = LinkImportDiagnostics.analyze(rawInput: rawInput)
        let presentation = LinkImportDiagnosticsFormatter.format(diagnostics: diagnostics)
        let validLinks = diagnostics.validNormalizedLinks
        let diagnosticDetails = presentation.detailLines
            .filter { !$0.hasPrefix("Added ") }
            .joined(separator: "\n")

        guard !validLinks.isEmpty else {
            model.lastError = diagnosticDetails.isEmpty ? (presentation.summaryText.isEmpty ? L("No valid links found.") : presentation.summaryText) : diagnosticDetails
            return
        }

        model.isBusy = true
        model.lastError = ""
        model.downloadFeedback = presentation.summaryText
        let config = model.config
        let bridge = model.bridgeClient
        let session = model.currentSessionCoordinator()
        Task {
            var successCount = 0
            var failureCount = 0
            var lastFailureReason: String?

            for normalized in validLinks {
                do {
                    let _ = try await bridge.addLink(link: normalized, config: config)
                    successCount += 1
                } catch {
                    failureCount += 1
                    lastFailureReason = await MainActor.run {
                        model.localNetworkErrorPresenter.userFacingMessage(for: error)
                    }
                    await MainActor.run {
                        guard model.isCurrentSession(session) else { return }
                        model.lastError = lastFailureReason ?? model.lastError
                    }
                }
            }

            do {
                guard model.isCurrentSession(session) else { return }
                let refresh = try await session.coordinator.mutationRefreshDownloads()
                await MainActor.run {
                    guard model.isCurrentSession(session) else { return }
                    if let (payloads, _) = refresh {
                        model.downloads = DownloadItem.fromBridge(payloads)
                    }
                    model.downloadFeedback = IOSAppModel.linkImportFeedback(
                        LinkImportOutcome(successCount: successCount, failureCount: failureCount)
                    )
                    if failureCount > 0 {
                        model.lastError = lastFailureReason ?? LF("%lld link(s) failed", Int64(failureCount))
                    } else if !diagnosticDetails.isEmpty {
                        model.lastError = diagnosticDetails
                    }
                    model.isBusy = false
                }
            } catch {
                await MainActor.run {
                    guard model.isCurrentSession(session) else { return }
                    model.downloadFeedback = IOSAppModel.linkImportFeedback(
                        LinkImportOutcome(successCount: successCount, failureCount: failureCount)
                    )
                    if failureCount > 0 {
                        model.lastError = lastFailureReason ?? LF("%lld link(s) failed", Int64(failureCount))
                    } else if !diagnosticDetails.isEmpty {
                        model.lastError = diagnosticDetails
                    }
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
        let session = model.currentSessionCoordinator()
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
                    guard model.isCurrentSession(session) else { return }
                    model.searchProgress = max(0, min(100, progress))
                    model.searchResults = SearchResult.fromBridge(results)
                    model.isSearchInProgress = false
                }
            } catch {
                await MainActor.run {
                    guard model.isCurrentSession(session) else { return }
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
        let session = model.currentSessionCoordinator()
        Task {
            do {
                let _ = try await bridge.download(hash: result.hash, config: config)
                await MainActor.run {
                    guard model.isCurrentSession(session) else { return }
                    model.downloadFeedback = LF("Added to downloads: %@", result.name)
                    model.isBusy = false
                }
                guard model.isCurrentSession(session) else { return }
                if let (payloads, _) = try await session.coordinator.mutationRefreshDownloads() {
                    await MainActor.run {
                        guard model.isCurrentSession(session) else { return }
                        model.downloads = DownloadItem.fromBridge(payloads)
                    }
                }
            } catch {
                await MainActor.run {
                    guard model.isCurrentSession(session) else { return }
                    model.lastError = model.localNetworkErrorPresenter.userFacingMessage(for: error)
                    model.isBusy = false
                }
            }
        }
    }
}
#endif
