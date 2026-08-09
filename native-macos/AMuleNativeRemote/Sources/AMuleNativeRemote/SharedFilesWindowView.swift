import SwiftUI
import AppKit
import AMuleECBridgeAdapter
import SharedViews
import SharedModels

struct SharedFilesWindowView: View {
    @EnvironmentObject private var model: AppModel
    let embeddedInMainWindow: Bool
    @State private var editingSharedFile: BridgeSharedFilePayload?
    @State private var editComment = ""
    @State private var editRating = 0
    @State private var selectedSharedFileIDs: Set<SharedFileRow.ID>
    @State private var sharedFileSortOrder = [
        KeyPathComparator(\SharedFileRow.name, order: .forward)
    ]
    @State private var sharedFileFilterQuery: String

    init(
        embeddedInMainWindow: Bool = false,
        initialSelectedSharedFileIDs: Set<String> = [],
        initialFilterQuery: String = ""
    ) {
        self.embeddedInMainWindow = embeddedInMainWindow
        _selectedSharedFileIDs = State(initialValue: initialSelectedSharedFileIDs)
        _sharedFileFilterQuery = State(initialValue: initialFilterQuery)
    }

    var body: some View {
        content
            .frame(
                minWidth: embeddedInMainWindow ? nil : 960,
                minHeight: embeddedInMainWindow ? nil : 560
            )
            .task { model.refreshSharedFiles() }
            .toolbar { sharedFilesToolbar }
            .sheet(isPresented: editSheetBinding) {
                if let file = editingSharedFile {
                    sharedFileEditSheet(file)
                }
            }
            .onChange(of: model.sharedFiles) {
                pruneSharedFileSelection()
            }
            .onChange(of: sharedFileFilterQuery) {
                pruneSharedFileSelection()
            }
    }

    @ToolbarContentBuilder
    private var sharedFilesToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            ControlGroup {
                Button {
                    model.refreshSharedFiles()
                } label: {
                    Label(L("Refresh"), systemImage: "arrow.clockwise")
                }
                .help(L("Refresh Shared Files"))
                .keyboardShortcut("r", modifiers: [.command, .option])
                .accessibilityLabel(L("Refresh Shared Files"))
                .accessibilityHint(L("Refresh Shared Files"))
                .disabled(model.isBusy || !model.isBridgeOpSupported("shared-files"))

                Button {
                    model.reloadSharedFiles()
                } label: {
                    Label(L("Reload"), systemImage: "arrow.triangle.2.circlepath")
                }
                .help(L("Reload Shared Files"))
                .keyboardShortcut("r", modifiers: [.command, .option, .shift])
                .accessibilityLabel(L("Reload Shared Files"))
                .accessibilityHint(L("Reload Shared Files"))
                .disabled(model.isBusy || !model.isBridgeOpSupported("shared-files-reload"))
            }
            .controlGroupStyle(.navigation)

            ControlGroup {
                Button {
                    if let selectedSharedFile {
                        beginEditing(selectedSharedFile)
                    }
                } label: {
                    Label(L("Edit Comment and Rating"), systemImage: "text.bubble")
                }
                .help(L("Edit Comment and Rating"))
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel(L("Edit Comment and Rating"))
                .accessibilityHint(L("Edit Comment and Rating"))
                .disabled(model.isBusy || selectedSharedFile == nil || !model.isBridgeOpSupported("shared-file-comment-rating"))

                Button {
                    if let selectedSharedFile {
                        model.pasteboardShare.writeString(selectedSharedFile.ed2kLink)
                    }
                } label: {
                    Label(L("Copy eD2k Link"), systemImage: "doc.on.doc")
                }
                .help(L("Copy eD2k Link"))
                .keyboardShortcut("c", modifiers: [.command, .option])
                .accessibilityLabel(L("Copy eD2k Link"))
                .accessibilityHint(L("Copy eD2k Link"))
                .disabled(selectedSharedFile == nil)
            }
            .controlGroupStyle(.navigation)

            Menu {
                ForEach(sharedFilePriorityItems, id: \.priority) { item in
                    Button(L(item.title)) {
                        if let selectedSharedFile {
                            model.setSharedFilePriority(hash: selectedSharedFile.hash, priority: item.priority)
                        }
                    }
                }
            } label: {
                Label(L("Priority"), systemImage: "arrow.up.arrow.down.circle")
            }
            .help(L("Priority"))
            .accessibilityLabel(L("Priority"))
            .accessibilityHint(L("Priority"))
            .disabled(model.isBusy || selectedSharedFile == nil || !model.isBridgeOpSupported("shared-file-priority"))
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            if model.sharedFiles.isEmpty {
                SharedFilesStateView(
                    icon: "folder",
                    title: L("No shared files available"),
                    subtitle: L("Refresh shared files from the remote daemon.")
                )
            } else if filteredSharedFileRows.isEmpty {
                SharedFilesStateView(
                    icon: "line.3.horizontal.decrease.circle",
                    title: L("No matching shared files"),
                    subtitle: L("Adjust the Shared Files filter.")
                )
                Divider()
                sharedFilesFooter
            } else {
                sharedFilesTable
                Divider()
                sharedFilesFooter
            }
        }
        .searchable(text: $sharedFileFilterQuery, placement: .toolbar, prompt: L("Filter Shared Files"))
    }

    private var sharedFilesTable: some View {
        Table(filteredSharedFileRows, selection: $selectedSharedFileIDs, sortOrder: $sharedFileSortOrder) {
            TableColumn(L("Name"), value: \.name) { row in
                sharedFileTableCell(row) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                        Text(row.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .width(min: 220, ideal: 280, max: 560)

            TableColumn(L("Size"), sortUsing: KeyPathComparator(\SharedFileRow.size, order: .reverse)) { row in
                sharedFileTableCell(row, alignment: .trailing) {
                    Text(row.sizeText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 86, ideal: 100, max: 150)

            TableColumn(L("Path/Location"), value: \.path) { row in
                sharedFileTableCell(row) {
                    Text(row.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 220, ideal: 280, max: 620)

            TableColumn(L("Priority"), value: \.priority) { row in
                sharedFileTableCell(row) {
                    Text(row.priorityText)
                        .lineLimit(1)
                }
            }
            .width(min: 82, ideal: 96, max: 150)

            TableColumn(L("Rating/Comment"), sortUsing: KeyPathComparator(\SharedFileRow.ratingSortValue, order: .reverse)) { row in
                sharedFileTableCell(row) {
                    Text(row.ratingCommentText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(row.hasRatingOrComment ? .primary : .secondary)
                }
            }
            .width(min: 150, ideal: 180, max: 360)

            TableColumn(L("Requests"), value: \.requests) { row in
                sharedFileTableCell(row, alignment: .trailing) {
                    Text(row.requestsText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 76, ideal: 88, max: 130)

            TableColumn(L("Accepted"), value: \.accepts) { row in
                sharedFileTableCell(row, alignment: .trailing) {
                    Text(row.acceptsText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 76, ideal: 88, max: 130)

            TableColumn(L("Transferred"), sortUsing: KeyPathComparator(\SharedFileRow.transferredAll, order: .reverse)) { row in
                sharedFileTableCell(row, alignment: .trailing) {
                    Text(row.transferredText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 126, ideal: 146, max: 220)

            TableColumn(L("Complete Sources"), value: \.completeSources) { row in
                sharedFileTableCell(row, alignment: .trailing) {
                    Text(row.completeSourcesText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 112, ideal: 124, max: 170)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollContentBackground(.hidden)
        .accessibilityLabel(L("Shared Files"))
    }

    private var sharedFilesFooter: some View {
        HStack(spacing: 8) {
            Text(footerCountText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if !selectedSharedFileIDs.isEmpty {
                Text(LF("%lld selected", Int64(selectedSharedFileIDs.count)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
    }

    private var footerCountText: String {
        if trimmedFilterQuery.isEmpty {
            return LF("%lld shared file(s)", Int64(filteredSharedFileRows.count))
        }
        return LF("%lld of %lld shown", Int64(filteredSharedFileRows.count), Int64(model.sharedFiles.count))
    }

    private var filteredSharedFileRows: [SharedFileRow] {
        let rows = sharedFileRows(from: model.sharedFiles)
        let filtered: [SharedFileRow]
        if trimmedFilterQuery.isEmpty {
            filtered = rows
        } else {
            filtered = rows.filter { $0.matches(query: trimmedFilterQuery) }
        }
        return filtered.sorted(using: sharedFileSortOrder)
    }

    private var trimmedFilterQuery: String {
        sharedFileFilterQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedSharedFile: BridgeSharedFilePayload? {
        filteredSharedFileRows.first { selectedSharedFileIDs.contains($0.id) }?.file
    }

    private var editSheetBinding: Binding<Bool> {
        Binding(
            get: { editingSharedFile != nil },
            set: { isPresented in
                if !isPresented {
                    editingSharedFile = nil
                }
            }
        )
    }

    @ViewBuilder
    private func sharedFileContextMenu(_ file: BridgeSharedFilePayload) -> some View {
        Menu(L("Priority")) {
            ForEach(sharedFilePriorityItems, id: \.priority) { item in
                Button(L(item.title)) {
                    model.setSharedFilePriority(hash: file.hash, priority: item.priority)
                }
            }
        }
        .disabled(model.isBusy || !model.isBridgeOpSupported("shared-file-priority"))

        Button(L("Edit Comment and Rating")) {
            beginEditing(file)
        }
        .disabled(model.isBusy || !model.isBridgeOpSupported("shared-file-comment-rating"))

        Button(L("Copy eD2k Link")) {
            model.pasteboardShare.writeString(file.ed2kLink)
        }
    }

    private func sharedFileEditSheet(_ file: BridgeSharedFilePayload) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("Edit Comment and Rating"))
                .font(.headline)

            Text(file.name)
                .font(.subheadline)
                .lineLimit(2)

            TextField(L("Comment"), text: $editComment)

            Picker(L("Rating"), selection: $editRating) {
                ForEach(0...5, id: \.self) { rating in
                    Text("\(rating)").tag(rating)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Spacer()
                Button(L("Cancel")) {
                    editingSharedFile = nil
                }
                .keyboardShortcut(.cancelAction)
                Button(L("Apply")) {
                    model.setSharedFileCommentRating(
                        hash: file.hash,
                        comment: editComment,
                        rating: editRating
                    )
                    editingSharedFile = nil
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.isBusy || !model.isBridgeOpSupported("shared-file-comment-rating"))
            }
        }
        .padding(20)
        .frame(width: 420)
        .onExitCommand { editingSharedFile = nil }
    }

    private func sharedFileTableCell<Content: View>(
        _ row: SharedFileRow,
        alignment: Alignment = .leading,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: alignment)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .contextMenu { sharedFileContextMenu(row.file) }
            .accessibilityHint(L("Use the context menu for shared file actions."))
    }

    private func beginEditing(_ file: BridgeSharedFilePayload) {
        editComment = file.comment ?? ""
        editRating = file.rating ?? 0
        editingSharedFile = file
    }

    private func pruneSharedFileSelection() {
        let validIDs = Set(filteredSharedFileRows.map(\.id))
        selectedSharedFileIDs = selectedSharedFileIDs.intersection(validIDs)
    }
}

private struct SharedFilesStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        EmptyStateView(icon: icon, title: title, subtitle: subtitle)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(L("Shared Files empty state"))
            .accessibilityValue(title)
            .accessibilityHint(subtitle)
    }
}

private let sharedFilePriorityItems: [(title: String, priority: Int)] = [
    ("Very Low", 1),
    ("Low", 2),
    ("Normal", 5),
    ("High", 7),
    ("Very High", 9),
    ("Auto", 10),
]

private struct SharedFileRow: Identifiable {
    let id: String
    let file: BridgeSharedFilePayload

    var name: String { file.name }
    var path: String { file.path }
    var size: UInt64 { file.size }
    var priority: Int { file.priority }
    var requests: Int { file.requests }
    var accepts: Int { file.accepts }
    var transferredAll: UInt64 { file.xferredAll }
    var completeSources: Int { file.completeSources }
    var ratingSortValue: Int { file.rating ?? -1 }

    var sizeText: String {
        AMuleFormatter.fileSize(file.size)
    }

    var priorityText: String {
        sharedFilePriorityTitle(for: file.priority)
    }

    var hasRatingOrComment: Bool {
        file.rating != nil || !(file.comment ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var ratingCommentText: String {
        let comment = (file.comment ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let rating = file.rating, !comment.isEmpty {
            return "\(rating)/5 · \(comment)"
        }
        if let rating = file.rating {
            return "\(rating)/5"
        }
        if !comment.isEmpty {
            return comment
        }
        return "-"
    }

    var requestsText: String {
        sharedFileCountPair(current: file.requests, all: file.requestsAll)
    }

    var acceptsText: String {
        sharedFileCountPair(current: file.accepts, all: file.acceptsAll)
    }

    var transferredText: String {
        let current = AMuleFormatter.fileSize(file.xferred)
        let all = AMuleFormatter.fileSize(file.xferredAll)
        if file.xferredAll > 0 {
            return "\(current) / \(all)"
        }
        return current
    }

    var completeSourcesText: String {
        if file.completeSourcesLow > 0 || file.completeSourcesHigh > 0 {
            return "\(file.completeSources) (\(file.completeSourcesLow)–\(file.completeSourcesHigh))"
        }
        return String(file.completeSources)
    }

    func matches(query: String) -> Bool {
        name.localizedCaseInsensitiveContains(query) ||
            path.localizedCaseInsensitiveContains(query) ||
            file.hash.localizedCaseInsensitiveContains(query) ||
            (file.comment ?? "").localizedCaseInsensitiveContains(query)
    }
}

private func sharedFileRows(from files: [BridgeSharedFilePayload]) -> [SharedFileRow] {
    files.enumerated().map { offset, file in
        SharedFileRow(
            id: sharedFileRowIdentifier(file: file, offset: offset),
            file: file
        )
    }
}

func sharedFileRowIdentifier(file: BridgeSharedFilePayload, offset: Int) -> String {
    "\(offset)|\(file.hash)|\(file.path)|\(file.name)"
}

private func sharedFilePriorityTitle(for priority: Int) -> String {
    if let item = sharedFilePriorityItems.first(where: { $0.priority == priority }) {
        return L(item.title)
    }
    return String(priority)
}

private func sharedFileCountPair(current: Int, all: Int) -> String {
    if all > 0 {
        return "\(current) / \(all)"
    }
    return String(current)
}
