import Foundation
import SharedViews
import SharedModels
import SharedServices

extension AppModel {
    func refreshConnectionPrefs() {
        guard isBridgeOpSupported("prefs-connection-get") else { return }
        run(label: "prefs-connection-get") {
            try await self.refreshConnectionPrefsNow()
        }
    }

    func setConnectionSpeedLimits(maxDL rawMaxDL: String, maxUL rawMaxUL: String) {
        guard isBridgeOpSupported("prefs-connection-set") else { return }

        let limits: TransferLimitSettings
        do {
            limits = try TransferLimitSettings(downloadText: rawMaxDL, uploadText: rawMaxUL)
        } catch TransferLimitValidationError.invalidDownload {
            lastError = L3("Invalid download speed limit. Use a non-negative integer.")
            return
        } catch TransferLimitValidationError.invalidUpload {
            lastError = L3("Invalid upload speed limit. Use a non-negative integer.")
            return
        } catch {
            lastError = error.localizedDescription
            return
        }

        run(label: "prefs-connection-set") {
            let (_, raw) = try await self.bridge.prefsConnectionSet(
                maxDownload: limits.maxDownload,
                maxUpload: limits.maxUpload,
                config: self.config
            )
            await MainActor.run {
                self.appendLog("$ prefs-connection-set --max-dl \(limits.maxDownload) --max-ul \(limits.maxUpload)\n\(raw)")
            }
            if self.isBridgeOpSupported("prefs-connection-get") {
                try await self.refreshConnectionPrefsNow(logOutput: false, suppressErrors: true)
            }
        }
    }

    func refreshConnectionPrefsNow(logOutput: Bool = true, suppressErrors: Bool = false) async throws {
        do {
            let (payload, raw) = try await bridge.prefsConnectionGet(config: config)
            await MainActor.run {
                self.connectionMaxDownloadKBps = payload.maxDownload
                self.connectionMaxUploadKBps = payload.maxUpload
                self.connectionMaxDownloadInput = String(payload.maxDownload)
                self.connectionMaxUploadInput = String(payload.maxUpload)
                self.savedConnectionMaxDownload = payload.maxDownload
                self.savedConnectionMaxUpload = payload.maxUpload
                self.lastConnectionPrefsRawOutput = raw
                if logOutput {
                    self.appendLog("$ prefs-connection-get\n\(raw)")
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
}
