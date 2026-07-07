import SwiftUI
import AppKit
import SharedModels
import SharedServices

enum ConnectionState {
    case connected
    case disconnected
    case transitional
    case unknown
}

func connectionState(from value: String) -> ConnectionState {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty || trimmed == "-" {
        return .unknown
    }

    let lower = trimmed.lowercased()
    let disconnectedTokens = [
        "disconnected", "not connected", "offline", "stopped", "off",
        "断开", "未连接", "離線", "离线", "未連線"
    ]
    if disconnectedTokens.contains(where: { lower.contains($0) }) {
        return .disconnected
    }

    let transitionalTokens = [
        "connecting", "starting", "initializing", "pending", "run", "running",
        "连接中", "正在连接", "連線中", "初始化"
    ]
    if transitionalTokens.contains(where: { lower.contains($0) }) {
        return .transitional
    }

    let connectedTokens = [
        "connected", "lowid", "highid", "firewalled", "on",
        "已连接", "已連線", "连接", "連線"
    ]
    if connectedTokens.contains(where: { lower.contains($0) }) {
        return .connected
    }

    if lower.contains("unknown") || lower.contains("未知") {
        return .unknown
    }

    return .unknown
}

func compactConnectionState(_ value: String) -> String {
    switch connectionState(from: value) {
    case .connected:
        return L("On")
    case .disconnected:
        return L("Off")
    case .transitional:
        return L("Run")
    case .unknown:
        return "?"
    }
}

func localizedConnectionStatusText(for value: String) -> String {
    switch connectionState(from: value) {
    case .connected:
        return L("Connected")
    case .disconnected:
        return L("Disconnected")
    case .transitional:
        return L("Connecting")
    case .unknown:
        return L("Unknown")
    }
}

func compactED2kBadgeValue(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let prefixes = ["Connected to ", "Connecting to "]
    guard let prefix = prefixes.first(where: { trimmed.hasPrefix($0) }) else {
        return compactConnectionState(value)
    }

    var rest = String(trimmed.dropFirst(prefix.count))
    if rest.hasSuffix(" LowID") {
        rest.removeLast(6)
    } else if rest.hasSuffix(" HighID") {
        rest.removeLast(7)
    }
    rest = rest.trimmingCharacters(in: .whitespacesAndNewlines)

    if let endpointRange = rest.range(
        of: #"\s+\[?[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(?::[0-9]+)?\]?$"#,
        options: .regularExpression
    ) {
        let name = String(rest[..<endpointRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            return name
        }
    }

    return rest.isEmpty ? compactConnectionState(value) : rest
}

struct NetworkStatusSummary: Equatable {
    let ed2k: String
    let kad: String

    init(ed2k: String, kad: String) {
        self.ed2k = ed2k
        self.kad = kad
    }

    init(status: StatusSnapshot) {
        self.init(ed2k: status.ed2k, kad: status.kad)
    }
}

@ViewBuilder
private func connectionStateBadge(label: String, isOn: Bool, isConnecting: Bool = false, isFirewalled: Bool = false) -> some View {
    HStack(spacing: 4) {
        Circle()
            .fill(isOn ? Color.green : (isConnecting ? Color.orange : Color.secondary))
            .frame(width: 6, height: 6)
        Text(label)
            .font(.caption2)
        if isFirewalled {
            Image(systemName: "flame.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
        }
    }
}

struct ConnectionSheet: View {
    @EnvironmentObject private var model: AppModel
    @Binding var isPresented: Bool

    private static let plainPortFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.usesGroupingSeparator = false
        formatter.allowsFloats = false
        return formatter
    }()

    var body: some View {
        VStack(spacing: 14) {
            Text("Connect To aMule Server")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Circle()
                    .fill(model.isSessionConnected ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(model.isSessionConnected ? L("Connected") : L("Disconnected"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 10) {
                TextField("Host", text: $model.host)
                    .textFieldStyle(.roundedBorder)
                TextField("Port", value: $model.port, formatter: Self.plainPortFormatter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
            }

            SecureField("Password", text: $model.password)
                .textFieldStyle(.roundedBorder)

            if model.isBridgeOpSupported("connection-state"), let state = model.connectionState {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connection State")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        connectionStateBadge(label: "ED2K", isOn: state.ed2kConnected, isConnecting: state.ed2kConnecting)
                        connectionStateBadge(label: "Kad", isOn: state.kadConnected, isFirewalled: state.kadFirewalled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                if model.isBusy {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
                Button("Close") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                if model.isSessionConnected {
                    Button("Disconnect") {
                        model.disconnectAll()
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isBusy)
                }
                Button(model.isSessionConnected ? L("Reconnect") : L("Connect")) {
                    model.connectAll()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy)
            }
        }
        .padding(16)
        .frame(minWidth: 300, idealWidth: 320, maxWidth: 360, minHeight: 188)
    }
}

struct KadSheet: View {
    @EnvironmentObject private var model: AppModel
    @Binding var isPresented: Bool
    @Binding var nodesURL: String
    @Binding var isRefreshingStatus: Bool
    @State private var bootstrapIP = ""
    @State private var bootstrapPort = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Kad")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 8, height: 8)
                    Text(localizedConnectionStatusText(for: model.status.kad))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Button {
                        guard !isRefreshingStatus else { return }
                        isRefreshingStatus = true
                        Task {
                            await model.refreshStatus(logOutput: false, suppressErrors: true)
                            await MainActor.run {
                                isRefreshingStatus = false
                            }
                        }
                    } label: {
                        Group {
                            if isRefreshingStatus {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .controlSize(.small)
                    .help("Refresh")
                    .disabled(model.isBusy || isRefreshingStatus)
                    Spacer()
                }
            }

            HStack(spacing: 8) {
                Button {
                    model.startKad()
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy || !model.isBridgeOpSupported("kad-start"))

                Button {
                    model.stopKad()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy || !model.isBridgeOpSupported("kad-stop"))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Bootstrap from node")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    TextField("IP address", text: $bootstrapIP)
                        .textFieldStyle(.roundedBorder)
                    TextField("Port", text: $bootstrapPort)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 84)
                    Button("Bootstrap") {
                        model.bootstrapKad(ip: bootstrapIP, port: bootstrapPort)
                    }
                    .buttonStyle(.bordered)
                    .disabled(
                        model.isBusy
                        || !model.isBridgeOpSupported("kad-bootstrap")
                        || bootstrapIP.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || bootstrapPort.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Update nodes.dat from URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("http://example.com/nodes.dat", text: $nodesURL)
                    .textFieldStyle(.roundedBorder)
                    .disabled(model.isBusy)
            }

            HStack(spacing: 8) {
                Spacer()
                Button("Close") {
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Button("Download nodes.dat") {
                    model.updateKadNodesFromURL(nodesURL)
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    model.isBusy
                    || !model.isBridgeOpSupported("kad-update-from-url")
                    || nodesURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
        .padding(16)
        .frame(minWidth: 420, idealWidth: 460, maxWidth: 520)
    }

    private var statusDotColor: Color {
        switch connectionState(from: model.status.kad) {
        case .connected:
            return .green
        case .transitional:
            return .orange
        case .disconnected:
            return .orange
        case .unknown:
            return .secondary
        }
    }
}
