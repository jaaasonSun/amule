import SwiftUI
import SharedModels
import SharedServices

struct MainToolbar: ToolbarContent {
    let selectedDownload: DownloadItem?
    let selectedDownloads: [DownloadItem]
    let selectedDownloadIDs: Set<DownloadItem.ID>
    let completedDownloads: [DownloadItem]
    let isBusy: Bool
    let showDetails: () -> Void
    let resumeDownloads: ([DownloadItem]) -> Void
    let pauseDownloads: ([DownloadItem]) -> Void
    let requestRemoveDownloads: (Set<DownloadItem.ID>) -> Void
    let showAddLinks: () -> Void
    let clearCompleted: ([DownloadItem]) -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button {
                showDetails()
            } label: {
                Label("Details", systemImage: "info")
            }
            .help("Show Download Details")
            .disabled(selectedDownload == nil)
        }

        ToolbarItem(placement: .automatic) {
            ControlGroup {
                Button {
                    resumeDownloads(selectedDownloads)
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .help("Resume Selected Downloads")
                .disabled(selectedDownloads.isEmpty || isBusy)

                Button {
                    pauseDownloads(selectedDownloads)
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
                .help("Pause Selected Downloads")
                .disabled(selectedDownloads.isEmpty || isBusy)

                Button {
                    requestRemoveDownloads(selectedDownloadIDs)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .help("Remove Selected Downloads")
                .disabled(selectedDownloads.isEmpty || isBusy)
            }
            .controlGroupStyle(.navigation)
        }

        ToolbarItem(placement: .automatic) {
            Button {
                showAddLinks()
            } label: {
                Label("Add Links", systemImage: "plus")
            }
            .help("Show Add Links Panel")
            .disabled(isBusy)
        }

        ToolbarItem(placement: .automatic) {
            Button {
                clearCompleted(completedDownloads)
            } label: {
                Label("Clear Completed", systemImage: "checkmark")
            }
            .help("Clear Completed Downloads")
            .disabled(completedDownloads.isEmpty || isBusy)
        }
    }
}
