import SwiftUI

/// A reusable empty state view with an icon, title, and optional subtitle.
/// Works on both iOS and macOS without platform-specific dependencies.
public struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String?

    public init(icon: String, title: String, subtitle: String? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding()
    }
}

/// A shared HUD overlay view that displays a success message with a checkmark.
/// Works on both iOS and macOS without platform-specific dependencies.
public struct AddLinksHUD: View {
    let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(message)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 3)
        }
        .padding(.top, 18)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#if DEBUG
#Preview("Empty State") {
    EmptyStateView(
        icon: "tray",
        title: "No Downloads",
        subtitle: "Downloads will appear here when you start downloading files."
    )
}

#Preview("Add Links HUD") {
    AddLinksHUD(message: "Link added to download queue")
}
#endif