import SwiftUI
import AppKit
import SharedViews
import SharedModels
import SharedServices

private func L2(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func LF2(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), locale: .current, arguments: args)
}

struct DiagnosticsWindowView: View {
    @EnvironmentObject private var model: AppModel

    private enum DiagnosticsTab: String, CaseIterable {
        case log = "Log"
        case downloads = "Raw DL"
        case sources = "Raw Src"
        case search = "Raw Search"
        case servers = "Raw Servers"
        case serverInfo = "Server Info"
        case coreLog = "Core Log"
        case coreDebugLog = "Core Debug"

        var localizedTitle: String { L2(rawValue) }
    }

    @State private var diagnosticsTab: DiagnosticsTab = .log

    private var availableTabs: [DiagnosticsTab] {
        var tabs: [DiagnosticsTab] = [.log, .downloads, .sources, .search, .servers]
        if model.isBridgeOpSupported("server-info") {
            tabs.append(.serverInfo)
        }
        if model.isBridgeOpSupported("log") {
            tabs.append(.coreLog)
        }
        if model.isBridgeOpSupported("debug-log") {
            tabs.append(.coreDebugLog)
        }
        return tabs
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Picker("Diagnostics", selection: $diagnosticsTab) {
                        ForEach(availableTabs, id: \.self) { tab in
                            Text(tab.localizedTitle).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 460)

                    Spacer()

                    Button("Copy") {
                        copyCurrentDiagnostics()
                    }
                    .buttonStyle(.bordered)

                    if diagnosticsTab == .log {
                        Button("Clear Log") {
                            model.resetLog()
                        }
                        .buttonStyle(.bordered)
                    }

                    if diagnosticsTab == .coreLog {
                        Button("Refresh") {
                            model.refreshCoreLog()
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.isBusy || !model.isBridgeOpSupported("log"))
                    }

                    if diagnosticsTab == .coreDebugLog {
                        Button("Refresh") {
                            model.refreshCoreDebugLog()
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.isBusy || !model.isBridgeOpSupported("debug-log"))
                    }

                    if diagnosticsTab == .serverInfo {
                        Button("Refresh") {
                            model.refreshServerInfo()
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.isBusy || !model.isBridgeOpSupported("server-info"))
                    }
                }

                ScrollView {
                    Text(currentDiagnosticsText)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(14)
            .padding(.top, proxy.safeAreaInsets.top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(minWidth: 920, minHeight: 520)
        .onAppear {
            if !availableTabs.contains(diagnosticsTab), let first = availableTabs.first {
                diagnosticsTab = first
            }
        }
        .onChange(of: model.bridgeOps) {
            if !availableTabs.contains(diagnosticsTab), let first = availableTabs.first {
                diagnosticsTab = first
            }
        }
    }

    private var currentDiagnosticsText: String {
        switch diagnosticsTab {
        case .log:
            return model.outputLog.isEmpty ? L2("No bridge output yet.") : model.outputLog
        case .downloads:
            return model.lastDownloadsRawOutput.isEmpty ? L2("No raw download queue output captured yet.") : model.lastDownloadsRawOutput
        case .sources:
            return model.lastSourcesRawOutput.isEmpty ? L2("No raw source output captured yet.") : model.lastSourcesRawOutput
        case .search:
            return model.lastSearchRawOutput.isEmpty ? L2("No raw search output captured yet.") : model.lastSearchRawOutput
        case .servers:
            return model.lastServersRawOutput.isEmpty ? L2("No raw server-list output captured yet.") : model.lastServersRawOutput
        case .serverInfo:
            return model.lastServerInfoRawOutput.isEmpty ? L2("No raw server-info output captured yet.") : model.lastServerInfoRawOutput
        case .coreLog:
            return model.coreLogLines.isEmpty ? L2("No core log lines captured yet.") : model.coreLogLines.joined(separator: "\n")
        case .coreDebugLog:
            return model.coreDebugLogLines.isEmpty ? L2("No core debug log lines captured yet.") : model.coreDebugLogLines.joined(separator: "\n")
        }
    }

    private func copyCurrentDiagnostics() {
        switch diagnosticsTab {
        case .log:
            model.copyLogToClipboard()
        case .downloads:
            model.copyDownloadsRawToClipboard()
        case .sources:
            model.copySourcesRawToClipboard()
        case .search:
            model.copySearchRawToClipboard()
        case .servers:
            model.copyServersRawToClipboard()
        case .serverInfo:
            model.pasteboardShare.writeString(model.lastServerInfoRawOutput)
        case .coreLog:
            model.copyCoreLogRawToClipboard()
        case .coreDebugLog:
            model.copyCoreDebugLogRawToClipboard()
        }
    }
}
