import Foundation
import SharedViews
import AMuleECClient
import AMuleECBridgeAdapter
import SharedModels
import SharedServices

extension AppModel {
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
            downloadSourceErrorsByHash[item.id] = nil
            isRefreshingSources = false
            return
        }

        isRefreshingSources = true
        lastError = ""
        downloadSourceErrorsByHash[item.id] = nil
        Task {
            do {
                try await self.refreshDownloadSourcesNow(for: item)
            } catch {
                await MainActor.run {
                    if let clientError = error as? AMuleClientError, clientError.isDownloadNotFound {
                        self.downloadSourcesByHash[item.id] = []
                        self.downloadSourceErrorsByHash[item.id] = nil
                    } else {
                        let message = error.localizedDescription
                        self.lastError = message
                        self.downloadSourceErrorsByHash[item.id] = message
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

    func sourceError(for item: DownloadItem?) -> String? {
        guard let item else { return nil }
        return downloadSourceErrorsByHash[item.id]
    }

    func clearCompletedDownloads(_ items: [DownloadItem]) {
        let ecids = items.map(\.ecid)
        guard !ecids.isEmpty else { return }

        run(label: "clear-completed") {
            let (_, raw) = try await self.bridge.clearCompleted(ecids: ecids, config: self.config)
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

    func stopDownload(_ item: DownloadItem) {
        run(label: "download-stop") {
            let (_, raw) = try await self.bridge.stop(hash: item.id, config: self.config)
            await MainActor.run {
                self.appendLog("$ download-stop \(item.id)\n\(raw)")
            }
            try await self.refreshDownloadsNow(logOutput: false)
            await self.refreshStatus(logOutput: false)
        }
    }

    func swapA4AF(_ item: DownloadItem, mode: ECOperations.A4AFSwapMode) {
        run(label: "download-a4af") {
            let (_, raw) = try await self.bridge.swapA4AF(hash: item.id, mode: mode, config: self.config)
            await MainActor.run {
                self.appendLog("$ download-a4af \(item.id)\n\(raw)")
            }
            try await self.refreshDownloadsNow(logOutput: false)
        }
    }

    func setDownloadCategory(_ item: DownloadItem, categoryID: Int) {
        run(label: "download-set-category") {
            let (_, raw) = try await self.bridge.downloadSetCategory(hash: item.id, categoryID: categoryID, config: self.config)
            await MainActor.run {
                self.appendLog("$ download-set-category \(item.id) \(categoryID)\n\(raw)")
            }
            try await self.refreshDownloadsNow(logOutput: false)
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
            let acknowledgement = try await self.bridge.rename(hash: item.id, name: trimmed, config: self.config)
            await MainActor.run {
                self.appendLog("$ rename \(item.id) \(trimmed)\n\(acknowledgement.raw)")
            }

            guard acknowledgement.requiresPostRefreshVerification else {
                await MainActor.run {
                    self.lastError = acknowledgement.verificationFailureMessage
                }
                return
            }

            let didApply = try await self.waitForRenameVerification(
                downloadID: item.id,
                newName: trimmed
            )
            guard !didApply else { return }

            await MainActor.run {
                self.lastError = acknowledgement.verificationFailureMessage
            }
        }
    }

    private func waitForRenameVerification(downloadID: String, newName: String) async throws -> Bool {
        let attempts = await MainActor.run { max(1, self.renameVerificationMaxAttempts) }
        for attempt in 0..<attempts {
            try await self.refreshDownloadsNow(logOutput: false)
            let didApply = await MainActor.run {
                RenameVerification.wasApplied(
                    downloadID: downloadID,
                    newName: newName,
                    downloads: self.downloads
                )
            }
            if didApply {
                return true
            }

            guard attempt + 1 < attempts else { break }
            let delay = await MainActor.run { self.renameVerificationRetryDelayNanoseconds }
            if delay > 0 {
                try await Task.sleep(nanoseconds: delay)
            }
        }
        return false
    }

    func requestRenameSuggestion(_ item: DownloadItem, suggestion: String) {
        guard let draft = FilenameSuggestionPresentation.renameDraft(from: suggestion, currentName: item.name) else { return }
        selectedDownloadID = item.id
        pendingRenameSuggestionRequest = DownloadRenameSuggestionRequest(downloadID: item.id, suggestion: draft)
        renameSuggestionRequestID &+= 1
    }

    func consumeRenameSuggestionRequest(for downloadID: String) -> String? {
        guard let request = pendingRenameSuggestionRequest, request.downloadID == downloadID else {
            return nil
        }
        pendingRenameSuggestionRequest = nil
        return request.suggestion
    }

    func setDownloadPriority(_ item: DownloadItem, _ priority: String) {
        run(label: "priority") {
            try await self.runDownloadAction(.priority(priority), item)
        }
    }

    func refreshDownloadsNow(logOutput: Bool = true, suppressErrors: Bool = false) async throws {
        do {
            let (payload, raw) = try await bridge.downloads(config: config)
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

    func refreshDownloadSourcesNow(for item: DownloadItem, logOutput: Bool = true) async throws {
        let (payloads, raw) = try await bridge.sources(hash: item.id, config: config)
        let parsed = DownloadSourceItem.fromBridge(payloads)
        await MainActor.run {
            self.downloadSourcesByHash[item.id] = parsed
            self.downloadSourceErrorsByHash[item.id] = nil
            self.lastSourcesRawOutput = raw
            if logOutput {
                self.appendLog("$ sources \(item.id)\n\(raw)")
            }
        }
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
            raw = try await bridge.pause(hash: item.id, config: config).raw
            commandLabel = "pause \(item.id)"
        case .resume:
            raw = try await bridge.resume(hash: item.id, config: config).raw
            commandLabel = "resume \(item.id)"
        case .cancel:
            raw = try await bridge.cancel(hash: item.id, config: config).raw
            commandLabel = "cancel \(item.id)"
        case .priority(let value):
            raw = try await bridge.priority(hash: item.id, value: value, config: config).raw
            commandLabel = "priority \(value) \(item.id)"
        }
        return (commandLabel, raw)
    }
}
