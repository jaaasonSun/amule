import SwiftUI
import SharedViews
import SharedModels
import SharedServices

private func L2(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func LF2(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), locale: .current, arguments: args)
}

struct AddLinksWindowView: View {
    @EnvironmentObject private var model: AppModel
    @State private var linksDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add eD2k Links")
                .font(.headline)

            Text("Paste one link per line (ed2k:// or magnet:? links).")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $linksDraft)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Button("Clear") {
                    linksDraft = ""
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Start Download") {
                    model.addLinks(linksDraft)
                }
                .buttonStyle(.borderedProminent)
                .disabled(linksDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isBusy)
            }
        }
        .padding(14)
        .frame(minWidth: 520, idealWidth: 560, maxWidth: 700, minHeight: 280, idealHeight: 320)
        .background(
            WindowAppearanceConfigurator(
                windowTitle: "Add Links",
                toolbarStyle: .automatic,
                windowLevel: .floating,
                windowCollectionBehavior: [.fullScreenAuxiliary, .moveToActiveSpace],
                panelHidesOnDeactivate: false,
                useUtilityStyleMask: true,
                isResizable: false
            )
        )
    }
}
