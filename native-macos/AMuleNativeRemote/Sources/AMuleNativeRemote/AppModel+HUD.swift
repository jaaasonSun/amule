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
        guard let importPlan = LinkImportPlan(rawInput: rawInput) else {
            lastError = L3("No valid links found.")
            return
        }

        presentHUD(message: LF3("Adding %lld link(s)...", Int64(importPlan.count)), autoDismissAfter: nil)

        run(label: "add-link") {
            let beforeHashes = Set(self.downloads.map { $0.id.uppercased() })

            var successCount = 0
            var failureCount = 0

            for (index, link) in importPlan.links.enumerated() {
                do {
                    let normalized = importPlan.normalizedLinks[index]
                    let (_, raw) = try await self.bridge.addLink(link: normalized, config: self.config)
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
                try await self.mutationRefreshDownloadsNow(logOutput: false)
                let afterHashes = Set(self.downloads.map { $0.id.uppercased() })

                if importPlan.requestedHashes.isEmpty {
                    actualAddedCount = max(0, afterHashes.count - beforeHashes.count)
                } else {
                    actualAddedCount = importPlan.requestedHashes.reduce(into: 0) { total, hash in
                        if !beforeHashes.contains(hash) && afterHashes.contains(hash) {
                            total += 1
                        }
                    }
                }

                await self.mutationRefreshStatus(logOutput: false, suppressErrors: true)
            }

            await MainActor.run {
                if failureCount > 0 {
                    self.presentHUD(message: LF3(
                        "Added %lld link(s), failed %lld.",
                        Int64(actualAddedCount),
                        Int64(failureCount)
                    ))
                    self.lastError = LF3(
                        "Added %lld link(s), failed %lld.",
                        Int64(actualAddedCount),
                        Int64(failureCount)
                    )
                } else {
                    self.presentHUD(message: LF3("Added %lld link(s)", Int64(actualAddedCount)))
                }
            }
        }
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
