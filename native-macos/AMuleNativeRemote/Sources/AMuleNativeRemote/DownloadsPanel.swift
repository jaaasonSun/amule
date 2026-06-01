import SwiftUI
import SharedViews
import SharedModels
import SharedServices

struct DownloadsPanel: View {
    let displayedDownloads: [DownloadItem]
    @Binding var selectedDownloadIDs: Set<DownloadItem.ID>
    @Binding var sortOrder: [KeyPathComparator<DownloadItem>]
    @Binding var nameFilterQuery: String
    let alwaysShowSuggestedFilename: Bool
    let canRenameDownload: (DownloadItem) -> Bool
    let showDetails: (DownloadItem) -> Void
    let useSuggestedFilename: (DownloadItem, String) -> Void
    let copyED2KLink: (DownloadItem) -> Void
    let pauseDownload: (DownloadItem) -> Void
    let resumeDownload: (DownloadItem) -> Void
    let removeDownload: (DownloadItem) -> Void
    let setPriority: (DownloadItem, String) -> Void
    let isBusy: Bool

    var body: some View {
        Table(displayedDownloads, selection: $selectedDownloadIDs, sortOrder: $sortOrder) {
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
                        if item.hasDisplayedNameEncodingValue(alwaysShowDiagnostic: alwaysShowSuggestedFilename) {
                            Label(
                                item.usesDiagnosticNameEncodingFallback(alwaysShowDiagnostic: alwaysShowSuggestedFilename)
                                    ? "Diagnostic filename value available"
                                    : (item.nameEncodingSuspect ? "Suggested filename available" : "Diagnostic filename suggestion available"),
                                systemImage: "wand.and.stars"
                            )
                                .labelStyle(.iconOnly)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(
                                    item.usesDiagnosticNameEncodingFallback(alwaysShowDiagnostic: alwaysShowSuggestedFilename) || !item.nameEncodingSuspect
                                        ? Color.secondary
                                        : Color.orange
                                )
                                .help(
                                    item.usesDiagnosticNameEncodingFallback(alwaysShowDiagnostic: alwaysShowSuggestedFilename)
                                        ? "Diagnostic filename value available"
                                        : (item.nameEncodingSuspect ? "Suggested filename available" : "Diagnostic filename suggestion available")
                                )
                        }
                    }
                }
                .contextMenu { downloadContextMenu(item) }
            }
            .width(min: 320, ideal: 560)

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
            .width(128)

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
            .width(64)

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
            .width(48)
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
        if let suggestion = item.meaningfulNameEncodingSuggestion {
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
                        colors: item.progressColors,
                        fallbackProgress: item.progressDisplayValue / 100.0
                    )
                    .opacity(0.20)
                }
            }
    }
}
