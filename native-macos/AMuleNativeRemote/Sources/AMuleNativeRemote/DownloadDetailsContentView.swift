import SwiftUI
import AppKit
import SharedViews
import SharedModels
import SharedServices

struct DownloadDetailsContentView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("amule.ui.alwaysShowSuggestedFilename") private var alwaysShowSuggestedFilename = false
    @AppStorage(FilenameCleanupPreferences.storageKey) private var filenameCleanupPrefixesRaw = "[]"

    @State private var sourceSortOrder = [KeyPathComparator(\DownloadSourceItem.clientName, order: .forward)]
    @State private var downloadRenameDraft: String = ""
    @State private var isEditingDownloadName = false

    private var selectedDownload: DownloadItem? {
        guard let selectedDownloadID = model.selectedDownloadID else { return nil }
        return model.downloads.first(where: { $0.id == selectedDownloadID })
    }

    private var selectedDownloadSources: [DownloadSourceItem] {
        model.sources(for: selectedDownload).sorted(using: sourceSortOrder)
    }

    private var selectedDownloadSourceError: String? {
        model.sourceError(for: selectedDownload)
    }

    private var canRenameSelectedDownload: Bool {
        guard let item = selectedDownload else { return false }
        return !item.isCompletedLike
    }

    private var filenameCleanupPrefixes: [String] {
        FilenameCleanupPreferences.decode(filenameCleanupPrefixesRaw)
    }

    private func actionableFilenameSuggestion(for item: DownloadItem) -> String? {
        item.meaningfulFilenameSuggestion(prefixes: filenameCleanupPrefixes)
    }

    private func displayedFilenameValue(for item: DownloadItem) -> String? {
        actionableFilenameSuggestion(for: item) ??
            item.displayedNameEncodingValue(alwaysShowDiagnostic: alwaysShowSuggestedFilename)
    }

    private func useSuggestionForRename(_ item: DownloadItem, suggestion: String) {
        guard let draft = FilenameSuggestionPresentation.renameDraft(from: suggestion, currentName: item.name) else { return }
        downloadRenameDraft = draft
        isEditingDownloadName = true
    }

    private func suggestionHeaderTitle(for item: DownloadItem) -> String {
        if actionableFilenameSuggestion(for: item) != nil {
            return L("Suggested Filename")
        }
        if item.usesDiagnosticNameEncodingFallback(alwaysShowDiagnostic: alwaysShowSuggestedFilename) {
            return L("Current Filename (Diagnostic)")
        }
        return item.nameEncodingSuspect ? L("Suggested Filename") : L("Diagnostic Suggestion")
    }

    private func suggestionHeaderColor(for item: DownloadItem) -> Color {
        if actionableFilenameSuggestion(for: item) != nil {
            return Color.orange
        }
        return item.usesDiagnosticNameEncodingFallback(alwaysShowDiagnostic: alwaysShowSuggestedFilename)
            ? Color.secondary
            : (item.nameEncodingSuspect ? Color.orange : Color.secondary)
    }

    var body: some View {
        detailsContent
            .padding(14)
            .frame(width: 820, alignment: .topLeading)
            .frame(minHeight: 180, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            syncSelectionState(refreshSources: true)
        }
        .onChange(of: model.selectedDownloadID) { _, _ in
            syncSelectionState(refreshSources: true)
        }
        .onChange(of: model.downloads) { _, _ in
            syncSelectionState(refreshSources: false)
        }
        .onChange(of: model.renameSuggestionRequestID) { _, _ in
            applyPendingRenameSuggestionIfNeeded()
        }
    }

    @ViewBuilder
    private var detailsContent: some View {
        VStack(spacing: 12) {
            if let item = selectedDownload {
                selectedDownloadContent(item)
            } else {
                noSelectionContent
            }
        }
    }

    private func selectedDownloadContent(_ item: DownloadItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            titleAndRenameSection(for: item)

            Text(item.id)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                DownloadSegmentedProgressBar(
                    colors: item.progressColors
                )
                Text(LF("Progress: %@", item.progressText))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 10) {
                Text(item.ed2kLink)
                    .font(.callout.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Button(L("Copy")) {
                    model.copyDownloadLinkToClipboard(item)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 8) {
                detailRowsSection(for: item)

                if !item.alternativeNames.isEmpty {
                    Divider()
                    alternativeNamesSection(for: item)
                }

                Divider()
                sourcesSection(for: item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var noSelectionContent: some View {
        Text(L("Select a download item in the Downloads window first."))
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func titleAndRenameSection(for item: DownloadItem) -> some View {
        if isEditingDownloadName && canRenameSelectedDownload {
            HStack(spacing: 8) {
                TextField(L("New file name"), text: $downloadRenameDraft)
                    .textFieldStyle(.roundedBorder)
                Button(L("Apply")) {
                    model.renameDownload(item, to: downloadRenameDraft)
                    isEditingDownloadName = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    model.isBusy ||
                    downloadRenameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    downloadRenameDraft == item.name
                )
                Button(L("Cancel")) {
                    downloadRenameDraft = item.name
                    isEditingDownloadName = false
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(.title3)
                        .lineLimit(2)
                        .truncationMode(.middle)

                    if let suggestion = displayedFilenameValue(for: item) {
                        HStack(spacing: 8) {
                            Label(suggestionHeaderTitle(for: item), systemImage: "wand.and.stars")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(suggestionHeaderColor(for: item))
                            Text(suggestion)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if actionableFilenameSuggestion(for: item) != nil && canRenameSelectedDownload {
                                Button(L("Use Suggested Filename")) {
                                    useSuggestionForRename(item, suggestion: suggestion)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                                .disabled(model.isBusy)
                            }
                        }
                    }
                }
                Spacer()
                if canRenameSelectedDownload {
                    Button(L("Edit")) {
                        downloadRenameDraft = item.name
                        isEditingDownloadName = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(model.isBusy)
                }
            }
        }
    }

    @ViewBuilder
    private func detailRowsSection(for item: DownloadItem) -> some View {
        HStack(alignment: .top, spacing: 22) {
            primaryDetailRows(for: item)
                .frame(maxWidth: .infinity, alignment: .leading)
            secondaryDetailRows(for: item)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func primaryDetailRows(for item: DownloadItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            detailRowLarge("Completed", item.completionText)
            detailRowLarge("Transferred", item.transferredText)
            detailRowLarge("Sources", item.sourcesText)
            detailRowLarge("Priority", item.priorityText)
            detailRowLarge("Category", String(item.category))
            detailRowLarge("Part File", item.partMetName.isEmpty ? "-" : item.partMetName)
        }
    }

    private func secondaryDetailRows(for item: DownloadItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            detailRowLarge("Transferring", String(item.sourceTransferring))
            detailRowLarge("A4AF", String(item.sourceA4AF))
            detailRowLarge("Available Parts", String(item.availableParts))
            detailRowLarge("Active Time", item.activeTimeText)
            detailRowLarge("Last Seen Complete", item.lastSeenCompleteText)
            detailRowLarge("Last Received", item.lastReceivedText)
            detailRowLarge("Shared", item.shared ? L("Yes") : L("No"))
        }
    }

    private func alternativeNamesSection(for item: DownloadItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Alternative Names"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(item.alternativeNames.sorted(by: { $0.count > $1.count })) { alt in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(alt.name)
                            .font(.body)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if let suggestion = alt.meaningfulFilenameSuggestion(prefixes: filenameCleanupPrefixes) {
                            Label(suggestion, systemImage: "wand.and.stars")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    Spacer()
                    Text(LF("x%lld", Int64(alt.count)))
                        .font(.body)
                        .foregroundStyle(.secondary)
                    if canRenameSelectedDownload {
                        Button(L("Use")) {
                            useSuggestionForRename(
                                item,
                                suggestion: alt.meaningfulFilenameSuggestion(prefixes: filenameCleanupPrefixes) ?? alt.name
                            )
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private func sourcesSection(for item: DownloadItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L("Sources"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if model.isRefreshingSources {
                    ProgressView()
                        .controlSize(.small)
                }
                Menu(L("A4AF")) {
                    Button(L("Swap to this file")) {
                        model.swapA4AF(item, mode: .toThis)
                    }
                    .disabled(!model.isBridgeOpSupported("download-a4af-this"))
                    Button(L("Swap to this file automatically")) {
                        model.swapA4AF(item, mode: .toThisAuto)
                    }
                    .disabled(!model.isBridgeOpSupported("download-a4af-auto"))
                    Button(L("Swap to another file")) {
                        model.swapA4AF(item, mode: .toAnyOther)
                    }
                    .disabled(!model.isBridgeOpSupported("download-a4af-others"))
                }
                .disabled(
                    model.isBusy ||
                    item.sourceA4AF == 0 ||
                    (
                        !model.isBridgeOpSupported("download-a4af-this") &&
                        !model.isBridgeOpSupported("download-a4af-auto") &&
                        !model.isBridgeOpSupported("download-a4af-others")
                    )
                )
                Button(L("Refresh")) {
                    model.refreshDownloadSources(for: item)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(model.isRefreshingSources)
            }

            if let sourceError = selectedDownloadSourceError {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(sourceError)
                        .textSelection(.enabled)
                }
                .font(.body)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            } else if selectedDownloadSources.isEmpty {
                Text(L("No sources available yet."))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                SourcesTableView(sources: selectedDownloadSources, sortOrder: $sourceSortOrder)
            }
        }
    }

    private func syncSelectionState(refreshSources: Bool) {
        guard let selectedDownload else {
            if model.selectedDownloadID != nil {
                model.selectedDownloadID = nil
            }
            downloadRenameDraft = ""
            isEditingDownloadName = false
            return
        }
        if !isEditingDownloadName || downloadRenameDraft.isEmpty {
            downloadRenameDraft = selectedDownload.name
        }
        if !canRenameSelectedDownload {
            isEditingDownloadName = false
        }
        if refreshSources {
            model.refreshDownloadSources(for: selectedDownload)
        }
        applyPendingRenameSuggestionIfNeeded()
    }

    private func applyPendingRenameSuggestionIfNeeded() {
        guard let selectedDownload else { return }
        guard let suggestion = model.consumeRenameSuggestionRequest(for: selectedDownload.id) else { return }
        guard canRenameSelectedDownload else { return }
        useSuggestionForRename(selectedDownload, suggestion: suggestion)
    }

    private func detailRowLarge(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(L(title) + ":")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 145, alignment: .leading)
            Text(value)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SourcesTableView: View {
    let sources: [DownloadSourceItem]
    @Binding var sortOrder: [KeyPathComparator<DownloadSourceItem>]

    var body: some View {
        Table(sources, sortOrder: $sortOrder) {
            TableColumn(L("Client"), value: \.clientName) { source in
                Text(source.clientDisplayName)
            }
            .width(min: 160, ideal: 220, max: 360)

            TableColumn(L("Endpoint"), value: \.userIP) { source in
                Text(source.endpoint)
                    .font(.system(.body, design: .monospaced))
            }
            .width(min: 130, ideal: 160, max: 250)

            TableColumn(L("Software"), value: \.softwareVersion) { source in
                Text(source.softwareDisplay)
                    .lineLimit(1)
            }
            .width(min: 120, ideal: 170, max: 260)

            TableColumn(L("State"), value: \.downloadStateText) { source in
                Text(source.downloadStateText)
            }
            .width(min: 130, ideal: 160, max: 260)

            TableColumn(L("Speed"), value: \.downSpeedKBps) { source in
                Text(source.speedText)
            }
            .width(min: 90, ideal: 110, max: 180)

            TableColumn(L("Avail"), value: \.availableParts) { source in
                Text(String(source.availableParts))
            }
            .width(min: 60, ideal: 80, max: 110)

            TableColumn(L("Queue"), value: \.remoteQueueRank) { source in
                Text(source.queueRankText)
            }
            .width(min: 70, ideal: 82, max: 120)

            TableColumn(L("From"), value: \.sourceFromText) { source in
                Text(source.sourceFromText)
            }
            .width(min: 110, ideal: 140, max: 210)

            TableColumn(L("Server"), value: \.serverName) { source in
                Text(source.serverEndpoint)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .width(min: 170, ideal: 240, max: 360)

            TableColumnForEach(SourceTrailingColumn.allCases) { column in
                TableColumn(L(column.title)) { source in
                    Text(column.text(for: source))
                        .lineLimit(1)
                        .truncationMode(column.truncationMode)
                }
                .width(min: column.width.min, ideal: column.width.ideal, max: column.width.max)
            }
        }
        .frame(height: tableHeight)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }

    private var tableHeight: CGFloat {
        let rowHeight: CGFloat = 28
        let headerHeight: CGFloat = 30
        let clampedRows = max(1, min(sources.count, 5))
        if sources.count <= 5 {
            return headerHeight + rowHeight * CGFloat(clampedRows) + 4
        }
        return 230
    }
}

private enum SourceTrailingColumn: String, CaseIterable, Identifiable {
    case remoteName
    case downloaded
    case uploaded
    case version
    case shares

    var id: String { rawValue }

    var title: String {
        switch self {
        case .remoteName: return "Remote Name"
        case .downloaded: return "Downloaded"
        case .uploaded: return "Uploaded"
        case .version: return "Version"
        case .shares: return "Shares"
        }
    }

    var width: (min: CGFloat, ideal: CGFloat, max: CGFloat) {
        switch self {
        case .remoteName: return (220, 340, 520)
        case .downloaded: return (90, 110, 180)
        case .uploaded: return (90, 110, 180)
        case .version: return (120, 170, 260)
        case .shares: return (70, 84, 120)
        }
    }

    var truncationMode: Text.TruncationMode {
        self == .remoteName ? .middle : .tail
    }

    func text(for source: DownloadSourceItem) -> String {
        switch self {
        case .remoteName: return source.remoteFilename.isEmpty ? "-" : source.remoteFilename
        case .downloaded: return source.downloadedText
        case .uploaded: return source.uploadedText
        case .version: return source.versionDisplay
        case .shares: return source.sharesFileListText
        }
    }
}
