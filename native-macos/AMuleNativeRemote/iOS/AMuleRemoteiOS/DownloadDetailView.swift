#if canImport(UIKit)
import SwiftUI
import AMuleRemoteIOSShared
import SharedUI

struct DownloadDetailView: View {
    @ObservedObject var model: IOSAppModel
    let item: DownloadItem
    @State private var renameDraft = ""
    @State private var isRenaming = false

    private var currentItem: DownloadItem {
        model.downloads.first(where: { $0.id == item.id }) ?? item
    }

    private var sources: [DownloadSourceItem] {
        model.sources(for: currentItem)
    }

    private var canRename: Bool {
        !currentItem.isCompletedLike && !model.isBusy
    }

    var body: some View {
        List {
            fileSummarySection
            nameSuggestionSection
            progressSection
            ed2kLinkSection
            alternativeNamesSection
            detailsSection
            sourcesSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(currentItem.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model.sources(for: currentItem).isEmpty {
                model.refreshDownloadSources(for: currentItem)
            }
        }
        .onChange(of: currentItem.name) { _, newName in
            if isRenaming && renameDraft == newName {
                isRenaming = false
            }
        }
    }

    // MARK: - File Summary

    private var fileSummarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                if isRenaming {
                    TextField("File name", text: $renameDraft, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(2...6)
                    HStack {
                        Button {
                            model.renameDownload(currentItem, to: renameDraft)
                        } label: {
                            Label("Apply", systemImage: "checkmark")
                        }
                        .disabled(model.isBusy || renameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || renameDraft == currentItem.name)
                        Button(role: .cancel) {
                            isRenaming = false
                            renameDraft = currentItem.name
                        } label: {
                            Label("Cancel", systemImage: "xmark")
                        }
                        .disabled(model.isBusy)
                    }
                } else {
                    HStack(alignment: .top) {
                        Text(currentItem.name)
                            .font(.headline)
                            .lineLimit(4)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                        Spacer()
                        if canRename {
                            Button {
                                renameDraft = currentItem.name
                                isRenaming = true
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                        }
                    }
                }

                Text(currentItem.id)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        } header: {
            Label("File", systemImage: "doc")
        }
    }

    private var nameSuggestionSection: some View {
        Group {
            if let suggestion = currentItem.meaningfulNameEncodingSuggestion {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "wand.and.stars")
                                .foregroundStyle(.orange)
                            Text(suggestion)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .lineLimit(5)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }

                        Text("Detected a likely filename encoding mix-up. The current name is unchanged until you apply the suggestion.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if canRename {
                            Button {
                                useSuggestionForRename(suggestion)
                            } label: {
                                Label("Use Suggested Filename", systemImage: "wand.and.stars")
                            }
                        }
                    }
                } header: {
                    Label("Suggested Filename", systemImage: "wand.and.stars")
                }
            }
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                DownloadSegmentedProgressBar(
                    colors: currentItem.progressColors,
                    fallbackProgress: currentItem.progressDisplayValue / 100.0
                )

                HStack {
                    Text(currentItem.progressText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    if currentItem.speedBytes > 0 {
                        Text(currentItem.speedText)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Label("Progress", systemImage: "chart.bar")
        }
    }

    // MARK: - Ed2k Link

    private var ed2kLinkSection: some View {
        Section {
            HStack(alignment: .top, spacing: 8) {
                Text(currentItem.ed2kLink)
                    .font(.caption.monospaced())
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                Spacer()

                Button {
                    model.copyDownloadLinkToClipboard(currentItem)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
        } header: {
            Label("ed2k Link", systemImage: "link")
        }
    }

    // MARK: - Details

    private var detailsSection: some View {
        Section {
            detailRow("Completed", value: currentItem.completionText)
            detailRow("Transferred", value: currentItem.transferredText)
            detailRow("Sources", value: currentItem.sourcesText)
            detailRow("Priority", value: currentItem.priorityText)
            detailRow("Category", value: String(currentItem.category))
            if !currentItem.partMetName.isEmpty {
                detailRow("Part File", value: currentItem.partMetName)
            }
            detailRow("Transferring", value: String(currentItem.sourceTransferring))
            detailRow("A4AF", value: String(currentItem.sourceA4AF))
            detailRow("Available Parts", value: String(currentItem.availableParts))
            detailRow("Active Time", value: currentItem.activeTimeText)
            detailRow("Last Seen Complete", value: currentItem.lastSeenCompleteText)
            detailRow("Last Received", value: currentItem.lastReceivedText)
            detailRow("Shared", value: currentItem.shared ? L("Yes") : L("No"))
        } header: {
            Label("Details", systemImage: "info.circle")
        }
    }

    private var alternativeNamesSection: some View {
        Group {
            if !currentItem.alternativeNames.isEmpty {
                Section {
                    ForEach(currentItem.alternativeNames.sorted(by: { $0.count > $1.count })) { alt in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(alt.name)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                                    .textSelection(.enabled)
                                if let suggestion = alt.meaningfulNameEncodingSuggestion {
                                    Label(suggestion, systemImage: "wand.and.stars")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .lineLimit(2)
                                        .truncationMode(.middle)
                                        .textSelection(.enabled)
                                }
                            }
                            Spacer()
                            Text("x\(alt.count)")
                                .foregroundStyle(.secondary)
                            if canRename {
                                Button {
                                    useSuggestionForRename(alt.meaningfulNameEncodingSuggestion ?? alt.name)
                                } label: {
                                    Label("Use", systemImage: "checkmark")
                                }
                            }
                        }
                    }
                } header: {
                    Label("Alternative Names", systemImage: "text.quote")
                }
            }
        }
    }

    // MARK: - Sources

    private var sourcesSection: some View {
        Section {
            if model.isRefreshingSources {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading sources\u{2026}")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else if sources.isEmpty {
                ContentUnavailableView(
                    "No Sources",
                    systemImage: "person.crop.circle.badge.xmark",
                    description: Text("No sources available yet for this download.")
                )
            } else {
                ForEach(sources) { source in
                    sourceRow(source)
                }
            }
        } header: {
            HStack {
                Text("Sources")
                Spacer()
                Button {
                    model.refreshDownloadSources(for: currentItem)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(model.isRefreshingSources)
            }
        }
    }

    // MARK: - Source Row

    private func sourceRow(_ source: DownloadSourceItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(localizedClientDisplayName(source))
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Spacer()
                Text(localizedSourceDownloadStateText(source))
                    .font(.caption)
                    .foregroundStyle(stateColor(source.downloadState))
            }

            HStack(spacing: 12) {
                Text(source.endpoint)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(source.softwareDisplay)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 12) {
                if source.downSpeedKBps > 0 {
                    Label(source.speedText, systemImage: "arrow.down")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.green)
                }

                if source.remoteQueueRank > 0 && source.remoteQueueRank != 0xffff {
                    Text(LF("QR: %@", localizedQueueRankText(source)))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if source.availableParts > 0 {
                    Text(LF("%lld parts", source.availableParts))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(localizedSourceFromText(source))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(L(label))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
        }
        .font(.subheadline)
    }

    private func localizedClientDisplayName(_ source: DownloadSourceItem) -> String {
        source.clientName.isEmpty ? L("(unknown client)") : source.clientDisplayName
    }

    private func localizedQueueRankText(_ source: DownloadSourceItem) -> String {
        source.queueRankText == "Full" ? L("Full") : source.queueRankText
    }

    private func localizedSourceDownloadStateText(_ source: DownloadSourceItem) -> String {
        switch source.downloadState {
        case 0...4:
            return L(source.downloadStateText)
        default:
            return source.downloadStateText
        }
    }

    private func localizedSourceFromText(_ source: DownloadSourceItem) -> String {
        switch source.sourceFrom {
        case 0...4:
            return L(source.sourceFromText)
        default:
            return source.sourceFromText
        }
    }

    private func stateColor(_ state: Int) -> Color {
        switch SourceDownloadState(rawValue: state) {
        case .downloading:              return .green
        case .onQueue:                  return .orange
        case .connecting:               return .secondary
        case .tooManyConnections:        return .red
        case .none:                      return .secondary
        }
    }

    private func useSuggestionForRename(_ suggestion: String) {
        guard let draft = FilenameSuggestionPresentation.renameDraft(from: suggestion, currentName: currentItem.name) else {
            return
        }
        renameDraft = draft
        isRenaming = true
    }
}

#Preview {
    NavigationStack {
        DownloadDetailView(
            model: IOSAppModel(),
            item: DownloadItem(
                ecid: 1,
                id: "ABCDEF0123456789ABCDEF0123456789",
                name: "Ubuntu 24.04 Desktop amd64.iso",
                nameEncodingSuspect: false,
                nameEncodingSuggestion: nil,
                sizeBytes: 5_100_000_000,
                doneBytes: 3_060_000_000,
                transferredBytes: 3_200_000_000,
                progressValue: 60.0,
                sourceCurrent: 5,
                sourceTotal: 42,
                sourceTransferring: 3,
                sourceA4AF: 0,
                statusCode: 4,
                isCompleted: false,
                status: "Downloading",
                speedBytes: 512_000,
                priority: 1,
                category: 0,
                partMetName: "001.part.met",
                lastSeenComplete: 0,
                lastReceived: 0,
                activeSeconds: 3600,
                availableParts: 200,
                shared: false,
                alternativeNames: [],
                progressColors: []
            )
        )
    }
}
#endif
