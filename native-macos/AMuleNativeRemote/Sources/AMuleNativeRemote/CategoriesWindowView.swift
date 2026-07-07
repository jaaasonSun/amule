import SwiftUI
import AppKit
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
                .presentationDetents([.height(180)])
                .presentationDragIndicator(.hidden)
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showingCreateCategorySheet = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .help("Create Category")
                    .disabled(model.isBusy || !model.isBridgeOpSupported("category-create"))

                    Button {
                        model.refreshCategories()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .help("Refresh Categories")
                    .disabled(model.isBusy || !model.isBridgeOpSupported("categories"))

                    Button {
                        if let selectedCategoryID {
                            model.deleteCategory(id: selectedCategoryID)
                            self.selectedCategoryID = nil
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .help("Delete Selected Category")
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
                Text("No categories available.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(18)
            } else {
                List(model.categories, id: \.id, selection: $selectedCategoryID) { category in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.title.isEmpty ? "Category \(category.id)" : category.title)
                            .font(.headline)
                        Text("ID: \(category.id)  Priority: \(category.priority)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .tag(category.id)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
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
}

private struct CreateCategorySheetView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var name: String
    let isBusy: Bool
    let canCreate: Bool
    let create: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Create Category")
                .font(.headline)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel") {
                    name = ""
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
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
