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
    @State private var newCategoryName = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    model.refreshCategories()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy || !model.isBridgeOpSupported("categories"))

                TextField("New category name", text: $newCategoryName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 280)

                Button("Create") {
                    model.createCategory(name: newCategoryName, path: "", comment: "", color: 0, priority: 0)
                    newCategoryName = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy || !model.isBridgeOpSupported("category-create"))

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if model.categories.isEmpty {
                Text("No categories available.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(18)
            } else {
                List(model.categories, id: \.id) { category in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.title.isEmpty ? "Category \(category.id)" : category.title)
                                .font(.headline)
                            Text("ID: \(category.id)  Priority: \(category.priority)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Delete") {
                            model.deleteCategory(id: category.id)
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.isBusy || !model.isBridgeOpSupported("category-delete"))
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 700, minHeight: 460)
        .background(GlassEffectBackground(material: .underWindowBackground).ignoresSafeArea())
        .background(
            WindowAppearanceConfigurator(
                windowTitle: "Categories",
                hideTitle: false,
                transparentTitlebar: true,
                fullSizeContentView: true,
                toolbarStyle: .automatic,
                makeWindowTransparent: true,
                ensureToolbarWhenTransparentTitlebar: false
            )
        )
        .task { model.refreshCategories() }
    }
}
