import SwiftUI

/// A shared download row view suitable for List-based displays on both iOS and macOS.
/// Displays download name, status icon, progress bar, speed, and sources.
public struct DownloadRowContent: View {
    let item: DownloadClassifiable
    let name: String
    let progressText: String
    let speedText: String
    let sourcesText: String
    let progressColors: [UInt32]
    let progressDisplayValue: Double
    let alwaysShowDiagnostic: Bool
    let nameEncodingSuspect: Bool
    let displayedNameEncodingValue: String?
    let usesDiagnosticFallback: Bool

    public init(
        item: DownloadClassifiable,
        name: String,
        progressText: String,
        speedText: String,
        sourcesText: String,
        progressColors: [UInt32],
        progressDisplayValue: Double,
        alwaysShowDiagnostic: Bool = false,
        nameEncodingSuspect: Bool = false,
        displayedNameEncodingValue: String? = nil,
        usesDiagnosticFallback: Bool = false
    ) {
        self.item = item
        self.name = name
        self.progressText = progressText
        self.speedText = speedText
        self.sourcesText = sourcesText
        self.progressColors = progressColors
        self.progressDisplayValue = progressDisplayValue
        self.alwaysShowDiagnostic = alwaysShowDiagnostic
        self.nameEncodingSuspect = nameEncodingSuspect
        self.displayedNameEncodingValue = displayedNameEncodingValue
        self.usesDiagnosticFallback = usesDiagnosticFallback
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: DownloadStatusSymbol.categorySymbolName(for: item))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
                Text(name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if displayedNameEncodingValue != nil {
                    Label(
                        usesDiagnosticFallback
                            ? "Diagnostic filename value available"
                            : (nameEncodingSuspect ? "Suggested filename available" : "Diagnostic filename suggestion available"),
                        systemImage: "wand.and.stars"
                    )
                    .labelStyle(.iconOnly)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(
                        usesDiagnosticFallback || !nameEncodingSuspect
                            ? Color.secondary
                            : Color.orange
                    )
                }
            }

            DownloadSegmentedProgressBar(
                colors: progressColors,
                fallbackProgress: progressDisplayValue / 100.0
            )

            HStack(spacing: 12) {
                Text(progressText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if !speedText.isEmpty && speedText != "-" {
                    Text(speedText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(sourcesText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// A shared footer bar view that displays connection status indicators and speed metrics.
/// Works on both iOS and macOS without platform-specific dependencies.
public struct ConnectionFooterBar: View {
    let serverState: ConnectionState
    let ed2kState: ConnectionState
    let kadState: ConnectionState
    let ed2kStatusText: String
    let downloadSpeed: String
    let uploadSpeed: String
    let onServerTap: () -> Void
    let onEd2kTap: () -> Void
    let onKadTap: () -> Void

    public init(
        serverState: ConnectionState,
        ed2kState: ConnectionState,
        kadState: ConnectionState,
        ed2kStatusText: String,
        downloadSpeed: String,
        uploadSpeed: String,
        onServerTap: @escaping () -> Void,
        onEd2kTap: @escaping () -> Void,
        onKadTap: @escaping () -> Void
    ) {
        self.serverState = serverState
        self.ed2kState = ed2kState
        self.kadState = kadState
        self.ed2kStatusText = ed2kStatusText
        self.downloadSpeed = downloadSpeed
        self.uploadSpeed = uploadSpeed
        self.onServerTap = onServerTap
        self.onEd2kTap = onEd2kTap
        self.onKadTap = onKadTap
    }

    public var body: some View {
        HStack(spacing: 6) {
            StatusTintedContent(state: serverState) {
                Button(action: onServerTap) {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .foregroundStyle(.secondary)
                        Text("aMule Server")
                        ConnectionStateIndicator(state: serverState, showLabel: false)
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
            }

            StatusTintedContent(state: ed2kState) {
                Button(action: onEd2kTap) {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.connected.to.line.below")
                            .foregroundStyle(.secondary)
                        Text(ed2kStatusText)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        ConnectionStateIndicator(state: ed2kState, showLabel: false)
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
            }

            StatusTintedContent(state: kadState) {
                Button(action: onKadTap) {
                    HStack(spacing: 6) {
                        Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                            .foregroundStyle(.secondary)
                        Text("Kad")
                        ConnectionStateIndicator(state: kadState, showLabel: false)
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                MetricChipView(title: NSLocalizedString("Download", comment: ""), value: downloadSpeed)
                MetricChipView(title: NSLocalizedString("Upload", comment: ""), value: uploadSpeed)
            }
            .padding(.trailing, 8)
        }
        .controlSize(.small)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }
}

#if DEBUG
import SharedModels

#Preview("Downloading Row") {
    List {
        DownloadRowContent(
            item: PreviewFixtures.downloadingDownload.asClassifiable,
            name: PreviewFixtures.downloadingDownload.name,
            progressText: "3.0 / 5.0 GB (60%)",
            speedText: "512 KB/s",
            sourcesText: "5/42 (3)",
            progressColors: PreviewFixtures.downloadingDownload.progressColors,
            progressDisplayValue: PreviewFixtures.downloadingDownload.progressValue
        )
    }
}

#Preview("Paused Row") {
    List {
        DownloadRowContent(
            item: PreviewFixtures.pausedDownload.asClassifiable,
            name: PreviewFixtures.pausedDownload.name,
            progressText: "1.0 / 3.0 GB (33%)",
            speedText: "-",
            sourcesText: "0/20",
            progressColors: PreviewFixtures.pausedDownload.progressColors,
            progressDisplayValue: PreviewFixtures.pausedDownload.progressValue
        )
    }
}

#Preview("Completed Row") {
    List {
        DownloadRowContent(
            item: PreviewFixtures.completedDownload.asClassifiable,
            name: PreviewFixtures.completedDownload.name,
            progressText: "1.0 GB (100%)",
            speedText: "",
            sourcesText: "-",
            progressColors: PreviewFixtures.completedDownload.progressColors,
            progressDisplayValue: PreviewFixtures.completedDownload.progressValue
        )
    }
}

#Preview("Row with Suggested Filename") {
    List {
        DownloadRowContent(
            item: PreviewFixtures.suggestedNameDownload.asClassifiable,
            name: PreviewFixtures.suggestedNameDownload.name,
            progressText: "3.0 / 5.0 GB (60%)",
            speedText: "512 KB/s",
            sourcesText: "5/42 (3)",
            progressColors: PreviewFixtures.suggestedNameDownload.progressColors,
            progressDisplayValue: PreviewFixtures.suggestedNameDownload.progressValue,
            nameEncodingSuspect: PreviewFixtures.suggestedNameDownload.nameEncodingSuspect,
            displayedNameEncodingValue: PreviewFixtures.suggestedNameDownload.nameEncodingSuggestion
        )
    }
}
#endif
