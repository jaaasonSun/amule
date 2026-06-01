#if canImport(UIKit)
import SwiftUI
import AMuleRemoteIOSShared
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
                let _ = try await bridge.rename(hash: item.id, name: trimmed, config: config)
                try? await Task.sleep(nanoseconds: 300_000_000)
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
                        : L("Rename request was sent, but the filename was not changed.")
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
}
#endif
