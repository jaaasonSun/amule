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

struct StatsWindowView: View {
    @EnvironmentObject private var model: AppModel
    let embeddedInMainWindow: Bool
    @State private var widthInput = "480"
    @State private var scaleInput = "1"

    init(embeddedInMainWindow: Bool = false) {
        self.embeddedInMainWindow = embeddedInMainWindow
    }

    var body: some View {
        content
            .frame(
                minWidth: embeddedInMainWindow ? nil : 780,
                minHeight: embeddedInMainWindow ? nil : 520
            )
            .task {
                model.refreshStatsTree()
                model.refreshStatsGraphs()
            }
    }

    private var content: some View {
        VStack(spacing: 0) {
            statusHeader

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    statsTreeSection

                    statsGraphsSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
        }
    }

    private var statusHeader: some View {
        let summary = NetworkStatusSummary(status: model.status)
        return HStack(spacing: 14) {
            Text("Statistics")
                .font(.headline)

            NetworkStatusChip(title: "eD2k", value: summary.ed2k)
            NetworkStatusChip(title: "Kad", value: summary.kad)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var statsTreeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Stats Tree")
                    .font(.headline)
                Spacer()
                Button {
                    model.refreshStatsTree()
                } label: {
                    Label("Refresh Tree", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy || !model.isBridgeOpSupported("stats-tree"))
            }

            if let tree = model.statsTree {
                VStack(alignment: .leading, spacing: 2) {
                    StatsTreeNodeRow(node: tree)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No statistics tree loaded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statsGraphsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let graphs = model.statsGraphs {
                    Text("Stats Graphs (\(graphs.samples.count) samples)")
                        .font(.headline)
                } else {
                    Text("Stats Graphs")
                        .font(.headline)
                }

                Spacer()

                TextField("Width", text: $widthInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                TextField("Scale", text: $scaleInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)

                Button {
                    let width = Int(widthInput) ?? 480
                    let scale = Int(scaleInput) ?? 1
                    model.refreshStatsGraphs(width: max(1, width), scale: max(1, scale))
                } label: {
                    Label("Refresh Graphs", systemImage: "waveform.path.ecg")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy || !model.isBridgeOpSupported("stats-graphs"))
            }

            if let graphs = model.statsGraphs {
                Text("Last sample marker: \(graphs.last.formatted())")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Grid(alignment: .leading, horizontalSpacing: 22, verticalSpacing: 4) {
                    GridRow {
                        graphHeader("Sample")
                        graphHeader("Download")
                        graphHeader("Upload")
                        graphHeader("Connections")
                        graphHeader("Kad")
                    }

                    Divider()
                        .gridCellColumns(5)

                    ForEach(Array(graphs.samples.enumerated()), id: \.offset) { index, sample in
                        GridRow {
                            Text("#\(index + 1)")
                                .foregroundStyle(.secondary)
                            graphValue(sample.dl)
                            graphValue(sample.ul)
                            graphValue(sample.connections)
                            graphValue(sample.kad)
                        }
                    }
                }
                .font(.system(.caption, design: .monospaced))
            } else {
                Text("No graph samples loaded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func graphHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func graphValue(_ value: Int) -> some View {
        Text(value.formatted())
            .monospacedDigit()
            .frame(minWidth: 64, alignment: .trailing)
    }
}

private struct NetworkStatusChip: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption.weight(.semibold))
            Text(displayValue)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary, in: Capsule())
    }

    private var displayValue: String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "-" : trimmed
    }

    private var dotColor: Color {
        switch connectionState(from: value) {
        case .connected:
            return .green
        case .transitional:
            return .orange
        case .disconnected:
            return .red
        case .unknown:
            return .secondary
        }
    }
}

private struct StatsTreeNodeRow: View {
    let node: BridgeStatsTreeNodePayload
    @State private var isExpanded = true

    var body: some View {
        if node.children.isEmpty {
            rowLabel
                .padding(.leading, 18)
        } else {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
                        StatsTreeNodeRow(node: child)
                    }
                }
                .padding(.leading, 12)
            } label: {
                rowLabel
            }
        }
    }

    private var rowLabel: some View {
        HStack(spacing: 8) {
            Text(node.label)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 12)
            Text(node.value.formatted())
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .font(.system(.caption, design: .monospaced))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
