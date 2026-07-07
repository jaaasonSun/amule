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
        .defaultSize(
            width: DownloadsWindowPersistence.defaultWidth,
            height: DownloadsWindowPersistence.defaultHeight
        )
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

        WindowGroup("Diagnostics", id: "diagnostics-window") {
            DiagnosticsWindowView()
                .environmentObject(model)
        }
        .windowStyle(.automatic)

        WindowGroup("Server Logs", id: "server-logs-window") {
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
    @AppStorage("amule.ui.alwaysShowSuggestedFilename") private var alwaysShowSuggestedFilename = false

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Refresh Status") {
                Task { await model.refreshStatus() }
            }
            .keyboardShortcut("r", modifiers: [.command])
        }

        CommandGroup(replacing: .newItem) {
            Button("Add Links…") {
                openWindow(id: "downloads-window")
                model.requestAddLinksPanel()
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("n", modifiers: [.command])
        }

        ToolbarCommands()

        CommandMenu("Tools") {
            Button("Show Details") {
                openWindow(id: "download-details-window")
            }
            .keyboardShortcut("i", modifiers: [.command])
            .disabled(model.selectedDownloadID == nil)

            Toggle("Always Show Suggested Filename", isOn: $alwaysShowSuggestedFilename)

            Button("Diagnostics") {
                openWindow(id: "diagnostics-window")
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])

            Button("Server Logs") {
                openWindow(id: "server-logs-window")
            }
            .disabled(!model.isBridgeOpSupported("server-info"))

        }
    }
}
