import SwiftUI
import AppKit
import SharedModels
import SharedServices

@main
struct AMuleNativeRemoteApp: App {
    @NSApplicationDelegateAdaptor private var deepLinkDelegate: MacOSDeepLinkHandler
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Downloads", id: "downloads-window") {
            ContentView()
                .environmentObject(model)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1040, height: 620)
        .commands {
            AppMenuCommands(model: model)
        }

        Window("Details", id: "download-details-window") {
            DownloadDetailsWindowView()
                .environmentObject(model)
        }
        .windowStyle(.automatic)
        .windowResizability(.contentSize)
        .defaultSize(width: 820, height: 620)

        Window("Diagnostics", id: "diagnostics-window") {
            DiagnosticsWindowView()
                .environmentObject(model)
        }
        .windowStyle(.automatic)

        Window("Server Logs", id: "server-logs-window") {
            ServerLogsWindowView()
                .environmentObject(model)
        }
        .windowStyle(.automatic)

        Settings {
            PreferencesWindowView()
                .environmentObject(model)
        }
    }
}

private struct AppMenuCommands: Commands {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Refresh Status") {
                Task { await model.refreshStatus() }
            }
            .keyboardShortcut("r", modifiers: [.command])

            Button("Connection Settings…") {
                model.requestConnectionSheet()
            }
            .keyboardShortcut("k", modifiers: [.command])
        }

        CommandGroup(replacing: .newItem) {
            Button("Add Links…") {
                openWindow(id: "downloads-window")
                model.requestAddLinksPanel()
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("n", modifiers: [.command])
        }

        CommandGroup(after: .windowList) {
            Button("Diagnostics") {
                openWindow(id: "diagnostics-window")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("d", modifiers: [.command, .option])
            .disabled(!model.isBridgeOpSupported("log") && !model.isBridgeOpSupported("debug-log") && !model.isBridgeOpSupported("server-info"))

            Button("Server Logs") {
                openWindow(id: "server-logs-window")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("l", modifiers: [.command, .option])
            .disabled(!model.isBridgeOpSupported("server-info"))
        }

        ToolbarCommands()
        SidebarCommands()
    }
}
