import SwiftUI
import AppKit
import Charts
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
            Text(L2("Statistics"))
                .font(.headline)

            NetworkStatusChip(title: L2("eD2k"), value: summary.ed2k)
            NetworkStatusChip(title: L2("Kad"), value: summary.kad)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var statsTreeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(L2("Stats Tree"))
                    .font(.headline)
                Spacer()
                Button {
                    model.refreshStatsTree()
                } label: {
                    Label(L2("Refresh Tree"), systemImage: "arrow.clockwise")
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
                Text(L2("No statistics tree loaded."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statsGraphsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let graphs = model.statsGraphs {
                    Text(LF2("Stats Graphs (%lld samples)", Int64(graphs.samples.count)))
                        .font(.headline)
                } else {
                    Text(L2("Stats Graphs"))
                        .font(.headline)
                }

                Spacer()

                TextField(L2("Width"), text: $widthInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                TextField(L2("Scale"), text: $scaleInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)

                Button {
                    let width = Int(widthInput) ?? 480
                    let scale = Int(scaleInput) ?? 1
                    model.refreshStatsGraphs(width: max(1, width), scale: max(1, scale))
                } label: {
                    Label(L2("Refresh Graphs"), systemImage: "waveform.path.ecg")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy || !model.isBridgeOpSupported("stats-graphs"))
            }

            if let graphs = model.statsGraphs, !graphs.samples.isEmpty {
                Text(LF2("Last sample marker: %@", graphs.last.formatted()))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                throughputChart(for: graphs)
                    .frame(height: 200)

                connectionsChart(for: graphs)
                    .frame(height: 200)
            } else {
                Text(L2("No graph samples loaded."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func throughputChart(for graphs: BridgeStatsGraphsPayload) -> some View {
        let data = graphs.samples.enumerated().flatMap { index, sample in
            [
                GraphPoint(index: index, value: sample.dl, series: L2("Download")),
                GraphPoint(index: index, value: sample.ul, series: L2("Upload"))
            ]
        }
        return Chart(data) { point in
            LineMark(
                x: .value(L2("Sample"), point.index + 1),
                y: .value(L2("KiB/s"), point.value)
            )
            .foregroundStyle(by: .value(L2("Series"), point.series))
            .interpolationMethod(.monotone)
        }
        .chartLegend(position: .top, alignment: .leading)
        .chartXAxisLabel(L2("Sample"))
        .chartYAxisLabel(L2("KiB/s"))
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let intValue = value.as(Int.self) {
                        Text(intValue.formatted())
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 8)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let intValue = value.as(Int.self) {
                        Text("#\(intValue)")
                    }
                }
            }
        }
    }

    private func connectionsChart(for graphs: BridgeStatsGraphsPayload) -> some View {
        let data = graphs.samples.enumerated().flatMap { index, sample in
            [
                GraphPoint(index: index, value: sample.connections, series: L2("Connections")),
                GraphPoint(index: index, value: sample.kad, series: L2("Kad"))
            ]
        }
        return Chart(data) { point in
            LineMark(
                x: .value(L2("Sample"), point.index + 1),
                y: .value(L2("Count"), point.value)
            )
            .foregroundStyle(by: .value(L2("Series"), point.series))
            .interpolationMethod(.monotone)
        }
        .chartLegend(position: .top, alignment: .leading)
        .chartXAxisLabel(L2("Sample"))
        .chartYAxisLabel(L2("Count"))
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let intValue = value.as(Int.self) {
                        Text(intValue.formatted())
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 8)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let intValue = value.as(Int.self) {
                        Text("#\(intValue)")
                    }
                }
            }
        }
    }
}

private struct GraphPoint: Identifiable {
    let id = UUID()
    let index: Int
    let value: Int
    let series: String
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
                .padding(.leading, 22)
        } else {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
                        StatsTreeNodeRow(node: child)
                    }
                }
                .padding(.leading, 14)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(.quaternary)
                        .frame(width: 1)
                        .padding(.leading, 7)
                }
            } label: {
                rowLabel
            }
        }
    }

    private var rowLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: categoryIconName)
                .foregroundStyle(categoryIconColor)
                .frame(width: 16, alignment: .center)
                .imageScale(.small)

            Text(displayLabel)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            if !valueBadgeText.isEmpty {
                Text(valueBadgeText)
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(valueBadgeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var displayLabel: String {
        let label = node.label
        if label.contains("%s") {
            return String(format: label, node.value.formatted())
        }
        if label.contains("%d") || label.contains("%i") || label.contains("%u") {
            return String(format: label, Int(node.value))
        }
        if label.contains("%f") || label.contains("%g") || label.contains("%e") {
            return String(format: label, node.value)
        }
        return label
    }

    private var valueBadgeText: String {
        let label = node.label
        if label.contains("%s") || label.contains("%d") || label.contains("%i") || label.contains("%u") || label.contains("%f") || label.contains("%g") || label.contains("%e") {
            return ""
        }
        return node.value.formatted()
    }

    private var categoryIconName: String {
        let lower = node.label.lowercased()
        if lower.contains("upload") || lower.contains(" ul") || lower.hasPrefix("ul ") {
            return "arrow.up"
        }
        if lower.contains("download") || lower.contains(" dl") || lower.hasPrefix("dl ") {
            return "arrow.down"
        }
        if lower.contains("session") || lower.contains("time") || lower.contains("uptime") {
            return "clock"
        }
        if lower.contains("client") || lower.contains("user") {
            return "person"
        }
        if lower.contains("file") || lower.contains("part") {
            return "doc"
        }
        if lower.contains("server") {
            return "server.rack"
        }
        return "circle.fill"
    }

    private var categoryIconColor: Color {
        semanticColor
    }

    private var valueBadgeColor: Color {
        semanticColor
    }

    private var semanticColor: Color {
        let lower = node.label.lowercased()
        if lower.contains("b/s") || lower.contains("speed") {
            return .blue
        }
        if lower.contains("upload") || lower.contains(" ul") || lower.hasPrefix("ul ") {
            return .green
        }
        if lower.contains("download") || lower.contains(" dl") || lower.hasPrefix("dl ") {
            return .blue
        }
        if lower.contains("time") || lower.contains("uptime") || lower.contains("session") {
            return .orange
        }
        if lower.contains("client") || lower.contains("user") || lower.contains("count") {
            return .purple
        }
        return .secondary
    }
}
