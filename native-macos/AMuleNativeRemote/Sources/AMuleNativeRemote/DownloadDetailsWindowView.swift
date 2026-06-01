import SwiftUI
import AppKit
import SharedUI
import SharedCore

private func L2(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func LF2(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), locale: .current, arguments: args)
}

struct DownloadDetailsWindowView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("amule.ui.alwaysShowSuggestedFilename") private var alwaysShowSuggestedFilename = false

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

    private var canRenameSelectedDownload: Bool {
        guard let item = selectedDownload else { return false }
        return !item.isCompletedLike
    }

    private func shouldShowSuggestion(for item: DownloadItem, suggestion: String) -> Bool {
        guard alwaysShowSuggestedFilename else { return false }
        if item.usesDiagnosticNameEncodingFallback(alwaysShowDiagnostic: alwaysShowSuggestedFilename) {
            return item.displayedNameEncodingValue(alwaysShowDiagnostic: alwaysShowSuggestedFilename) == suggestion
        }
        guard !item.nameEncodingSuspect else { return false }
        guard item.displayedNameEncodingValue(alwaysShowDiagnostic: alwaysShowSuggestedFilename) == suggestion else { return false }
        return true
    }

    private func useSuggestionForRename(_ item: DownloadItem, suggestion: String) {
        guard let draft = FilenameSuggestionPresentation.renameDraft(from: suggestion, currentName: item.name) else { return }
        downloadRenameDraft = draft
        isEditingDownloadName = true
    }

    private func suggestionSectionTitle(for item: DownloadItem) -> String {
        if item.usesDiagnosticNameEncodingFallback(alwaysShowDiagnostic: alwaysShowSuggestedFilename) {
            return "Current Filename (Diagnostic)"
        }
        if alwaysShowSuggestedFilename && !item.nameEncodingSuspect {
            return "Suggested Filename (Diagnostic)"
        }
        return "Suggested Filename"
    }

    private func suggestionHelpText(for item: DownloadItem) -> String {
        if item.usesDiagnosticNameEncodingFallback(alwaysShowDiagnostic: alwaysShowSuggestedFilename) {
            return "Diagnostic display only. No distinct filename suggestion was detected, so this shows the current/original filename."
        }
        if canRenameSelectedDownload {
            return "Diagnostic guess only. The original filename stays unchanged until you apply a rename."
        }
        return "Diagnostic guess only. The original filename is preserved, and renaming is not available for this download."
    }

    private func suggestionHeaderTitle(for item: DownloadItem) -> String {
        if item.usesDiagnosticNameEncodingFallback(alwaysShowDiagnostic: alwaysShowSuggestedFilename) {
            return "Current Filename (Diagnostic)"
        }
        return item.nameEncodingSuspect ? "Suggested Filename" : "Diagnostic Suggestion"
    }

    private func suggestionHeaderColor(for item: DownloadItem) -> Color {
        item.usesDiagnosticNameEncodingFallback(alwaysShowDiagnostic: alwaysShowSuggestedFilename)
            ? .secondary
            : (item.nameEncodingSuspect ? .orange : .secondary)
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
                            TextField("New file name", text: $downloadRenameDraft)
                                .textFieldStyle(.roundedBorder)
                            Button("Apply") {
                                model.renameDownload(item, to: downloadRenameDraft)
                                isEditingDownloadName = false
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(
                                model.isBusy ||
                                downloadRenameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                downloadRenameDraft == item.name
                            )
                            Button("Cancel") {
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

                                if let suggestion = item.displayedNameEncodingValue(alwaysShowDiagnostic: alwaysShowSuggestedFilename) {
                                    HStack(spacing: 8) {
                                        Label(suggestionHeaderTitle(for: item), systemImage: "wand.and.stars")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(suggestionHeaderColor(for: item))
                                        Text(suggestion)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        if item.meaningfulNameEncodingSuggestion != nil && canRenameSelectedDownload {
                                            Button("Use Suggested Filename") {
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
                                Button("Edit") {
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

                    if let suggestion = item.displayedNameEncodingValue(alwaysShowDiagnostic: alwaysShowSuggestedFilename),
                       shouldShowSuggestion(for: item, suggestion: suggestion) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(suggestionSectionTitle(for: item))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(suggestion)
                                        .font(.body)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(suggestionHelpText(for: item))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if item.meaningfulNameEncodingSuggestion != nil && canRenameSelectedDownload {
                                    Button("Use Suggested Filename") {
                                        useSuggestionForRename(item, suggestion: suggestion)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .disabled(model.isBusy)
                                }
                            }
                        }

                        Divider()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        DownloadSegmentedProgressBar(
                            colors: item.progressColors,
                            fallbackProgress: item.progressDisplayValue / 100.0
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
                        Button("Copy") {
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
                                Text("Alternative Names")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                ForEach(item.alternativeNames.sorted(by: { $0.count > $1.count })) { alt in
                                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(alt.name)
                                                .font(.body)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                            if let suggestion = alt.meaningfulNameEncodingSuggestion {
                                                Label(suggestion, systemImage: "wand.and.stars")
                                                    .font(.caption)
                                                    .foregroundStyle(.orange)
                                                    .lineLimit(1)
                                                    .truncationMode(.middle)
                                            }
                                        }
                                        Spacer()
                                        Text("x\(alt.count)")
                                            .font(.body)
                                            .foregroundStyle(.secondary)
                                        if canRenameSelectedDownload {
                                            Button("Use") {
                                                useSuggestionForRename(item, suggestion: alt.meaningfulNameEncodingSuggestion ?? alt.name)
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
                            Text("Sources")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if model.isRefreshingSources {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Button("Refresh") {
                                model.refreshDownloadSources(for: item)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(model.isRefreshingSources)
                        }

                        if selectedDownloadSources.isEmpty {
                            Text("No sources available yet.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                        } else {
                            Table(selectedDownloadSources, sortOrder: $sourceSortOrder) {
                                TableColumn("Client", value: \.clientName) { source in
                                    Text(source.clientDisplayName)
                                }
                                .width(min: 160, ideal: 220, max: 360)

                                TableColumn("Endpoint", value: \.userIP) { source in
                                    Text(source.endpoint)
                                        .font(.system(.body, design: .monospaced))
                                }
                                .width(min: 130, ideal: 160, max: 250)

                                TableColumn("Software", value: \.softwareVersion) { source in
                                    Text(source.softwareDisplay)
                                        .lineLimit(1)
                                }
                                .width(min: 120, ideal: 170, max: 260)

                                TableColumn("State", value: \.downloadStateText) { source in
                                    Text(source.downloadStateText)
                                }
                                .width(min: 130, ideal: 160, max: 260)

                                TableColumn("Speed", value: \.downSpeedKBps) { source in
                                    Text(source.speedText)
                                }
                                .width(min: 90, ideal: 110, max: 180)

                                TableColumn("Avail", value: \.availableParts) { source in
                                    Text(String(source.availableParts))
                                }
                                .width(min: 60, ideal: 80, max: 110)

                                TableColumn("Queue", value: \.remoteQueueRank) { source in
                                    Text(source.queueRankText)
                                }
                                .width(min: 70, ideal: 82, max: 120)

                                TableColumn("From", value: \.sourceFromText) { source in
                                    Text(source.sourceFromText)
                                }
                                .width(min: 110, ideal: 140, max: 210)

                                TableColumn("Server", value: \.serverName) { source in
                                    Text(source.serverEndpoint)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                .width(min: 170, ideal: 240, max: 360)

                                TableColumn("Remote Name", value: \.remoteFilename) { source in
                                    Text(source.remoteFilename.isEmpty ? "-" : source.remoteFilename)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                .width(min: 220, ideal: 340, max: 520)
                            }
                            .frame(height: sourcesTableHeight)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Select a download item in the Downloads window first.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .padding(14)
        .frame(width: 820, alignment: .topLeading)
        .frame(minHeight: 180, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            GlassEffectBackground(material: .underWindowBackground)
                .ignoresSafeArea()
        )
        .background(
            WindowAppearanceConfigurator(
                hideTitle: true,
                transparentTitlebar: true,
                fullSizeContentView: true,
                toolbarStyle: .automatic,
                showsToolbarBaselineSeparator: false,
                makeWindowTransparent: true,
                ensureToolbarWhenTransparentTitlebar: false,
                forceNoToolbar: true
            )
        )
        .onAppear {
            syncSelectionState()
        }
        .onChange(of: model.selectedDownloadID) { _, _ in
            syncSelectionState()
        }
        .onChange(of: model.downloads) {
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
