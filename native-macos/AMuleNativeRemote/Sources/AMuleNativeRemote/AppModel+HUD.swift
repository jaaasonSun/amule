import Foundation
import SharedViews
import SwiftUI
import SharedModels
import SharedServices

extension AppModel {
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

    func addLinks(_ rawInput: String) {
        let diagnostics = LinkImportDiagnostics.analyze(rawInput: rawInput)

        guard !diagnostics.validNormalizedLinks.isEmpty else {
            lastError = Self.composeAddLinksErrorMessage(items: diagnostics.items)
            return
        }

        presentHUD(message: LF3("Adding %lld link(s)...", Int64(diagnostics.validNormalizedLinks.count)), autoDismissAfter: nil)

        run(label: "add-link") {
            let beforeHashes = Set(self.downloads.map { $0.id.uppercased() })
            var processedLinks: [String] = []
            var bridgeOutcomeItems: [LinkImportDiagnosticItem] = []

            var successCount = 0

            for normalized in diagnostics.validNormalizedLinks {
                do {
                    let (_, raw) = try await self.bridge.addLink(link: normalized, config: self.config)
                    await MainActor.run {
                        self.appendLog("$ add-link \(normalized)\n\(raw)")
                    }
                    successCount += 1
                    processedLinks.append(normalized)
                } catch {
                    let preview = Self.compactAddLinkPreview(normalized)
                    bridgeOutcomeItems.append(.init(kind: .failedLink, line: preview, detail: error.localizedDescription))
                    await MainActor.run {
                        self.appendLog("! add-link \(preview)\n\(error.localizedDescription)")
                    }
                }
            }

            var actualAddedCount = 0
            var postRefreshOutcomeItems: [LinkImportDiagnosticItem] = []
            if successCount > 0 {
                try await self.mutationRefreshDownloadsNow(logOutput: false)
                let afterHashes = Set(self.downloads.map { $0.id.uppercased() })

                for normalized in processedLinks {
                    let preview = Self.compactAddLinkPreview(normalized)
                    guard let hash = LinkImportSupport.extractEd2kHash(from: normalized) else {
                        postRefreshOutcomeItems.append(.init(kind: .unverifiable, line: preview, detail: "could not verify link"))
                        continue
                    }

                    if beforeHashes.contains(hash) {
                        postRefreshOutcomeItems.append(.init(kind: .alreadyPresentOrSkipped, line: preview, detail: "already present"))
                    } else if afterHashes.contains(hash) {
                        actualAddedCount += 1
                    } else {
                        postRefreshOutcomeItems.append(.init(kind: .acceptedButNotVisible, line: preview, detail: "accepted but not visible"))
                    }
                }

                await self.mutationRefreshStatus(logOutput: false, suppressErrors: true)
            }

            let combinedItems = diagnostics.items + bridgeOutcomeItems + postRefreshOutcomeItems
            let actionableItems = combinedItems.filter { $0.kind != .validNormalizedLink }

            await MainActor.run {
                if actionableItems.isEmpty {
                    self.lastError = ""
                    self.presentHUD(message: LF3("Added %lld link(s)", Int64(actualAddedCount)))
                } else {
                    let failureCount = bridgeOutcomeItems.filter { $0.kind == .failedLink }.count
                    let skippedCount = postRefreshOutcomeItems.filter { $0.kind == .alreadyPresentOrSkipped }.count
                    let invisibleCount = postRefreshOutcomeItems.filter { $0.kind == .acceptedButNotVisible }.count

                    if failureCount > 0 {
                        self.presentHUD(message: LF3(
                            "Added %lld link(s), failed %lld.",
                            Int64(actualAddedCount),
                            Int64(failureCount)
                        ))
                    } else if skippedCount > 0 || invisibleCount > 0 {
                        self.presentHUD(message: LF3("Added %lld link(s)", Int64(actualAddedCount)))
                    } else {
                        self.presentHUD(message: LF3("Added %lld link(s)", Int64(actualAddedCount)))
                    }

                    self.lastError = Self.composeAddLinksErrorMessage(items: actionableItems)
                }
            }
        }
    }

    private static func composeAddLinksErrorMessage(items: [LinkImportDiagnosticItem]) -> String {
        let presentation = LinkImportDiagnosticsFormatter.format(diagnostics: .init(items: items))
        var lines = [presentation.summaryText]
        lines.append(contentsOf: items.compactMap { composeAddLinkDetailLine(for: $0) })
        return lines
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
    }

    private static func composeAddLinkDetailLine(for item: LinkImportDiagnosticItem) -> String? {
        let preview = compactAddLinkPreview(item.line)
        switch item.kind {
        case .ignoredUnsupportedLine:
            return LF3("Ignored unsupported line: %@", preview)
        case .duplicateNormalizedLink:
            return LF3("Duplicate normalized link skipped: %@", preview)
        case .malformedHash:
            return LF3("Malformed hash: %@", preview)
        case .failedLink:
            if let detail = item.detail, !detail.isEmpty {
                return LF3("Bridge failed for %@: %@", preview, detail)
            }
            return LF3("Bridge failed for %@", preview)
        case .alreadyPresentOrSkipped:
            return LF3("Already present or skipped: %@", preview)
        case .acceptedButNotVisible:
            return LF3("Accepted but not visible: %@", preview)
        case .unverifiable:
            if let detail = item.detail, !detail.isEmpty {
                return LF3("Unverifiable: %@ — %@", preview, detail)
            }
            return LF3("Unverifiable: %@", preview)
        case .validNormalizedLink:
            return nil
        }
    }

    private static func compactAddLinkPreview(_ link: String) -> String {
        let limit = 120
        if link.count <= limit { return link }
        let suffix = "…"
        return String(link.prefix(limit - suffix.count)) + suffix
    }

    func presentHUD(message: String) {
        presentHUD(message: message, autoDismissAfter: 2_000_000_000)
    }

    func presentHUD(message: String, autoDismissAfter nanoseconds: UInt64?) {
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

    func hideHUD() {
        hudDismissTask?.cancel()
        hudDismissTask = nil
        withAnimation(.easeIn(duration: 0.18)) {
            showHUD = false
        }
    }
}
