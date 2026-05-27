import SwiftUI
import SharedUI

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

private struct DownloadRowSegmentBackground: View {
    let colors: [UInt32]
    let fallbackProgress: Double

    private static let fallbackDoneColor = packedColor(r: 104, g: 104, b: 104)
    private static let fallbackMissingColor = packedColor(r: 255, g: 0, b: 0)

    private var renderedColors: [UInt32] {
        if !colors.isEmpty {
            return colors
        }

        let segmentCount = 64
        let safeProgress = max(0, min(fallbackProgress, 1))
        let doneSegments = Int((safeProgress * Double(segmentCount)).rounded(.down))
        return (0..<segmentCount).map {
            $0 < doneSegments ? Self.fallbackDoneColor : Self.fallbackMissingColor
        }
    }

    var body: some View {
        Canvas { context, size in
            let segments = renderedColors
            let count = max(segments.count, 1)
            let height = max(1, size.height)

            for index in 0..<count {
                let left = floor(CGFloat(index) * size.width / CGFloat(count))
                let right = floor(CGFloat(index + 1) * size.width / CGFloat(count))
                let width = max(1, right - left)
                let rect = CGRect(x: left, y: 0, width: width, height: height)
                context.fill(
                    Path(rect),
                    with: .color(color(from: segments[min(index, segments.count - 1)]))
                )
            }
        }
    }

    private func color(from packed: UInt32) -> Color {
        let red = Double(packed & 0xff) / 255.0
        let green = Double((packed >> 8) & 0xff) / 255.0
        let blue = Double((packed >> 16) & 0xff) / 255.0
        let luma = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
        let saturationScale = 0.42
        let softenedRed = luma + (red - luma) * saturationScale
        let softenedGreen = luma + (green - luma) * saturationScale
        let softenedBlue = luma + (blue - luma) * saturationScale
        return Color(red: softenedRed, green: softenedGreen, blue: softenedBlue)
    }

    private static func packedColor(r: Int, g: Int, b: Int) -> UInt32 {
        (UInt32(b & 0xff) << 16) | (UInt32(g & 0xff) << 8) | UInt32(r & 0xff)
    }
}

struct DownloadSegmentedProgressBar: View {
    let colors: [UInt32]
    let fallbackProgress: Double

    private let outerCornerRadius: CGFloat = 6
    private let innerCornerRadius: CGFloat = 4.5

    private static let fallbackDoneColor = packedColor(r: 104, g: 104, b: 104)
    private static let fallbackMissingColor = packedColor(r: 255, g: 0, b: 0)

    private var renderedColors: [UInt32] {
        if !colors.isEmpty {
            return colors
        }
        let segmentCount = 48
        let safeProgress = max(0, min(fallbackProgress, 1))
        let doneSegments = Int((safeProgress * Double(segmentCount)).rounded(.down))
        return (0..<segmentCount).map {
            $0 < doneSegments ? Self.fallbackDoneColor : Self.fallbackMissingColor
        }
    }

    var body: some View {
        Canvas { context, size in
            let segments = renderedColors
            let count = max(segments.count, 1)
            let height = max(1, size.height)

            for index in 0..<count {
                let left = floor(CGFloat(index) * size.width / CGFloat(count))
                let right = floor(CGFloat(index + 1) * size.width / CGFloat(count))
                let width = max(1, right - left)
                let rect = CGRect(x: left, y: 0, width: width, height: height)
                context.fill(
                    Path(rect),
                    with: .color(color(from: segments[min(index, segments.count - 1)]))
                )
            }
        }
        .frame(height: 10)
        .clipShape(RoundedRectangle(cornerRadius: innerCornerRadius, style: .continuous))
        .padding(2)
        .background {
            RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.18))
        }
        .overlay {
            RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.75)
        }
    }

    private func color(from packed: UInt32) -> Color {
        let red = Double(packed & 0xff) / 255.0
        let green = Double((packed >> 8) & 0xff) / 255.0
        let blue = Double((packed >> 16) & 0xff) / 255.0
        let luma = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
        let saturationScale = 0.55
        let softenedRed = luma + (red - luma) * saturationScale
        let softenedGreen = luma + (green - luma) * saturationScale
        let softenedBlue = luma + (blue - luma) * saturationScale
        return Color(
            red: softenedRed,
            green: softenedGreen,
            blue: softenedBlue,
            opacity: 0.82
        )
    }

    private static func packedColor(r: Int, g: Int, b: Int) -> UInt32 {
        (UInt32(b & 0xff) << 16) | (UInt32(g & 0xff) << 8) | UInt32(r & 0xff)
    }
}
