#if canImport(UIKit)
import SwiftUI
import AMuleECBridgeAdapter
import AMuleECClient
import SharedModels
import SharedServices
import SharedViews

@MainActor
struct IOSDownloadService {
    func refreshDownloads(model: IOSAppModel) {
        let session = model.currentSessionCoordinator()
        Task {
            do {
                guard let (payloads, _) = try await session.coordinator.manualRefreshDownloads() else { return }
                await MainActor.run {
                    guard model.isCurrentSession(session) else { return }
                    model.downloads = DownloadItem.fromBridge(payloads)
                }
            } catch {
                await MainActor.run {
                    guard model.isCurrentSession(session) else { return }
                    model.lastError = model.localNetworkErrorPresenter.userFacingMessage(for: error)
                }
            }
        }
    }

    func pauseDownload(_ item: DownloadItem, model: IOSAppModel) {
        let config = model.config
        let bridge = model.bridgeClient
        let session = model.currentSessionCoordinator()
        Task {
            do {
                let _ = try await bridge.pause(hash: item.id, config: config)
                try await mutationRefreshDownloads(model: model, session: session)
            } catch {
                await MainActor.run {
                    guard model.isCurrentSession(session) else { return }
                    model.lastError = model.localNetworkErrorPresenter.userFacingMessage(for: error)
                }
            }
        }
    }

    func resumeDownload(_ item: DownloadItem, model: IOSAppModel) {
        let config = model.config
        let bridge = model.bridgeClient
        let session = model.currentSessionCoordinator()
        Task {
            do {
                let _ = try await bridge.resume(hash: item.id, config: config)
                try await mutationRefreshDownloads(model: model, session: session)
            } catch {
                await MainActor.run {
                    guard model.isCurrentSession(session) else { return }
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

        let session = model.currentSessionCoordinator()
        model.isBusy = true
        model.lastError = ""
        let config = model.config
        let bridge = model.bridgeClient
        Task {
            do {
                let acknowledgement = try await bridge.rename(hash: item.id, name: trimmed, config: config)
                let isCurrent = await MainActor.run { () -> Bool in
                    model.isCurrentSession(session)
                }
                guard isCurrent else { return }
                guard acknowledgement.requiresPostRefreshVerification else {
                    await MainActor.run {
                        guard model.isCurrentSession(session) else { return }
                        model.lastError = acknowledgement.verificationFailureMessage
                        model.isBusy = false
                    }
                    return
                }

                let didApply = try await verifyRename(
                    downloadID: item.id,
                    newName: trimmed,
                    bridge: bridge,
                    config: config,
                    model: model,
                    session: session
                )
                await MainActor.run {
                    guard model.isCurrentSession(session) else { return }
                    model.lastError = didApply ? "" : acknowledgement.verificationFailureMessage
                    model.isBusy = false
                }
            } catch {
                let isCurrent = await MainActor.run { () -> Bool in
                    model.isCurrentSession(session)
                }
                guard isCurrent else { return }
                do {
                    let didApply = try await verifyRename(
                        downloadID: item.id,
                        newName: trimmed,
                        bridge: bridge,
                        config: config,
                        model: model,
                        session: session
                    )
                    await MainActor.run {
                        guard model.isCurrentSession(session) else { return }
                        model.lastError = didApply
                            ? ""
                            : "\(model.localNetworkErrorPresenter.userFacingMessage(for: error)) \(L("The filename was not changed."))"
                        model.isBusy = false
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

    private func verifyRename(
        downloadID: String,
        newName: String,
        bridge: BridgeProtocol,
        config: AMuleConnectionConfig,
        model: IOSAppModel,
        session: IOSRemoteSessionLease
    ) async throws -> Bool {
        let attempts = await MainActor.run { max(1, model.renameVerificationMaxAttempts) }
        for attempt in 0..<attempts {
            let isCurrent = await MainActor.run { () -> Bool in
                model.isCurrentSession(session)
            }
            guard isCurrent else { return false }
            let (payloads, _) = try await bridge.downloads(config: config)
            let refreshedDownloads = DownloadItem.fromBridge(payloads)
            let didApply = RenameVerification.wasApplied(
                downloadID: downloadID,
                newName: newName,
                downloads: refreshedDownloads
            )
            let didPublish = await MainActor.run(resultType: Bool.self, body: {
                guard model.isCurrentSession(session) else { return false }
                model.downloads = refreshedDownloads
                return true
            })
            guard didPublish else { return false }
            if didApply {
                return true
            }

            guard attempt + 1 < attempts else { break }
            let delay = await MainActor.run { model.renameVerificationRetryDelayNanoseconds }
            if delay > 0 {
                try await Task.sleep(nanoseconds: delay)
            }
        }
        return false
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
        let session = model.currentSessionCoordinator()
        Task {
            do {
                let _ = try await bridge.cancel(hash: item.id, config: config)
                try await mutationRefreshDownloads(model: model, session: session)
                await MainActor.run {
                    guard model.isCurrentSession(session) else { return }
                    model.isBusy = false
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

    func clearCompleted(_ items: [DownloadItem], model: IOSAppModel) {
        guard model.isSessionConnected else { return }
        guard BridgeCapabilityGate.isSupported("clear-completed", by: model.bridgeOps) else { return }

        let ecids = items.map(\.ecid)
        guard !ecids.isEmpty else { return }

        model.isBusy = true
        model.lastError = ""
        let config = model.config
        let bridge = model.bridgeClient
        let session = model.currentSessionCoordinator()
        Task {
            do {
                let _ = try await bridge.clearCompleted(ecids: ecids, config: config)
                try await mutationRefreshDownloads(model: model, session: session)
                await MainActor.run {
                    guard model.isCurrentSession(session) else { return }
                    model.isBusy = false
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

    private func mutationRefreshDownloads(
        model: IOSAppModel,
        session: IOSRemoteSessionLease
    ) async throws {
        guard model.isCurrentSession(session) else { return }
        guard let (payloads, _) = try await session.coordinator.mutationRefreshDownloads(),
              model.isCurrentSession(session) else {
            return
        }
        model.downloads = DownloadItem.fromBridge(payloads)
    }

}
#endif
