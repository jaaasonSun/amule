import SwiftUI
import SharedViews
import SharedModels
import SharedServices

enum DownloadTableColumnPersistence {
    static let columnCustomizationDefaultsKey = "AMuleNativeRemote.DownloadsTable.columnCustomization"
}

struct DownloadTableColumnLayout {
    let minWidth: CGFloat
    let idealWidth: CGFloat

    var isResizable: Bool {
        true
    }

    static let name = DownloadTableColumnLayout(minWidth: 320, idealWidth: 560)
    static let progress = DownloadTableColumnLayout(minWidth: 128, idealWidth: 128)
    static let speed = DownloadTableColumnLayout(minWidth: 52, idealWidth: 64)
    static let sources = DownloadTableColumnLayout(minWidth: 48, idealWidth: 72)
}

struct DownloadCategoryMenuItem: Identifiable {
    let id: Int
    let title: String
}

struct DownloadsPanel: View {
    let displayedDownloads: [DownloadItem]
    @Binding var selectedDownloadIDs: Set<DownloadItem.ID>
    @Binding var sortOrder: [KeyPathComparator<DownloadItem>]
    @Binding var nameFilterQuery: String
    let alwaysShowSuggestedFilename: Bool
    let filenameCleanupPrefixes: [String]
    let canRenameDownload: (DownloadItem) -> Bool
    let showDetails: (DownloadItem) -> Void
    let useSuggestedFilename: (DownloadItem, String) -> Void
    let copyED2KLink: (DownloadItem) -> Void
    let pauseDownload: (DownloadItem) -> Void
    let resumeDownload: (DownloadItem) -> Void
    let stopDownload: (DownloadItem) -> Void
    let removeDownload: (DownloadItem) -> Void
    let setPriority: (DownloadItem, String) -> Void
    let setCategory: (DownloadItem, Int) -> Void
    let categories: [DownloadCategoryMenuItem]
    let isDownloadStopSupported: Bool
    let isDownloadSetCategorySupported: Bool
    let isBusy: Bool

    @AppStorage(DownloadTableColumnPersistence.columnCustomizationDefaultsKey)
    private var columnCustomization = TableColumnCustomization<DownloadItem>()

    var body: some View {
        Table(
            displayedDownloads,
            selection: $selectedDownloadIDs,
            sortOrder: $sortOrder,
            columnCustomization: $columnCustomization
        ) {
            TableColumn("Name", sortUsing: KeyPathComparator(\DownloadItem.name, order: .forward)) { item in
                downloadTableCell(
                    item,
                    showsProgressBackground: false
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: downloadStatusSymbol(for: item.status))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                        Text(item.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if hasDisplayedFilenameSuggestion(for: item) {
                            Label(
                                isDiagnosticFilenameValue(for: item)
                                    ? "Diagnostic filename value available"
                                    : "Suggested filename available",
                                systemImage: "wand.and.stars"
                            )
                                .labelStyle(.iconOnly)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(
                                    isDiagnosticFilenameValue(for: item)
                                        ? Color.secondary
                                        : Color.orange
                                )
                                .help(
                                    isDiagnosticFilenameValue(for: item)
                                        ? "Diagnostic filename value available"
                                        : "Suggested filename available"
                                )
                        }
                    }
                }
                .contextMenu { downloadContextMenu(item) }
            }
            .width(
                min: DownloadTableColumnLayout.name.minWidth,
                ideal: DownloadTableColumnLayout.name.idealWidth
            )
            .customizationID("name")

            TableColumn("Progress", sortUsing: KeyPathComparator(\DownloadItem.progressSortValue, order: .reverse)) { item in
                downloadTableCell(
                    item,
                    alignment: .trailing,
                    showsProgressBackground: true
                ) {
                    Text(item.completionText)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .contextMenu { downloadContextMenu(item) }
            }
            .width(
                min: DownloadTableColumnLayout.progress.minWidth,
                ideal: DownloadTableColumnLayout.progress.idealWidth
            )
            .customizationID("progress")

            TableColumn("Speed", sortUsing: KeyPathComparator(\DownloadItem.speedSortValue, order: .reverse)) { item in
                downloadTableCell(
                    item,
                    alignment: .trailing,
                    showsProgressBackground: false
                ) {
                    Text(item.speedBytes > 0 ? item.speedText : "")
                        .lineLimit(1)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .contextMenu { downloadContextMenu(item) }
            }
            .width(
                min: DownloadTableColumnLayout.speed.minWidth,
                ideal: DownloadTableColumnLayout.speed.idealWidth
            )
            .customizationID("speed")

            TableColumn("Src", sortUsing: KeyPathComparator(\DownloadItem.sourceTotal, order: .reverse)) { item in
                downloadTableCell(
                    item,
                    alignment: .trailing,
                    showsProgressBackground: false
                ) {
                    Text(item.sourcesText)
                        .lineLimit(1)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .contextMenu { downloadContextMenu(item) }
            }
            .width(
                min: DownloadTableColumnLayout.sources.minWidth,
                ideal: DownloadTableColumnLayout.sources.idealWidth
            )
            .customizationID("sources")
        }
        .padding(.horizontal, 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollContentBackground(.hidden)
        .searchable(text: $nameFilterQuery, placement: .toolbar, prompt: L("Filter Downloads"))
    }

    @ViewBuilder
    private func downloadContextMenu(_ item: DownloadItem) -> some View {
        Button("Details…") {
            showDetails(item)
        }
        if let suggestion = item.meaningfulFilenameSuggestion(prefixes: filenameCleanupPrefixes) {
            Button("Use Suggested Filename…") {
                useSuggestedFilename(item, suggestion)
            }
            .disabled(!canRenameDownload(item) || isBusy)
        }
        Button("Copy eD2k Link") {
            copyED2KLink(item)
        }
        Divider()
        Button("Pause") {
            pauseDownload(item)
        }
        Button("Resume") {
            resumeDownload(item)
        }
        Button("Stop") {
            stopDownload(item)
        }
        .disabled(isBusy || !isDownloadStopSupported || item.isCompletedLike)
        Divider()
        Button("Remove") {
            removeDownload(item)
        }
        Divider()
        Menu("Priority") {
            Button("Low") { setPriority(item, "low") }
            Button("Normal") { setPriority(item, "normal") }
            Button("High") { setPriority(item, "high") }
            Button("Auto") { setPriority(item, "auto") }
        }
        Menu("Assign to Category") {
            Button("Unassign") { setCategory(item, 0) }
            ForEach(categories) { category in
                Button(category.title.isEmpty ? "Category \(category.id)" : category.title) {
                    setCategory(item, category.id)
                }
            }
        }
        .disabled(isBusy || !isDownloadSetCategorySupported)
    }

    private func hasDisplayedFilenameSuggestion(for item: DownloadItem) -> Bool {
        item.meaningfulFilenameSuggestion(prefixes: filenameCleanupPrefixes) != nil ||
            item.hasDisplayedNameEncodingValue(alwaysShowDiagnostic: alwaysShowSuggestedFilename)
    }

    private func isDiagnosticFilenameValue(for item: DownloadItem) -> Bool {
        item.meaningfulFilenameSuggestion(prefixes: filenameCleanupPrefixes) == nil &&
            item.usesDiagnosticNameEncodingFallback(alwaysShowDiagnostic: alwaysShowSuggestedFilename)
    }

    private func downloadStatusSymbol(for status: String) -> String {
        let raw = status.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercase = raw.lowercased()

        func hasAny(_ haystack: String, _ tokens: [String]) -> Bool {
            tokens.contains { haystack.contains($0) }
        }

        if hasAny(lowercase, ["error", "erroneous", "failed", "corrupt"]) || hasAny(raw, ["错误", "故障", "失败"]) {
            return "xmark"
        }
        if hasAny(lowercase, ["complete", "completed"]) || hasAny(raw, ["完成", "已完成"]) {
            return "checkmark"
        }
        if hasAny(lowercase, ["paused"]) || hasAny(raw, ["暂停"]) {
            return "pause"
        }
        if hasAny(lowercase, ["hashing", "allocat", "completing"]) || hasAny(raw, ["哈希", "分配", "完成中"]) {
            return "progress.indicator"
        }
        if hasAny(lowercase, ["downloading"]) || hasAny(raw, ["下载"]) {
            return "arrow.down"
        }
        if hasAny(lowercase, ["waiting", "ready", "empty"]) || hasAny(raw, ["等待"]) {
            return "clock"
        }
        return "questionmark"
    }

    private func downloadTableCell<Content: View>(
        _ item: DownloadItem,
        alignment: Alignment = .leading,
        showsProgressBackground: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: alignment)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background {
                if showsProgressBackground {
                    DownloadRowSegmentBackground(
                        colors: item.progressColors
                    )
                    .opacity(DownloadProgressVisualStyle.rowBackgroundOpacity)
                }
            }
    }
}

#if DEBUG
private extension DownloadsPanel {
    static func preview(
        downloads: [DownloadItem],
        selectedIDs: Set<DownloadItem.ID> = []
    ) -> DownloadsPanel {
        DownloadsPanel(
            displayedDownloads: downloads,
            selectedDownloadIDs: .constant(selectedIDs),
            sortOrder: .constant([KeyPathComparator(\DownloadItem.name, order: .forward)]),
            nameFilterQuery: .constant(""),
            alwaysShowSuggestedFilename: false,
            filenameCleanupPrefixes: [],
            canRenameDownload: { _ in true },
            showDetails: { _ in },
            useSuggestedFilename: { _, _ in },
            copyED2KLink: { _ in },
            pauseDownload: { _ in },
            resumeDownload: { _ in },
            stopDownload: { _ in },
            removeDownload: { _ in },
            setPriority: { _, _ in },
            setCategory: { _, _ in },
            categories: [
                DownloadCategoryMenuItem(id: 1, title: "Movies"),
                DownloadCategoryMenuItem(id: 2, title: "Music")
            ],
            isDownloadStopSupported: true,
            isDownloadSetCategorySupported: true,
            isBusy: false
        )
    }
}

#Preview("Empty Downloads") {
    DownloadsPanel.preview(downloads: [])
}

#Preview("Active Downloads") {
    DownloadsPanel.preview(
        downloads: AppModel.previewWithDownloads().downloads
    )
}

#Preview("Completed Downloads") {
    DownloadsPanel.preview(
        downloads: AppModel.previewWithDownloads().downloads.filter(\.isCompleted)
    )
}
#endif
