#if canImport(UIKit)
import SwiftUI
import SharedModels
import SharedServices
import SharedViews

struct SuggestedRenameRequest: Identifiable {
    let id = UUID()
    let item: DownloadItem
    let suggestion: String
}

struct AddLinksSheet: View {
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

struct RenameSuggestionSheet: View {
    @ObservedObject var model: IOSAppModel
    let request: SuggestedRenameRequest
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String

    init(model: IOSAppModel, request: SuggestedRenameRequest) {
        self.model = model
        self.request = request
        _draft = State(initialValue: request.suggestion)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(request.item.name)
                        .lineLimit(nil)
                        .textSelection(.enabled)
                        .font(.body)
                } header: {
                    Label("Current Filename", systemImage: "doc")
                }

                Section {
                    TextField("New file name", text: $draft, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(3...8)
                        .textSelection(.enabled)
                        .font(.body)
                } header: {
                    Label("Suggested Filename", systemImage: "wand.and.stars")
                } footer: {
                    Text("Review or edit the suggestion before applying it. The original filename remains unchanged until Apply is tapped.")
                }

                if model.isBusy {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Applying rename…")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Rename File")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: renameVerificationToken) { _, _ in
                if RenameVerification.wasApplied(downloadID: request.item.id, newName: draft, downloads: model.downloads) {
                    dismiss()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(model.isBusy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        model.renameDownload(request.item, to: draft)
                    }
                    .disabled(
                        model.isBusy ||
                        FilenameSuggestionPresentation.renameDraft(from: draft, currentName: request.item.name) == nil
                    )
                }
            }
        }
    }

    private var renameVerificationToken: String {
        model.downloads
            .map { "\($0.id)|\($0.name)" }
            .joined(separator: "\n")
    }
}

struct DownloadRow: View {
    let item: DownloadItem
    let filenameCleanupPrefixes: [String]

    init(item: DownloadItem, filenameCleanupPrefixes: [String] = []) {
        self.item = item
        self.filenameCleanupPrefixes = filenameCleanupPrefixes
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: DownloadStatusSymbol.categorySymbolName(for: item))
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusTint)
                .frame(width: 16, height: 20)
                .accessibilityLabel(statusAccessibilityLabel)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.trimmedDisplayName ?? item.name)
                        .font(.headline)
                        .lineLimit(2)
                        .truncationMode(.middle)

                    if item.meaningfulFilenameSuggestion(prefixes: filenameCleanupPrefixes) != nil {
                        Image(systemName: "wand.and.stars")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                            .accessibilityLabel("Suggested filename available")
                    }
                }

                if let suggestion = item.meaningfulFilenameSuggestion(prefixes: filenameCleanupPrefixes) {
                    Label(suggestion, systemImage: "wand.and.stars")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .accessibilityLabel("Suggested filename: \(suggestion)")
                }

                ZStack(alignment: .trailing) {
                    DownloadRowSegmentBackground(
                        colors: item.progressColors,
                        fallbackProgress: item.progressDisplayValue / 100.0
                    )
                    .opacity(0.36)

                    Text(item.progressText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                }
                .frame(height: 14)
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))

                HStack(spacing: 10) {
                    if item.speedBytes > 0 {
                        Text(item.speedText)
                    }
                    Text(AMuleFormatter.fileSize(item.sizeBytes))
                    Spacer(minLength: 8)
                    Text(item.sourcesText)
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusAccessibilityLabel: String {
        if item.isCompletedLike {
            return L("Completed")
        }
        if DownloadClassification.isPaused(item) {
            return L("Paused")
        }
        if DownloadClassification.isDownloading(item) {
            return L("Downloading")
        }
        return L("Pending")
    }

    private var statusTint: Color {
        if item.isCompletedLike {
            return .green
        }
        if DownloadClassification.isPaused(item) {
            return .orange
        }
        if DownloadClassification.isDownloading(item) {
            return .accentColor
        }
        return .secondary
    }
}

extension DownloadsView {
    func filterCount(for filter: DownloadListFilter) -> Int {
        DownloadListPresentation.count(model.downloads, matching: filter)
    }

    func canRename(_ item: DownloadItem) -> Bool {
        !item.isCompletedLike && !model.isBusy
    }
}
#endif
