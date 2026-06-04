import SwiftUI

public struct ConnectionStateBadge: View {
    let state: ConnectionState

    public init(state: ConnectionState) {
        self.state = state
    }

    public var body: some View {
        Image(systemName: ConnectionStateSymbol.symbolName(for: state))
    }
}

public struct ConnectionStateDot: View {
    let state: ConnectionState

    public init(state: ConnectionState) {
        self.state = state
    }

    public var body: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 8, height: 8)
    }

    private var dotColor: Color {
        switch state {
        case .connected: return .green
        case .disconnected: return .red
        case .transitional: return .orange
        case .unknown: return .secondary
        }
    }
}

public struct ConnectionStateLabel: View {
    let state: ConnectionState

    public init(state: ConnectionState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 6) {
            ConnectionStateDot(state: state)
            Text(ConnectionStateLocalizer.localizedText(for: state))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

public struct DownloadStatusIcon: View {
    let status: String

    public init(status: String) {
        self.status = status
    }

    public var body: some View {
        Image(systemName: DownloadStatusSymbol.symbolName(for: status))
    }
}

#if DEBUG
#Preview("Connection Badges") {
    VStack(spacing: 20) {
        HStack(spacing: 12) {
            ConnectionStateBadge(state: .connected)
            ConnectionStateDot(state: .connected)
            ConnectionStateLabel(state: .connected)
        }
        HStack(spacing: 12) {
            ConnectionStateBadge(state: .disconnected)
            ConnectionStateDot(state: .disconnected)
            ConnectionStateLabel(state: .disconnected)
        }
        HStack(spacing: 12) {
            ConnectionStateBadge(state: .transitional)
            ConnectionStateDot(state: .transitional)
            ConnectionStateLabel(state: .transitional)
        }
    }
    .padding()
}

#Preview("Download Status Icons") {
    VStack(spacing: 16) {
        HStack(spacing: 8) {
            DownloadStatusIcon(status: "Downloading")
            Text("Downloading")
        }
        HStack(spacing: 8) {
            DownloadStatusIcon(status: "Paused")
            Text("Paused")
        }
        HStack(spacing: 8) {
            DownloadStatusIcon(status: "Completed")
            Text("Completed")
        }
        HStack(spacing: 8) {
            DownloadStatusIcon(status: "Error")
            Text("Error")
        }
    }
    .padding()
}
#endif