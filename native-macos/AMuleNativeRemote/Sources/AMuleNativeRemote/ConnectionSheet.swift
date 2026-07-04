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
        .background(.regularMaterial)
    }
}

struct KadSheet: View {
    @EnvironmentObject private var model: AppModel
    @Binding var isPresented: Bool
    @Binding var nodesURL: String
    @Binding var isRefreshingStatus: Bool

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
                .disabled(model.isBusy || nodesURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(minWidth: 300, idealWidth: 320, maxWidth: 360)
        .background(.regularMaterial)
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

struct MainFooterBar: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @Binding var showLoginSheet: Bool
    @Binding var showKadSheet: Bool

    var body: some View {
        HStack(spacing: 6) {
            footerStatusControl(state: amuleServerFooterConnectionState) {
                Button {
                    showLoginSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .foregroundStyle(.secondary)
                        Text(L("aMule Server"))
                        footerConnectionStateSymbol(amuleServerFooterConnectionState)
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .help("Open Connection Panel")
            }

            footerStatusControl(state: ed2kFooterConnectionState) {
                ControlGroup {
                    Button {
                        openWindow(id: "servers-window")
                        NSApp.activate(ignoringOtherApps: true)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "rectangle.connected.to.line.below")
                                .foregroundStyle(.secondary)
                            switch ed2kFooterConnectionState {
                            case .connected:
                                Text(ed2kFooterPrimaryText)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            case .transitional:
                                Text(ed2kFooterPrimaryText)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                footerConnectionStateSymbol(ed2kFooterConnectionState)
                            case .disconnected, .unknown:
                                Text("eD2k")
                                footerConnectionStateSymbol(ed2kFooterConnectionState)
                            }
                        }
                        .font(.caption)
                        .padding(.leading, 3)
                    }
                    .help("Open eD2k Window")

                    Button {
                        if ed2kFooterConnectionState == .connected {
                            model.connectServer(nil)
                        } else {
                            model.connectServer(bestServerForED2KConnect)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Reconnect")
                    .disabled(model.isBusy)
                }
                .controlGroupStyle(.navigation)
            }

            footerStatusControl(state: kadFooterConnectionState) {
                Button {
                    showKadSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                            .foregroundStyle(.secondary)
                        Text("Kad")
                        footerConnectionStateSymbol(kadFooterConnectionState)
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .help("Open Kad Panel")
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                footerMetricChip(title: L("Download"), value: model.status.downloadSpeed)
                footerMetricChip(title: L("Upload"), value: model.status.uploadSpeed)
            }
            .padding(.trailing, 8)
        }
        .controlSize(.small)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }

    private var amuleServerFooterConnectionState: ConnectionState { model.isSessionConnected ? .connected : .disconnected }
    private var ed2kFooterConnectionState: ConnectionState { connectionState(from: model.status.ed2k) }
    private var kadFooterConnectionState: ConnectionState { connectionState(from: model.status.kad) }
    private var ed2kFooterStatusText: String { compactED2kBadgeValue(model.status.ed2k) }

    private var ed2kFooterPrimaryText: String {
        let compact = ed2kFooterStatusText
        let stateText = compactConnectionState(model.status.ed2k)
        if compact != stateText && compact != "?" && !compact.isEmpty {
            return compact
        }
        return "eD2k"
    }

    private var bestServerForED2KConnect: ServerItem? {
        model.servers
            .filter { !$0.ip.isEmpty && $0.port > 0 }
            .sorted {
                if $0.files != $1.files { return $0.files > $1.files }
                if $0.users != $1.users { return $0.users > $1.users }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            .first
    }

    private func footerMetricChip(title: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
        }
        .font(.caption)
    }

    @ViewBuilder
    private func footerStatusControl<Content: View>(state: ConnectionState, @ViewBuilder content: () -> Content) -> some View {
        if case .disconnected = state {
            content().tint(.red)
        } else {
            content()
        }
    }

    @ViewBuilder
    private func footerConnectionStateSymbol(_ state: ConnectionState) -> some View {
        switch state {
        case .connected:
            Image(systemName: "checkmark.circle")
        case .disconnected:
            Image(systemName: "xmark.circle")
        case .transitional:
            ProgressView().controlSize(.small)
        case .unknown:
            Image(systemName: "questionmark.circle").foregroundStyle(.secondary)
        }
    }
}
