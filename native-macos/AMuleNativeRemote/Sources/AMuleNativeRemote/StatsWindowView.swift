import SwiftUI
import AppKit
import Charts
import AMuleECBridgeAdapter
#if canImport(SharedViews)
import SharedViews
import SharedModels
import SharedServices
#endif

func statsLabelByReplacingValuePlaceholders(_ label: String, value: Double) -> String {
    var result = ""
    var cursor = label.startIndex
    while let percent = label[cursor...].firstIndex(of: "%") {
        result.append(contentsOf: label[cursor..<percent])
        let afterPercent = label.index(after: percent)
        guard afterPercent < label.endIndex else {
            result.append("%")
            cursor = afterPercent
            break
        }
        if label[afterPercent] == "%" {
            result.append("%")
            cursor = label.index(after: afterPercent)
            continue
        }
        guard let specifier = statsFormatSpecifierRange(in: label, startingAt: afterPercent) else {
            result.append("%")
            cursor = afterPercent
            continue
        }
        result.append(statsFormattedValue(value, specifier: label[specifier.upperBound]))
        cursor = label.index(after: specifier.upperBound)
    }
    result.append(contentsOf: label[cursor...])
    return result
}

func statsLabelContainsValuePlaceholder(_ label: String) -> Bool {
    var cursor = label.startIndex
    while let percent = label[cursor...].firstIndex(of: "%") {
        let afterPercent = label.index(after: percent)
        guard afterPercent < label.endIndex else { return false }
        if label[afterPercent] == "%" {
            cursor = label.index(after: afterPercent)
            continue
        }
        if statsFormatSpecifierRange(in: label, startingAt: afterPercent) != nil {
            return true
        }
        cursor = afterPercent
    }
    return false
}

func statsGraphRateInKilobytesPerSecond(_ bytesPerSecond: Int) -> Double {
    Double(bytesPerSecond) / 1024.0
}

func statsGraphLegendLabel(_ series: String, unit: String) -> String {
    "\(series) (\(unit))"
}

private func statsFormatSpecifierRange(in label: String, startingAt start: String.Index) -> ClosedRange<String.Index>? {
    let specifiers = Set("diuoxXfFeEgGaAcCsSp@")
    let allowedBeforeSpecifier = Set("-+#0123456789.hlLqztj")
    var cursor = start
    while cursor < label.endIndex {
        if specifiers.contains(label[cursor]) {
            return start...cursor
        }
        if !allowedBeforeSpecifier.contains(label[cursor]) {
            return nil
        }
        cursor = label.index(after: cursor)
    }
    return nil
}

private func statsFormattedValue(_ value: Double, specifier: Character) -> String {
    switch specifier {
    case "d", "i", "u", "o", "x", "X":
        return Int(value).formatted()
    default:
        return value.formatted()
    }
}

struct StatsWindowView: View {
    @EnvironmentObject private var model: AppModel
    let embeddedInMainWindow: Bool

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
                refreshStatistics()
            }
    }

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    StatsOverviewGrid(status: model.status, graphs: model.statsGraphs)

                    statsGraphsSection

                    statsTreeSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    refreshStatistics()
                } label: {
                    Label(L("Refresh"), systemImage: "arrow.clockwise")
                }
                .help(L("Refresh Statistics"))
                .disabled(model.isBusy || (!model.isBridgeOpSupported("stats-tree") && !model.isBridgeOpSupported("stats-graphs")))
            }
        }
    }

    private func refreshStatistics() {
        if model.isBridgeOpSupported("stats-tree") {
            model.refreshStatsTree()
        }
        if model.isBridgeOpSupported("stats-graphs") {
            model.refreshStatsGraphs()
        }
    }

    private var statsTreeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Stats Tree"))
                .font(.headline)

            if let tree = model.statsTree {
                VStack(alignment: .leading, spacing: 2) {
                    StatsTreeNodeRow(node: tree)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(L("No statistics tree loaded."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statsGraphsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let graphs = model.statsGraphs {
                Text(LF("Stats Graphs (%lld samples)", Int64(graphs.samples.count)))
                    .font(.headline)
            } else {
                Text(L("Stats Graphs"))
                    .font(.headline)
            }

            if let graphs = model.statsGraphs, !graphs.samples.isEmpty {
                Text(LF("Last sample marker: %@", graphs.last.formatted()))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                throughputChart(for: graphs)
                    .frame(height: 200)

                connectionsChart(for: graphs)
                    .frame(height: 200)
            } else {
                Text(L("No graph samples loaded."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func throughputChart(for graphs: BridgeStatsGraphsPayload) -> some View {
        let unit = L("KB/s")
        let data = graphs.samples.enumerated().flatMap { index, sample in
            [
                ThroughputGraphPoint(
                    index: index,
                    value: statsGraphRateInKilobytesPerSecond(sample.dl),
                    series: statsGraphLegendLabel(L("Download"), unit: unit)
                ),
                ThroughputGraphPoint(
                    index: index,
                    value: statsGraphRateInKilobytesPerSecond(sample.ul),
                    series: statsGraphLegendLabel(L("Upload"), unit: unit)
                )
            ]
        }
        return Chart(data) { point in
            LineMark(
                x: .value(L("Sample"), point.index + 1),
                y: .value(unit, point.value)
            )
            .foregroundStyle(by: .value(L("Series"), point.series))
            .interpolationMethod(.monotone)
        }
        .chartLegend(position: .top, alignment: .leading)
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color(nsColor: .textBackgroundColor))
        }
        .chartXAxisLabel(L("Sample"))
        .chartYAxisLabel(unit)
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let rate = value.as(Double.self) {
                        Text(rate.formatted(.number.precision(.fractionLength(0...1))))
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
                GraphPoint(index: index, value: sample.connections, series: L("Connections")),
                GraphPoint(index: index, value: sample.kad, series: L("Kad"))
            ]
        }
        return Chart(data) { point in
            LineMark(
                x: .value(L("Sample"), point.index + 1),
                y: .value(L("Count"), point.value)
            )
            .foregroundStyle(by: .value(L("Series"), point.series))
            .interpolationMethod(.monotone)
        }
        .chartLegend(position: .top, alignment: .leading)
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color(nsColor: .textBackgroundColor))
        }
        .chartXAxisLabel(L("Sample"))
        .chartYAxisLabel(L("Count"))
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

private struct ThroughputGraphPoint: Identifiable {
    let id = UUID()
    let index: Int
    let value: Double
    let series: String
}

private struct GraphPoint: Identifiable {
    let id = UUID()
    let index: Int
    let value: Int
    let series: String
}

private struct StatsOverviewGrid: View {
    let status: StatusSnapshot
    let graphs: BridgeStatsGraphsPayload?

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], alignment: .leading, spacing: 10) {
            StatsOverviewTile(title: L("Download"), value: status.downloadSpeed, systemImage: "arrow.down", color: .blue)
            StatsOverviewTile(title: L("Upload"), value: status.uploadSpeed, systemImage: "arrow.up", color: .green)
            StatsOverviewTile(title: L("Queue"), value: status.queue, systemImage: "person.3.sequence", color: .purple)
            StatsOverviewTile(title: L("Samples"), value: sampleCountText, systemImage: "chart.xyaxis.line", color: .orange)
        }
    }

    private var sampleCountText: String {
        guard let graphs else { return "-" }
        return graphs.samples.count.formatted()
    }
}

private struct StatsOverviewTile: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundStyle(color)
                    .frame(width: 16)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "-" : value)
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
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
        return statsLabelByReplacingValuePlaceholders(label, value: node.value)
    }

    private var valueBadgeText: String {
        let label = node.label
        if statsLabelContainsValuePlaceholder(label) {
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
