import SwiftUI

private func L2ServerRow(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

struct ServerRowView: View {
    private enum Content {
        case name(ServerItem, Bool)
        case text(String)
        case number(Int)
        case ping(Int)
        case isStatic(Bool)
    }

    private let content: Content

    private init(content: Content) {
        self.content = content
    }

    static func name(item: ServerItem, isConnected: Bool) -> ServerRowView {
        ServerRowView(content: .name(item, isConnected))
    }

    static func text(_ value: String) -> ServerRowView {
        ServerRowView(content: .text(value))
    }

    static func number(_ value: Int) -> ServerRowView {
        ServerRowView(content: .number(value))
    }

    static func ping(_ value: Int) -> ServerRowView {
        ServerRowView(content: .ping(value))
    }

    static func isStatic(_ value: Bool) -> ServerRowView {
        ServerRowView(content: .isStatic(value))
    }

    var body: some View {
        switch content {
        case .name(let item, let isConnected):
            HStack(spacing: 6) {
                if isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .help("Connected Server")
                }
                Text(item.name.isEmpty ? L2ServerRow("(unnamed)") : item.name)
                    .fontWeight(isConnected ? .semibold : .regular)
            }
        case .text(let value):
            Text(value)
        case .number(let value):
            Text(String(value))
        case .ping(let value):
            Text(value > 0 ? "\(value) ms" : "-")
        case .isStatic(let value):
            Text(value ? L2ServerRow("Yes") : L2ServerRow("No"))
        }
    }
}
