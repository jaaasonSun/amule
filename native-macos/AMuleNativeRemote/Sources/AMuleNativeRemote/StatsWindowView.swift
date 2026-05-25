import SwiftUI
import AppKit
#if canImport(SharedUI)
import SharedUI
#endif

private func L2(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func LF2(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), locale: .current, arguments: args)
}

struct StatsWindowView: View {
    @EnvironmentObject private var model: AppModel
    @State private var widthInput = "480"
    @State private var scaleInput = "1"

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    model.refreshStatsTree()
                } label: {
                    Label("Refresh Tree", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy || !model.isBridgeOpSupported("stats-tree"))

                TextField("Width", text: $widthInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                TextField("Scale", text: $scaleInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)

                Button("Refresh Graphs") {
                    let width = Int(widthInput) ?? 480
                    let scale = Int(scaleInput) ?? 1
                    model.refreshStatsGraphs(width: max(1, width), scale: max(1, scale))
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy || !model.isBridgeOpSupported("stats-graphs"))

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let tree = model.statsTree {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Stats Tree")
                                .font(.headline)
                            ForEach(flatten(tree: tree), id: \.self) { line in
                                Text(line)
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }
                    }

                    if let graphs = model.statsGraphs {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Stats Graphs (\(graphs.samples.count) samples)")
                                .font(.headline)
                            Text("Last: \(graphs.last)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(Array(graphs.samples.enumerated()), id: \.offset) { _, sample in
                                Text("dl=\(sample.dl) ul=\(sample.ul) conn=\(sample.connections) kad=\(sample.kad)")
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
        }
        .frame(minWidth: 780, minHeight: 520)
        .background(GlassEffectBackground(material: .underWindowBackground).ignoresSafeArea())
        .background(
            WindowAppearanceConfigurator(
                windowTitle: "Statistics",
                hideTitle: false,
                transparentTitlebar: true,
                fullSizeContentView: true,
                toolbarStyle: .automatic,
                makeWindowTransparent: true,
                ensureToolbarWhenTransparentTitlebar: false
            )
        )
        .task {
            model.refreshStatsTree()
            model.refreshStatsGraphs()
        }
    }

    private func flatten(tree: BridgeStatsTreeNodePayload, depth: Int = 0) -> [String] {
        let indent = String(repeating: "  ", count: depth)
        var lines = ["\(indent)- \(tree.label): \(tree.value)"]
        for child in tree.children {
            lines.append(contentsOf: flatten(tree: child, depth: depth + 1))
        }
        return lines
    }
}
