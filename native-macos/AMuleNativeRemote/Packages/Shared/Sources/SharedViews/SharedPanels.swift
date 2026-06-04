import SwiftUI

/// Shared content for the link import panel (Add eD2k Links).
/// This is the pure SwiftUI form content without platform-specific chrome.
/// macOS wraps this in GlassEffectBackground; iOS wraps in a sheet.
public struct LinkImportPanelContent: View {
    @Binding var draft: String
    let isBusy: Bool
    let onImport: () -> Void
    let onClear: () -> Void

    public init(draft: Binding<String>, isBusy: Bool, onImport: @escaping () -> Void, onClear: @escaping () -> Void) {
        self._draft = draft
        self.isBusy = isBusy
        self.onImport = onImport
        self.onClear = onClear
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add eD2k Links")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Paste one link per line (ed2k:// or magnet:? links).")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $draft)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 140)

            HStack(spacing: 8) {
                Button("Clear", action: onClear)
                    .buttonStyle(.bordered)

                Spacer()

                Button("Start Download", action: onImport)
                    .buttonStyle(.borderedProminent)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isBusy)
            }
        }
    }
}

/// Shared content for the connection/login panel.
/// This is the pure SwiftUI form content without platform-specific chrome.
/// macOS wraps this in GlassEffectBackground; iOS wraps in a sheet.
public struct ConnectionPanelContent: View {
    @Binding var host: String
    @Binding var port: Int
    @Binding var password: String
    let isConnected: Bool
    let isBusy: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    let onClose: () -> Void

    private static let portFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.usesGroupingSeparator = false
        formatter.allowsFloats = false
        return formatter
    }()

    public init(
        host: Binding<String>,
        port: Binding<Int>,
        password: Binding<String>,
        isConnected: Bool,
        isBusy: Bool,
        onConnect: @escaping () -> Void,
        onDisconnect: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self._host = host
        self._port = port
        self._password = password
        self.isConnected = isConnected
        self.isBusy = isBusy
        self.onConnect = onConnect
        self.onDisconnect = onDisconnect
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 14) {
            Text("Connect To aMule Server")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Circle()
                    .fill(isConnected ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(isConnected ? NSLocalizedString("Connected", comment: "") : NSLocalizedString("Disconnected", comment: ""))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 10) {
                TextField("Host", text: $host)
                    .textFieldStyle(.roundedBorder)
                TextField("Port", value: $port, formatter: Self.portFormatter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
            }

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            HStack {
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
                Button("Close", action: onClose)
                    .buttonStyle(.bordered)
                if isConnected {
                    Button("Disconnect", action: onDisconnect)
                        .buttonStyle(.bordered)
                        .disabled(isBusy)
                }
                Button(isConnected ? NSLocalizedString("Reconnect", comment: "") : NSLocalizedString("Connect", comment: ""), action: onConnect)
                    .buttonStyle(.borderedProminent)
                    .disabled(isBusy)
            }
        }
    }
}

/// Shared content for the Kad panel.
/// This is the pure SwiftUI form content without platform-specific chrome.
/// macOS wraps this in GlassEffectBackground; iOS wraps in a sheet.
public struct KadPanelContent: View {
    @Binding var nodesURL: String
    let kadStatusText: String
    let kadConnectionState: ConnectionState
    let isRefreshing: Bool
    let isBusy: Bool
    let onRefresh: () -> Void
    let onUpdateNodes: () -> Void
    let onClose: () -> Void

    public init(
        nodesURL: Binding<String>,
        kadStatusText: String,
        kadConnectionState: ConnectionState,
        isRefreshing: Bool,
        isBusy: Bool,
        onRefresh: @escaping () -> Void,
        onUpdateNodes: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self._nodesURL = nodesURL
        self.kadStatusText = kadStatusText
        self.kadConnectionState = kadConnectionState
        self.isRefreshing = isRefreshing
        self.isBusy = isBusy
        self.onRefresh = onRefresh
        self.onUpdateNodes = onUpdateNodes
        self.onClose = onClose
    }

    private var statusDotColor: Color {
        switch kadConnectionState {
        case .connected: return .green
        case .transitional: return .orange
        case .disconnected: return .orange
        case .unknown: return .secondary
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Kad")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 8, height: 8)
                    Text(kadStatusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Button {
                        onRefresh()
                    } label: {
                        Group {
                            if isRefreshing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Refresh")
                    .disabled(isBusy || isRefreshing)
                    Spacer()
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Update nodes.dat from URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("http://example.com/nodes.dat", text: $nodesURL)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isBusy)
            }

            HStack(spacing: 8) {
                Spacer()
                Button("Close", action: onClose)
                    .buttonStyle(.bordered)

                Button("Download nodes.dat", action: onUpdateNodes)
                    .buttonStyle(.borderedProminent)
                    .disabled(isBusy || nodesURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

#if DEBUG
#Preview("Connection Panel - Connected") {
    ConnectionPanelContent(
        host: .constant("localhost"),
        port: .constant(4712),
        password: .constant("••••••••"),
        isConnected: true,
        isBusy: false,
        onConnect: {},
        onDisconnect: {},
        onClose: {}
    )
    .padding()
    .frame(width: 350)
}

#Preview("Connection Panel - Disconnected") {
    ConnectionPanelContent(
        host: .constant("localhost"),
        port: .constant(4712),
        password: .constant(""),
        isConnected: false,
        isBusy: false,
        onConnect: {},
        onDisconnect: {},
        onClose: {}
    )
    .padding()
    .frame(width: 350)
}

#Preview("Connection Panel - Busy") {
    ConnectionPanelContent(
        host: .constant("192.168.1.100"),
        port: .constant(4712),
        password: .constant("••••••••"),
        isConnected: false,
        isBusy: true,
        onConnect: {},
        onDisconnect: {},
        onClose: {}
    )
    .padding()
    .frame(width: 350)
}
#endif
