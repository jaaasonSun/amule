import SwiftUI
import AppKit
import Carbon.HIToolbox

final class DeepLinkAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        let manager = NSAppleEventManager.shared()
        manager.setEventHandler(
            self,
            andSelector: #selector(handleGetURL(event:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSAppleEventManager.shared().removeEventHandler(
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleGetURL(event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let incomingURL = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else {
            return
        }

        Task { @MainActor in
            PendingIncomingLinkInbox.shared.enqueue(incomingURL)
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}

@main
struct AMuleNativeRemoteApp: App {
    @NSApplicationDelegateAdaptor private var deepLinkDelegate: DeepLinkAppDelegate
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

        WindowGroup("Uploads", id: "uploads-window") {
            UploadsWindowView()
                .environmentObject(model)
        }
        .windowStyle(.automatic)

        WindowGroup("Shared Files", id: "shared-files-window") {
            SharedFilesWindowView()
                .environmentObject(model)
        }
        .windowStyle(.automatic)

        WindowGroup("Categories", id: "categories-window") {
            CategoriesWindowView()
                .environmentObject(model)
        }
        .windowStyle(.automatic)

        WindowGroup("Friends", id: "friends-window") {
            FriendsWindowView()
                .environmentObject(model)
        }
        .windowStyle(.automatic)

        WindowGroup("Statistics", id: "stats-window") {
            StatsWindowView()
                .environmentObject(model)
        }
        .windowStyle(.automatic)

        WindowGroup("Preferences", id: "preferences-window") {
            PreferencesWindowView()
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

            Button("Uploads") {
                openWindow(id: "uploads-window")
            }
            .disabled(!model.isBridgeOpSupported("uploads"))

            Button("Shared Files") {
                openWindow(id: "shared-files-window")
            }
            .disabled(!model.isBridgeOpSupported("shared-files"))

            Button("Categories") {
                openWindow(id: "categories-window")
            }
            .disabled(!model.isBridgeOpSupported("categories"))

            Button("Friends") {
                openWindow(id: "friends-window")
            }
            .disabled(!model.isBridgeOpSupported("friends"))

            Button("Statistics") {
                openWindow(id: "stats-window")
            }
            .disabled(!model.isBridgeOpSupported("stats-tree") && !model.isBridgeOpSupported("stats-graphs"))

            Button("Preferences") {
                openWindow(id: "preferences-window")
            }
            .disabled(!model.isBridgeOpSupported("prefs-connection-get") && !model.isBridgeOpSupported("prefs-connection-set"))
        }
    }
}
