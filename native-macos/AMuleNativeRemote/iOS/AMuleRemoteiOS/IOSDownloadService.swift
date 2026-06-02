#if canImport(UIKit)
import SwiftUI
import AMuleECClient
import SharedModels
import SharedServices
import SharedViews

@MainActor
struct IOSDownloadService {
    func refreshDownloads(model: IOSAppModel) {
        let config = model.config
        let bridge = model.bridgeClient
        Task {
            do {
                let (payloads, _) = try await bridge.downloads(config: config)
                await MainActor.run {
                    model.downloads = DownloadItem.fromBridge(payloads)
                }
            } catch {
                await MainActor.run {
                    model.lastError = model.localNetworkErrorPresenter.userFacingMessage(for: error)
                }
            }
        }
    }

    func pauseDownload(_ item: DownloadItem, model: IOSAppModel) {
        let config = model.config
        let bridge = model.bridgeClient
        Task {
            do {
                let _ = try await bridge.pause(hash: item.id, config: config)
                await MainActor.run {
                    model.refreshDownloads()
                }
            } catch {
                await MainActor.run {
                    model.lastError = model.localNetworkErrorPresenter.userFacingMessage(for: error)
                }
            }
        }
    }

    func resumeDownload(_ item: DownloadItem, model: IOSAppModel) {
        let config = model.config
        let bridge = model.bridgeClient
        Task {
            do {
                let _ = try await bridge.resume(hash: item.id, config: config)
                await MainActor.run {
                    model.refreshDownloads()
                }
            } catch {
                await MainActor.run {
                    model.lastError = model.localNetworkErrorPresenter.userFacingMessage(for: error)
                }
            }
        }
    }

    func renameDownload(_ item: DownloadItem, to newName: String, model: IOSAppModel) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !item.id.isEmpty else {
            model.lastError = L("Cannot rename download: missing file hash.")
            return
        }
        guard !trimmed.isEmpty else {
            model.lastError = L("New file name is required.")
            return
        }
        guard trimmed != item.name else { return }

        model.isBusy = true
        model.lastError = ""
        let config = model.config
        let bridge = model.bridgeClient
        Task {
            do {
                let acknowledgement = try await bridge.rename(hash: item.id, name: trimmed, config: config)
                guard acknowledgement.requiresPostRefreshVerification else {
                    await MainActor.run {
                        model.lastError = acknowledgement.verificationFailureMessage
                        model.isBusy = false
                    }
                    return
                }

                let (payloads, _) = try await bridge.downloads(config: config)
                let refreshedDownloads = DownloadItem.fromBridge(payloads)
                let didApply = RenameVerification.wasApplied(
                    downloadID: item.id,
                    newName: trimmed,
                    downloads: refreshedDownloads
                )
                await MainActor.run {
                    model.downloads = refreshedDownloads
                    model.lastError = didApply ? "" : acknowledgement.verificationFailureMessage
                    model.isBusy = false
                }
            } catch {
                do {
                    let (payloads, _) = try await bridge.downloads(config: config)
                    let refreshedDownloads = DownloadItem.fromBridge(payloads)
                    let didApply = RenameVerification.wasApplied(
                        downloadID: item.id,
                        newName: trimmed,
                        downloads: refreshedDownloads
                    )
                    await MainActor.run {
                        model.downloads = refreshedDownloads
                        model.lastError = didApply
                            ? ""
                            : "\(model.localNetworkErrorPresenter.userFacingMessage(for: error)) \(L("The filename was not changed."))"
                        model.isBusy = false
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

    func removeDownload(_ item: DownloadItem, model: IOSAppModel) {
        guard !item.id.isEmpty else {
            model.lastError = L("Cannot remove download: missing file hash.")
            return
        }

        model.isBusy = true
        model.lastError = ""
        let config = model.config
        let bridge = model.bridgeClient
        Task {
            do {
                let _ = try await bridge.cancel(hash: item.id, config: config)
                let (payloads, _) = try await bridge.downloads(config: config)
                await MainActor.run {
                    model.downloads = DownloadItem.fromBridge(payloads)
                    model.isBusy = false
                }
            } catch {
                await MainActor.run {
                    model.lastError = model.localNetworkErrorPresenter.userFacingMessage(for: error)
                    model.isBusy = false
                }
            }
        }
    }

    func clearCompleted(_ items: [DownloadItem], model: IOSAppModel) {
        guard model.isSessionConnected else { return }
        guard BridgeCapabilityGate.isSupported("clear-completed", by: model.bridgeOps) else { return }

        let ecids = items.map(\.ecid)
        guard !ecids.isEmpty else { return }

        model.isBusy = true
        model.lastError = ""
        let config = model.config
        let bridge = model.bridgeClient
        Task {
            do {
                let _ = try await bridge.clearCompleted(ecids: ecids, config: config)
                let (payloads, _) = try await bridge.downloads(config: config)
                await MainActor.run {
                    model.downloads = DownloadItem.fromBridge(payloads)
                    model.isBusy = false
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
