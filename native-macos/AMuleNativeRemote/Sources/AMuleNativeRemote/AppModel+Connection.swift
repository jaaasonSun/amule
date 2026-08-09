import Foundation
import AMuleECBridgeAdapter
import SharedModels
import SharedServices

extension AppModel {
    func refreshBridgeCapabilities(logOutput: Bool = false, suppressErrors: Bool = true) async {
        do {
            let (schemaVersion, capabilities, raw) = try await bridge.capabilities(config: config)
            await MainActor.run {
                self.bridgeSchemaVersion = schemaVersion
                self.bridgeOps = Set(capabilities.ops)
                if logOutput {
                    self.appendLog("$ capabilities\n\(raw)")
                }
            }
        } catch {
            await MainActor.run {
                if !suppressErrors {
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    func refreshBridgeCapabilitiesAndPreloadCategories(logOutput: Bool = false, suppressErrors: Bool = true) async {
        await refreshBridgeCapabilities(logOutput: logOutput, suppressErrors: suppressErrors)
        await refreshCategoriesIfSupported(logOutput: false, suppressErrors: true)
    }

    func requestConnectionSheet() {
        connectionSheetRequestID &+= 1
    }

    func refreshCategoriesIfSupported(logOutput: Bool = false, suppressErrors: Bool = true) async {
        try? await refreshCategoriesNow(logOutput: logOutput, suppressErrors: suppressErrors)
    }

    func connectAll() {
        run(label: "connect") {
            try await self.connectNow()
        }
    }

    func disconnectAll() {
        run(label: "disconnect") {
            let (_, raw) = try await self.bridge.disconnect(config: self.config)
            await MainActor.run {
                self.appendLog("$ disconnect\n\(raw)")
                self.isSessionConnected = false
            }
            await self.refreshStatus(logOutput: false)
        }
    }

    func refreshStatus(logOutput: Bool = true, suppressErrors: Bool = false) async {
        let session = currentSessionCoordinator()
        do {
            guard let (bridgeStatus, raw) = try await session.coordinator.manualRefreshStatus(),
                  isCurrentSession(session) else {
                return
            }
            applyStatusRefresh(bridgeStatus, raw: raw, logOutput: logOutput)
        } catch {
            guard isCurrentSession(session) else { return }
            handleStatusRefreshError(error, suppressErrors: suppressErrors)
        }
    }

    func mutationRefreshStatus(logOutput: Bool = true, suppressErrors: Bool = false) async {
        let session = currentSessionCoordinator()
        do {
            guard let (bridgeStatus, raw) = try await session.coordinator.mutationRefreshStatus(),
                  isCurrentSession(session) else {
                return
            }
            applyStatusRefresh(bridgeStatus, raw: raw, logOutput: logOutput)
        } catch {
            guard isCurrentSession(session) else { return }
            handleStatusRefreshError(error, suppressErrors: suppressErrors)
        }
    }

    private func pollStatus(logOutput: Bool, suppressErrors: Bool) async {
        let session = currentSessionCoordinator()
        do {
            guard let (bridgeStatus, raw) = try await session.coordinator.pollStatus(),
                  isCurrentSession(session) else {
                return
            }
            applyStatusRefresh(bridgeStatus, raw: raw, logOutput: logOutput)
        } catch {
            guard isCurrentSession(session) else { return }
            handleStatusRefreshError(error, suppressErrors: suppressErrors)
        }
    }

    func startAutoRefresh(intervalNanoseconds: UInt64 = 1_000_000_000) {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task {
            var tick: Int = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalNanoseconds)
                guard !Task.isCancelled else { break }
                await self.pollStatus(logOutput: false, suppressErrors: true)
                if self.isSessionConnected, self.shouldAutoRefreshDownloads {
                    try? await self.pollDownloadsNow(logOutput: false, suppressErrors: true)
                }
                if self.isSessionConnected, tick % 5 == 0 {
                    try? await self.pollServersNow(logOutput: false, suppressErrors: true)
                }
                tick += 1
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

    func resetLog() {
        outputLog = ""
        guard isSessionConnected, isBridgeOpSupported("log") else { return }
        run(label: "reset-log") {
            let (_, raw) = try await self.bridge.resetLog(config: self.config)
            await MainActor.run {
                self.appendLog("$ reset-log\n\(raw)")
            }
        }
    }

    func copyLogToClipboard() {
        pasteboardShare.writeString(outputLog)
    }

    func copyDownloadsRawToClipboard() {
        pasteboardShare.writeString(lastDownloadsRawOutput)
    }

    func copySearchRawToClipboard() {
        pasteboardShare.writeString(lastSearchRawOutput)
    }

    func copyServersRawToClipboard() {
        pasteboardShare.writeString(lastServersRawOutput)
    }

    func copySourcesRawToClipboard() {
        pasteboardShare.writeString(lastSourcesRawOutput)
    }

    func copyUploadsRawToClipboard() {
        pasteboardShare.writeString(lastUploadsRawOutput)
    }

    func copySharedFilesRawToClipboard() {
        pasteboardShare.writeString(lastSharedFilesRawOutput)
    }

    func copyCoreLogRawToClipboard() {
        pasteboardShare.writeString(lastCoreLogRawOutput)
    }

    func copyCoreDebugLogRawToClipboard() {
        pasteboardShare.writeString(lastCoreDebugLogRawOutput)
    }

    func copyDownloadLinkToClipboard(_ item: DownloadItem) {
        pasteboardShare.writeString(item.ed2kLink)
    }

    func run(label: String, _ work: @escaping () async throws -> Void) {
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

    func connectNow() async throws {
        let (_, raw) = try await bridge.connect(config: self.config)
        await MainActor.run {
            self.appendLog("$ connect\n\(raw)")
            self.isSessionConnected = true
        }
        await self.refreshBridgeCapabilitiesAndPreloadCategories(logOutput: false, suppressErrors: true)
        await self.refreshStatus(logOutput: false)
        try await self.refreshDownloadsNow()
        try await self.refreshServersNow(logOutput: false, suppressErrors: true)
    }

    private func applyStatusRefresh(_ bridgeStatus: BridgeStatusPayload, raw: String, logOutput: Bool) {
        status = StatusSnapshot.fromBridge(bridgeStatus)
        if logOutput {
            appendLog("$ status\n\(raw)")
        }
        isSessionConnected = status.looksConnected
    }

    private func handleStatusRefreshError(_ error: Error, suppressErrors: Bool) {
        if !suppressErrors {
            lastError = error.localizedDescription
        }
        isSessionConnected = false
    }

    private func pollServersNow(logOutput: Bool, suppressErrors: Bool) async throws {
        let session = currentSessionCoordinator()
        do {
            guard let (payload, raw) = try await session.coordinator.pollServers(),
                  isCurrentSession(session) else {
                return
            }
            let parsed = ServerItem.fromBridge(payload)
            servers = parsed
            lastServersRawOutput = raw
            if logOutput {
                appendLog("$ servers\n\(raw)")
            }
        } catch {
            guard isCurrentSession(session) else { return }
            if !suppressErrors {
                lastError = error.localizedDescription
            }
            throw error
        }
    }

    func appendLog(_ message: String) {
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        outputLog = "[\(stamp)]\n\(message)\n\n" + outputLog
    }
}
