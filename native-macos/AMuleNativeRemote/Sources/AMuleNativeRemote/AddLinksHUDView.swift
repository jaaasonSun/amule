import SwiftUI
import SharedModels
import SharedServices

struct AddLinksSheetView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var draft: String
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add eD2k Links")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Paste one link per line (ed2k:// or magnet:? links).")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $draft)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 140)

            HStack(spacing: 8) {
                Button("Clear") {
                    draft = ""
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Close") {
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Button("Start Download") {
                    model.addLinks(draft)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isBusy)
            }
        }
        .padding(16)
        .frame(minWidth: 560, idealWidth: 620, maxWidth: 760, minHeight: 260, idealHeight: 300)
    }
}
