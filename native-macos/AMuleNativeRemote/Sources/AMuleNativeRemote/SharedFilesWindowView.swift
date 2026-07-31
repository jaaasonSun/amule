import SwiftUI
import AppKit
import AMuleECBridgeAdapter
#if canImport(SharedViews)
import SharedViews
import SharedModels
import SharedServices
#endif

private func L2(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func LF2(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), locale: .current, arguments: args)
}

struct SharedFilesWindowView: View {
    @EnvironmentObject private var model: AppModel
    let embeddedInMainWindow: Bool
    @State private var editingSharedFile: BridgeSharedFilePayload?
    @State private var editComment = ""
    @State private var editRating = 0

    init(embeddedInMainWindow: Bool = false) {
        self.embeddedInMainWindow = embeddedInMainWindow
    }

    var body: some View {
        content
            .frame(
                minWidth: embeddedInMainWindow ? nil : 760,
                minHeight: embeddedInMainWindow ? nil : 500
            )
            .task { model.refreshSharedFiles() }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        model.refreshSharedFiles()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .help("Refresh Shared Files")
                    .disabled(model.isBusy || !model.isBridgeOpSupported("shared-files"))

                    Button {
                        model.reloadSharedFiles()
                    } label: {
                        Label("Reload", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .help("Reload Shared Files")
                    .disabled(model.isBusy || !model.isBridgeOpSupported("shared-files-reload"))
                }
            }
            .sheet(isPresented: editSheetBinding) {
                if let file = editingSharedFile {
                    sharedFileEditSheet(file)
                }
            }
    }

    private var content: some View {
        VStack(spacing: 0) {
            if model.sharedFiles.isEmpty {
                Text("No shared files available.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(18)
            } else {
                List(sharedFileRows(from: model.sharedFiles)) { row in
                    sharedFileRow(row.file)
                        .contextMenu {
                            sharedFileContextMenu(row.file)
                        }
                }
                .listStyle(.inset)
            }
        }
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

    private func sharedFileRow(_ file: BridgeSharedFilePayload) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(file.name)
                .font(.headline)
            Text(file.path)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func sharedFileContextMenu(_ file: BridgeSharedFilePayload) -> some View {
        Menu("Priority") {
            ForEach(sharedFilePriorityItems, id: \.priority) { item in
                Button(item.title) {
                    model.setSharedFilePriority(hash: file.hash, priority: item.priority)
                }
            }
        }
        .disabled(model.isBusy || !model.isBridgeOpSupported("shared-file-priority"))

        Button("Edit Comment and Rating") {
            beginEditing(file)
        }
        .disabled(model.isBusy || !model.isBridgeOpSupported("shared-file-comment-rating"))

        Button("Copy eD2k Link") {
            model.pasteboardShare.writeString(file.ed2kLink)
        }
    }

    private func sharedFileEditSheet(_ file: BridgeSharedFilePayload) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Comment and Rating")
                .font(.headline)

            Text(file.name)
                .font(.subheadline)
                .lineLimit(2)

            TextField("Comment", text: $editComment)

            Picker("Rating", selection: $editRating) {
                ForEach(0...5, id: \.self) { rating in
                    Text("\(rating)").tag(rating)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Spacer()
                Button("Cancel") {
                    editingSharedFile = nil
                }
                Button("Apply") {
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
    }

    private func beginEditing(_ file: BridgeSharedFilePayload) {
        editComment = file.comment ?? ""
        editRating = file.rating ?? 0
        editingSharedFile = file
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
