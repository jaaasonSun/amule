import SwiftUI
import AppKit
import SharedModels
import SharedServices

extension Notification.Name {
    static let amulePauseSelectedDownloads = Notification.Name("amule.pauseSelectedDownloads")
    static let amuleResumeSelectedDownloads = Notification.Name("amule.resumeSelectedDownloads")
    static let amuleRemoveSelectedDownloads = Notification.Name("amule.removeSelectedDownloads")
}

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

        Window("Search", id: "search-window") {
            SearchWindowView(embeddedInMainWindow: false)
                .environmentObject(model)
        }
        .windowStyle(.automatic)

        Window("Servers", id: "servers-window") {
            ServersWindowView(embeddedInMainWindow: false)
                .environmentObject(model)
        }
        .windowStyle(.automatic)

        Window("Shared Files", id: "shared-files-window") {
            SharedFilesWindowView(embeddedInMainWindow: false)
                .environmentObject(model)
        }
        .windowStyle(.automatic)

        Window("Statistics", id: "statistics-window") {
            StatsWindowView(embeddedInMainWindow: false)
                .environmentObject(model)
        }
        .windowStyle(.automatic)

        Window("Uploads", id: "uploads-window") {
            UploadsWindowView(embeddedInMainWindow: false)
                .environmentObject(model)
        }
        .windowStyle(.automatic)
        .commandsRemoved()

        Window("Categories", id: "categories-window") {
            CategoriesWindowView(embeddedInMainWindow: false)
                .environmentObject(model)
        }
        .windowStyle(.automatic)
        .commandsRemoved()

        Window("Friends", id: "friends-window") {
            FriendsWindowView(embeddedInMainWindow: false)
                .environmentObject(model)
        }
        .windowStyle(.automatic)
        .commandsRemoved()

        Settings {
            PreferencesWindowView()
                .environmentObject(model)
        }
    }
}

private struct AppMenuCommands: Commands {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @AppStorage("amule.ui.showUploadsPage") private var showUploadsPage = true
    @AppStorage("amule.ui.showCategoriesPage") private var showCategoriesPage = true
    @AppStorage("amule.ui.showFriendsPage") private var showFriendsPage = true

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button(L("Refresh Status")) {
                Task { await model.refreshStatus() }
            }
            .keyboardShortcut("r", modifiers: [.command])

            Button(L("Connection Settings…")) {
                model.requestConnectionSheet()
            }
            .keyboardShortcut("k", modifiers: [.command])
        }

        CommandGroup(replacing: .newItem) {
            Button(L("Add Links…")) {
                openWindow(id: "downloads-window")
                model.requestAddLinksPanel()
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("n", modifiers: [.command])
        }

        CommandMenu(L("Downloads")) {
            Button(L("Show Details")) {
                openWindow(id: "download-details-window")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(model.selectedDownloadID == nil)

            Divider()

            Button(L("Pause Selected Downloads")) {
                NotificationCenter.default.post(name: .amulePauseSelectedDownloads, object: nil)
            }
            .disabled(model.selectedDownloadID == nil || model.isBusy)

            Button(L("Resume Selected Downloads")) {
                NotificationCenter.default.post(name: .amuleResumeSelectedDownloads, object: nil)
            }
            .disabled(model.selectedDownloadID == nil || model.isBusy)

            Button(L("Remove Selected Downloads")) {
                NotificationCenter.default.post(name: .amuleRemoveSelectedDownloads, object: nil)
            }
            .keyboardShortcut(.delete)
            .disabled(model.selectedDownloadID == nil || model.isBusy)
        }

        CommandGroup(after: .windowList) {
            Button(L("Downloads")) {
                openWindow(id: "downloads-window")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("1", modifiers: [.command])

            Button(L("Search Network")) {
                openWindow(id: "search-window")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("2", modifiers: [.command])

            Button(L("Servers")) {
                openWindow(id: "servers-window")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("3", modifiers: [.command])

            Button(L("Shared Files")) {
                openWindow(id: "shared-files-window")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("4", modifiers: [.command])

            Button(L("Statistics")) {
                openWindow(id: "statistics-window")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("5", modifiers: [.command])

            if showUploadsPage {
                Button(L("Uploads")) {
                    openWindow(id: "uploads-window")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }

            if showCategoriesPage {
                Button(L("Categories")) {
                    openWindow(id: "categories-window")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }

            if showFriendsPage {
                Button(L("Friends")) {
                    openWindow(id: "friends-window")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }

            Divider()

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
    }
}
