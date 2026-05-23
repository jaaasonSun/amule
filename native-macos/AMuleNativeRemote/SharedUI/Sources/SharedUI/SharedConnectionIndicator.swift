import SwiftUI

/// A shared view that displays a connection state indicator with a colored dot,
/// localized status text, and an animated symbol for transitional states.
///
/// This component works on both iOS and macOS without platform-specific dependencies.
public struct ConnectionStateIndicator: View {
    let state: ConnectionState
    let showLabel: Bool
    let compact: Bool

    public init(state: ConnectionState, showLabel: Bool = true, compact: Bool = false) {
        self.state = state
        self.showLabel = showLabel
        self.compact = compact
    }

    public var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            ConnectionStateDot(state: state)
            if showLabel {
                Text(ConnectionStateLocalizer.localizedText(for: state))
                    .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            connectionSymbol
        }
    }

    @ViewBuilder
    private var connectionSymbol: some View {
        switch state {
        case .connected:
            Image(systemName: ConnectionStateSymbol.symbolName(for: state))
        case .disconnected:
            Image(systemName: ConnectionStateSymbol.symbolName(for: state))
        case .transitional:
            ProgressView()
                .controlSize(.small)
        case .unknown:
            Image(systemName: ConnectionStateSymbol.symbolName(for: state))
                .foregroundStyle(.secondary)
        }
    }
}

/// A shared view that displays a metric chip with a title and value,
/// typically used in footer bars to show download/upload speeds.
///
/// This component works on both iOS and macOS without platform-specific dependencies.
public struct MetricChipView: View {
    let title: String
    let value: String

    public init(title: String, value: String) {
        self.title = title
        self.value = value
    }

    public var body: some View {
        HStack(spacing: 4) {
            Text(title)
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
        }
        .font(.caption)
    }
}

/// A shared view that displays a status-tinted control wrapper.
/// When the state is disconnected, the content is tinted red.
///
/// This component works on both iOS and macOS without platform-specific dependencies.
@available(iOS 16.0, macOS 13.0, *)
public struct StatusTintedContent<Content: View>: View {
    let state: ConnectionState
    @ViewBuilder let content: () -> Content

    public init(state: ConnectionState, @ViewBuilder content: @escaping () -> Content) {
        self.state = state
        self.content = content
    }

    public var body: some View {
        if case .disconnected = state {
            content()
                .tint(.red)
        } else {
            content()
        }
    }
}