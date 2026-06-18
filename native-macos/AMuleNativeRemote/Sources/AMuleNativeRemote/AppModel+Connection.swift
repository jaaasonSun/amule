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
        do {
            let (bridgeStatus, raw) = try await bridge.status(config: config)
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

    func startAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task {
            var tick: Int = 0
            while !Task.isCancelled {
                if self.isSessionConnected {
                    await self.refreshStatus(logOutput: false, suppressErrors: true)
                    if self.shouldAutoRefreshDownloads {
                        try? await self.refreshDownloadsNow(logOutput: false, suppressErrors: true)
                    }
                    if tick % 5 == 0 {
                        try? await self.refreshServersNow(logOutput: false, suppressErrors: true)
                    }
                }
                tick += 1
                try? await Task.sleep(nanoseconds: 1_000_000_000)
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
                    if self.showHUD, self.hudDismissTask == nil {
                        self.hideHUD()
                    }
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
        await self.refreshBridgeCapabilities(logOutput: false, suppressErrors: true)
        await self.refreshStatus(logOutput: false)
        try await self.refreshDownloadsNow()
        try await self.refreshServersNow(logOutput: false, suppressErrors: true)
    }

    func appendLog(_ message: String) {
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        outputLog = "[\(stamp)]\n\(message)\n\n" + outputLog
    }
}
