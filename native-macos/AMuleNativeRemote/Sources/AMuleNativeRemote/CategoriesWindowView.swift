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

struct CategoriesWindowView: View {
    @EnvironmentObject private var model: AppModel
    let embeddedInMainWindow: Bool
    @State private var newCategoryName = ""
    @State private var selectedCategoryID: Int?
    @State private var showingCreateCategorySheet = false
    @State private var editDraft: CategoryEditDraft?

    init(embeddedInMainWindow: Bool = false) {
        self.embeddedInMainWindow = embeddedInMainWindow
    }

    var body: some View {
        content
            .frame(
                minWidth: embeddedInMainWindow ? nil : 700,
                minHeight: embeddedInMainWindow ? nil : 460
            )
            .task { model.refreshCategories() }
            .sheet(isPresented: $showingCreateCategorySheet) {
                CreateCategorySheetView(
                    name: $newCategoryName,
                    isBusy: model.isBusy,
                    canCreate: model.isBridgeOpSupported("category-create")
                ) {
                    model.createCategory(name: newCategoryName, path: "", comment: "", color: 0, priority: 0)
                    newCategoryName = ""
                    showingCreateCategorySheet = false
                }

            }
            .sheet(item: $editDraft) { draft in
                EditCategorySheetView(
                    draft: draft,
                    isBusy: model.isBusy,
                    canUpdate: model.isBridgeOpSupported("category-update")
                ) { updatedDraft in
                    model.updateCategory(
                        id: updatedDraft.id,
                        name: updatedDraft.title,
                        path: updatedDraft.path,
                        comment: updatedDraft.comment,
                        color: updatedDraft.parsedColor ?? 0,
                        priority: updatedDraft.parsedPriority ?? 0
                    )
                    editDraft = nil
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showingCreateCategorySheet = true
                    } label: {
                        Label(L2("Add"), systemImage: "plus")
                    }
                    .help(L2("Create Category"))
                    .disabled(model.isBusy || !model.isBridgeOpSupported("category-create"))

                    Button {
                        model.refreshCategories()
                    } label: {
                        Label(L2("Refresh"), systemImage: "arrow.clockwise")
                    }
                    .help(L2("Refresh Categories"))
                    .disabled(model.isBusy || !model.isSessionConnected || !model.isBridgeOpSupported("categories"))

                    Button {
                        if let selectedCategory {
                            editDraft = CategoryEditDraft(category: selectedCategory)
                        }
                    } label: {
                        Label(L2("Edit"), systemImage: "pencil")
                    }
                    .help(L2("Edit Selected Category"))
                    .disabled(model.isBusy || selectedCategory == nil || !model.isBridgeOpSupported("category-update"))

                    Button {
                        if let selectedCategoryID {
                            model.deleteCategory(id: selectedCategoryID)
                            self.selectedCategoryID = nil
                        }
                    } label: {
                        Label(L2("Delete"), systemImage: "trash")
                    }
                    .help(L2("Delete Selected Category"))
                    .disabled(model.isBusy || selectedCategoryID == nil || !model.isBridgeOpSupported("category-delete"))
                }
            }
            .onChange(of: model.categories) {
                if let selectedCategoryID,
                   !model.categories.contains(where: { $0.id == selectedCategoryID }) {
                    self.selectedCategoryID = nil
                }
            }
    }

    private var content: some View {
        VStack(spacing: 0) {
            if model.categories.isEmpty {
                Text(L2("No categories available."))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(18)
            } else {
                List(model.categories, id: \.id, selection: $selectedCategoryID) { category in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.title.isEmpty ? LF2("Category %lld", Int64(category.id)) : category.title)
                            .font(.headline)
                        Text(LF2("ID: %lld  Priority: %lld", Int64(category.id), Int64(category.priority)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .tag(category.id)
                    .contextMenu {
                        Button(L2("Delete"), role: .destructive) {
                            model.deleteCategory(id: category.id)
                            if selectedCategoryID == category.id {
                                selectedCategoryID = nil
                            }
                        }
                        .disabled(model.isBusy || !model.isBridgeOpSupported("category-delete"))
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private var selectedCategory: BridgeCategoryPayload? {
        guard let selectedCategoryID else { return nil }
        return model.categories.first { $0.id == selectedCategoryID }
    }
}

private struct CategoryEditDraft: Identifiable {
    let id: Int
    var title: String
    var path: String
    var comment: String
    var color: String
    var priority: String

    init(category: BridgeCategoryPayload) {
        id = category.id
        title = category.title
        path = category.path
        comment = category.comment
        color = String(format: "0x%06X", category.color)
        priority = String(category.priority)
    }

    var parsedColor: Int? {
        let trimmed = color.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        let hexPrefixes = ["0x", "#"]
        if let prefix = hexPrefixes.first(where: { trimmed.lowercased().hasPrefix($0) }) {
            return Int(trimmed.dropFirst(prefix.count), radix: 16)
        }

        return Int(trimmed) ?? Int(trimmed, radix: 16)
    }

    var parsedPriority: Int? {
        Int(priority.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && parsedColor != nil && parsedPriority != nil
    }
}

private struct CreateCategorySheetView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var name: String
    let isBusy: Bool
    let canCreate: Bool
    let create: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L2("Create Category"))
                .font(.headline)

            TextField(L2("Name"), text: $name)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button(L2("Cancel")) {
                    name = ""
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(L2("Create")) {
                    create()
                    dismiss()
                }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isBusy || !canCreate || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}

private struct EditCategorySheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CategoryEditDraft

    let isBusy: Bool
    let canUpdate: Bool
    let update: (CategoryEditDraft) -> Void

    init(draft: CategoryEditDraft, isBusy: Bool, canUpdate: Bool, update: @escaping (CategoryEditDraft) -> Void) {
        _draft = State(initialValue: draft)
        self.isBusy = isBusy
        self.canUpdate = canUpdate
        self.update = update
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L2("Edit Category"))
                .font(.headline)

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text(L2("Title"))
                    TextField(L2("Title"), text: $draft.title)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text(L2("Path"))
                    TextField(L2("Path"), text: $draft.path)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text(L2("Comment"))
                    TextField(L2("Comment"), text: $draft.comment)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text(L2("Color"))
                    TextField(L2("Color"), text: $draft.color)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text(L2("Priority"))
                    TextField(L2("Priority"), text: $draft.priority)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Text(L2("Color accepts decimal or hex values such as 0x00AAFF."))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button(L2("Cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(L2("Save")) {
                    update(draft)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isBusy || !canUpdate || !draft.canSave)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
