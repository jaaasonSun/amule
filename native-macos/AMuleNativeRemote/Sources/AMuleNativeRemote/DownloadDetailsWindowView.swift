import SwiftUI
import AppKit
import SharedViews
import SharedModels
import SharedServices

private func L2(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func LF2(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), locale: .current, arguments: args)
}

struct DownloadDetailsWindowView: View {
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
            return L2("Suggested Filename")
        }
        if item.usesDiagnosticNameEncodingFallback(alwaysShowDiagnostic: alwaysShowSuggestedFilename) {
            return L2("Current Filename (Diagnostic)")
        }
        return item.nameEncodingSuspect ? L2("Suggested Filename") : L2("Diagnostic Suggestion")
    }

    private func suggestionHeaderColor(for item: DownloadItem) -> Color {
        if actionableFilenameSuggestion(for: item) != nil {
            return Color.orange
        }
        return item.usesDiagnosticNameEncodingFallback(alwaysShowDiagnostic: alwaysShowSuggestedFilename)
            ? Color.secondary
            : (item.nameEncodingSuspect ? Color.orange : Color.secondary)
    }

    private var sourcesTableHeight: CGFloat {
        let rowHeight: CGFloat = 28
        let headerHeight: CGFloat = 30
        let clampedRows = max(1, min(selectedDownloadSources.count, 5))
        if selectedDownloadSources.count <= 5 {
            return headerHeight + rowHeight * CGFloat(clampedRows) + 4
        }
        return 230
    }

    var body: some View {
        VStack(spacing: 12) {
            if let item = selectedDownload {
                VStack(alignment: .leading, spacing: 12) {
                    if isEditingDownloadName && canRenameSelectedDownload {
                        HStack(spacing: 8) {
                            TextField(L2("New file name"), text: $downloadRenameDraft)
                                .textFieldStyle(.roundedBorder)
                            Button(L2("Apply")) {
                                model.renameDownload(item, to: downloadRenameDraft)
                                isEditingDownloadName = false
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(
                                model.isBusy ||
                                downloadRenameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                downloadRenameDraft == item.name
                            )
                            Button(L2("Cancel")) {
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
                                            Button(L2("Use Suggested Filename")) {
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
                                Button(L2("Edit")) {
                                    downloadRenameDraft = item.name
                                    isEditingDownloadName = true
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(model.isBusy)
                            }
                        }
                    }

                    Text(item.id)
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        DownloadSegmentedProgressBar(
                            colors: item.progressColors
                        )
                        Text(LF2("Progress: %@", item.progressText))
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
                        Button(L2("Copy")) {
                            model.copyDownloadLinkToClipboard(item)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 22) {
                            VStack(alignment: .leading, spacing: 8) {
                                detailRowLarge("Completed", item.completionText)
                                detailRowLarge("Transferred", item.transferredText)
                                detailRowLarge("Sources", item.sourcesText)
                                detailRowLarge("Priority", item.priorityText)
                                detailRowLarge("Category", String(item.category))
                                detailRowLarge("Part File", item.partMetName.isEmpty ? "-" : item.partMetName)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            VStack(alignment: .leading, spacing: 8) {
                                detailRowLarge("Transferring", String(item.sourceTransferring))
                                detailRowLarge("A4AF", String(item.sourceA4AF))
                                detailRowLarge("Available Parts", String(item.availableParts))
                                detailRowLarge("Active Time", item.activeTimeText)
                                detailRowLarge("Last Seen Complete", item.lastSeenCompleteText)
                                detailRowLarge("Last Received", item.lastReceivedText)
                                detailRowLarge("Shared", item.shared ? L2("Yes") : L2("No"))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if !item.alternativeNames.isEmpty {
                            Divider()
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L2("Alternative Names"))
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
                                        Text(LF2("x%lld", Int64(alt.count)))
                                            .font(.body)
                                            .foregroundStyle(.secondary)
                                        if canRenameSelectedDownload {
                                            Button(L2("Use")) {
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

                        Divider()

                        HStack {
                            Text(L2("Sources"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if model.isRefreshingSources {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Menu(L2("A4AF")) {
                                Button(L2("Swap to this file")) {
                                    model.swapA4AF(item, mode: .toThis)
                                }
                                .disabled(!model.isBridgeOpSupported("download-a4af-this"))
                                Button(L2("Swap to this file automatically")) {
                                    model.swapA4AF(item, mode: .toThisAuto)
                                }
                                .disabled(!model.isBridgeOpSupported("download-a4af-auto"))
                                Button(L2("Swap to another file")) {
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
                            Button(L2("Refresh")) {
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
                            Text(L2("No sources available yet."))
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                        } else {
                            SourcesTableView(sources: selectedDownloadSources, sortOrder: $sourceSortOrder)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(L2("Select a download item in the Downloads window first."))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .padding(14)
        .frame(width: 820, alignment: .topLeading)
        .frame(minHeight: 180, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            syncSelectionState()
        }
        .onChange(of: model.selectedDownloadID) { _, _ in
            syncSelectionState()
        }
        .onChange(of: model.renameSuggestionRequestID) { _, _ in
            applyPendingRenameSuggestionIfNeeded()
        }
    }

    private func syncSelectionState() {
        guard let selectedDownload else {
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
        model.refreshDownloadSources(for: selectedDownload)
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
            Text(L2(title) + ":")
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
            TableColumn(L2("Client"), value: \.clientName) { source in
                Text(source.clientDisplayName)
            }
            .width(min: 160, ideal: 220, max: 360)

            TableColumn(L2("Endpoint"), value: \.userIP) { source in
                Text(source.endpoint)
                    .font(.system(.body, design: .monospaced))
            }
            .width(min: 130, ideal: 160, max: 250)

            TableColumn(L2("Software"), value: \.softwareVersion) { source in
                Text(source.softwareDisplay)
                    .lineLimit(1)
            }
            .width(min: 120, ideal: 170, max: 260)

            TableColumn(L2("State"), value: \.downloadStateText) { source in
                Text(source.downloadStateText)
            }
            .width(min: 130, ideal: 160, max: 260)

            TableColumn(L2("Speed"), value: \.downSpeedKBps) { source in
                Text(source.speedText)
            }
            .width(min: 90, ideal: 110, max: 180)

            TableColumn(L2("Avail"), value: \.availableParts) { source in
                Text(String(source.availableParts))
            }
            .width(min: 60, ideal: 80, max: 110)

            TableColumn(L2("Queue"), value: \.remoteQueueRank) { source in
                Text(source.queueRankText)
            }
            .width(min: 70, ideal: 82, max: 120)

            TableColumn(L2("From"), value: \.sourceFromText) { source in
                Text(source.sourceFromText)
            }
            .width(min: 110, ideal: 140, max: 210)

            TableColumn(L2("Server"), value: \.serverName) { source in
                Text(source.serverEndpoint)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .width(min: 170, ideal: 240, max: 360)

            TableColumnForEach(SourceTrailingColumn.allCases) { column in
                TableColumn(L2(column.title)) { source in
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

#if DEBUG
#Preview("No Selection") {
    DownloadDetailsWindowView()
        .environmentObject(AppModel.previewWithDownloads())
}

#Preview("Downloading Selection") {
    let model = AppModel.previewWithDownloads()
    model.selectedDownloadID = model.downloads.first(where: { !$0.isCompleted })?.id
    return DownloadDetailsWindowView()
        .environmentObject(model)
}

#Preview("With Sources") {
    let model = AppModel.previewWithDownloads()
    let downloading = model.downloads.first(where: { !$0.isCompleted })
    model.selectedDownloadID = downloading?.id
    if let downloadId = downloading?.id {
        model.downloadSourcesByHash[downloadId] = [
            DownloadSourceItem(
                id: 1, requestFileID: 1, clientName: "eMule v0.60",
                userIP: "192.168.1.100", userPort: 4662,
                serverName: "ExampleServer", serverIP: "5.45.85.226", serverPort: 6584,
                software: "eMule", softwareVersion: "0.60",
                downloadState: 4, downloadStateText: "Downloading",
                sourceFrom: 1, sourceFromText: "Server",
                downSpeedKBps: 125.5, availableParts: 64,
                remoteQueueRank: 0, obfuscationStatus: 0,
                extendedProtocol: false, remoteFilename: "Ubuntu ISO",
                downloadedTotal: 1_258_291, uploadedTotal: 64_512,
                versionString: "0.60", sharesFileList: true
            ),
            DownloadSourceItem(
                id: 2, requestFileID: 1, clientName: "aMule v2.3",
                userIP: "10.0.0.50", userPort: 4662,
                serverName: "Server", serverIP: "1.2.3.4", serverPort: 4661,
                software: "aMule", softwareVersion: "2.3",
                downloadState: 1, downloadStateText: "On Queue",
                sourceFrom: 2, sourceFromText: "Kad",
                downSpeedKBps: 0, availableParts: 32,
                remoteQueueRank: 150, obfuscationStatus: 0,
                extendedProtocol: true, remoteFilename: "Ubuntu ISO",
                downloadedTotal: 0, uploadedTotal: 131_072,
                versionString: "2.3", sharesFileList: false
            )
        ]
    }
    return DownloadDetailsWindowView()
        .environmentObject(model)
}
#endif
