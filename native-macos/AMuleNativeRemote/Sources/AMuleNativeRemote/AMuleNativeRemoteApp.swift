import SwiftUI
import AppKit

@main
struct AMuleNativeRemoteApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Downloads", id: "downloads-window") {
            ContentView()
                .environmentObject(model)
        }
        .windowStyle(.automatic)

        WindowGroup("Search", id: "search-window") {
            SearchWindowView()
                .environmentObject(model)
        }
        .windowStyle(.hiddenTitleBar)

        WindowGroup("Mock Search", id: "search-mock-window") {
            SearchWindowView(mockMode: true)
                .environmentObject(model)
        }
        .windowStyle(.hiddenTitleBar)

        WindowGroup("eD2k", id: "servers-window") {
            ServersWindowView()
                .environmentObject(model)
        }
        .windowStyle(.automatic)

        Window("", id: "download-details-window") {
            DownloadDetailsWindowView()
                .environmentObject(model)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 820, height: 620)

        WindowGroup("Diagnostics", id: "diagnostics-window") {
            DiagnosticsWindowView()
                .environmentObject(model)
        }
        .windowStyle(.automatic)
        .commands {
            AppMenuCommands(model: model)
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

            Button("Diagnostics") {
                openWindow(id: "diagnostics-window")
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
        }
    }
}
