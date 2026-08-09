import SwiftUI
import SharedModels
import SharedServices

struct MainToolbar: ToolbarContent {
    @Binding var selectedDownloadStatusFilter: ContentView.DownloadStatusFilter
    let downloadStatusFilterCounts: [ContentView.DownloadStatusFilter: Int]
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
    let showSearchNetwork: () -> Void
    let clearCompleted: ([DownloadItem]) -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Menu {
                ForEach(ContentView.DownloadStatusFilter.allCases) { filter in
                    Button {
                        selectedDownloadStatusFilter = filter
                    } label: {
                        HStack {
                            Label(downloadStatusFilterLabel(for: filter), systemImage: filter.symbolName)
                                .labelStyle(.titleAndIcon)
                            if filter == selectedDownloadStatusFilter {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label(downloadStatusFilterLabel(for: selectedDownloadStatusFilter), systemImage: selectedDownloadStatusFilter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    .labelStyle(.iconOnly)
            }
            .help(L("Download Status Filter"))
            .accessibilityLabel(L("Download Status Filter"))
            .accessibilityValue(downloadStatusFilterLabel(for: selectedDownloadStatusFilter))
        }

        ToolbarItem(placement: .automatic) {
            Button {
                showDetails()
            } label: {
                Label("Details", systemImage: "info")
            }
            .help("Show Download Details")
            .accessibilityLabel(L("Show Download Details"))
            .accessibilityHint(L("Show Download Details"))
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
                .accessibilityLabel(L("Resume Selected Downloads"))
                .accessibilityHint(L("Resume Selected Downloads"))
                .disabled(selectedDownloads.isEmpty || isBusy)

                Button {
                    pauseDownloads(selectedDownloads)
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
                .help("Pause Selected Downloads")
                .accessibilityLabel(L("Pause Selected Downloads"))
                .accessibilityHint(L("Pause Selected Downloads"))
                .disabled(selectedDownloads.isEmpty || isBusy)

                Button {
                    requestRemoveDownloads(selectedDownloadIDs)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .help("Remove Selected Downloads")
                .accessibilityLabel(L("Remove Selected Downloads"))
                .accessibilityHint(L("Remove Selected Downloads"))
                .disabled(selectedDownloads.isEmpty || isBusy)

                Button {
                    clearCompleted(completedDownloads)
                } label: {
                    Label("Clear Completed", systemImage: "checkmark")
                }
                .help("Clear Completed Downloads")
                .accessibilityLabel(L("Clear Completed"))
                .accessibilityHint(L("Clear Completed Downloads"))
                .disabled(completedDownloads.isEmpty || isBusy)
            }
            .controlGroupStyle(.navigation)
        }

        ToolbarItem(placement: .automatic) {
            Button {
                showSearchNetwork()
            } label: {
                Label(L("Search Network"), systemImage: "network")
            }
            .help(L("Search Network"))
            .accessibilityLabel(L("Search Network"))
        }

        ToolbarItem(placement: .automatic) {
            Button {
                showAddLinks()
            } label: {
                Label("Add Links", systemImage: "plus")
            }
            .help("Show Add Links Panel")
            .accessibilityLabel(L("Add Links"))
            .accessibilityHint(L("Show Add Links Panel"))
            .disabled(isBusy)
        }
    }

    private func downloadStatusFilterLabel(for filter: ContentView.DownloadStatusFilter) -> String {
        "\(filter.localizedTitle) (\(downloadStatusFilterCounts[filter, default: 0]))"
    }
}
