#if canImport(UIKit)
import SwiftUI
import AMuleRemoteIOSShared
import SharedUI

struct DownloadsView: View {
    @ObservedObject var model: IOSAppModel

    private enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case downloading = "Downloading"
        case paused = "Paused"
        case completed = "Completed"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .all: return "tray.full"
            case .downloading: return "arrow.down"
            case .paused: return "pause"
            case .completed: return "checkmark"
            }
        }
    }

    @State private var selectedFilter: Filter = .all
    @State private var addLinksDraft = ""
    @State private var showAddLinksSheet = false

    private var filteredDownloads: [DownloadItem] {
        switch selectedFilter {
        case .all: return model.downloads
        case .downloading: return model.downloads.filter { DownloadClassification.isDownloading($0) }
        case .paused: return model.downloads.filter { DownloadClassification.isPaused($0) }
        case .completed: return model.downloads.filter { DownloadClassification.isCompleted($0) }
        }
    }

    var body: some View {
        List {
            if filteredDownloads.isEmpty {
                ContentUnavailableView(
                    model.isSessionConnected ? "No Downloads" : "Not Connected",
                    systemImage: model.isSessionConnected ? "tray" : "wifi.slash",
                    description: Text(model.isSessionConnected
                        ? "Downloads will appear here when active."
                        : "Connect to an aMule server to see downloads.")
                )
            } else {
                ForEach(filteredDownloads) { item in
                    NavigationLink {
                        DownloadDetailView(model: model, item: item)
                    } label: {
                        DownloadRow(item: item)
                    }
                    .contextMenu {
                        Button {
                            model.copyDownloadLinkToClipboard(item)
                        } label: {
                            Label("Copy Link", systemImage: "doc.on.doc")
                        }

                        Button {
                            model.shareDownloadLink(item)
                        } label: {
                            Label("Share Link", systemImage: "square.and.arrow.up")
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            model.removeDownload(item)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        if DownloadClassification.isPaused(item) || item.statusCode == 7 {
                            Button {
                                model.resumeDownload(item)
                            } label: {
                                Label("Resume", systemImage: "play.fill")
                            }
                        } else if DownloadClassification.isDownloading(item) {
                            Button {
                                model.pauseDownload(item)
                            } label: {
                                Label("Pause", systemImage: "pause.fill")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: .constant(""), prompt: "Filter Downloads")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddLinksSheet = true
                } label: {
                    Label("Add Links", systemImage: "plus")
                }
                .disabled(!model.isSessionConnected || model.isBusy)
            }
        }
        .sheet(isPresented: $showAddLinksSheet) {
            AddLinksSheet(model: model, draft: $addLinksDraft)
        }
        .task {
            if model.isSessionConnected {
                model.refreshDownloads()
            }
        }
    }
}

private struct AddLinksSheet: View {
    @ObservedObject var model: IOSAppModel
    @Binding var draft: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LinkImportPanelContent(
                draft: $draft,
                isBusy: model.isBusy,
                onImport: {
                    model.addLinks(draft)
                    draft = ""
                    dismiss()
                },
                onClear: { draft = "" }
            )
            .padding(16)
            .navigationTitle("Add eD2k Links")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

extension IOSAppModel {
    func removeDownload(_ item: DownloadItem) {
        downloads.removeAll { $0.id == item.id }
    }
}

#Preview {
    NavigationStack {
        DownloadsView(model: IOSAppModel())
    }
}
#endif
