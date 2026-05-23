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