import SwiftUI
import AppKit

@main
struct AMuleNativeRemoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("aMule Native Remote", id: "downloads-window") {
            ContentView()
                .environmentObject(model)
        }
        .windowStyle(.automatic)

        WindowGroup("Search", id: "search-window") {
            SearchWindowView()
                .environmentObject(model)
        }
        .windowStyle(.hiddenTitleBar)

        WindowGroup("Servers", id: "servers-window") {
            ServersWindowView()
                .environmentObject(model)
        }
        .windowStyle(.hiddenTitleBar)

        WindowGroup("Diagnostics", id: "diagnostics-window") {
            DiagnosticsWindowView()
                .environmentObject(model)
        }
        .windowStyle(.automatic)

        MenuBarExtra {
            MenuBarStatusMenu(model: model)
        } label: {
            MenuBarStatusLabel(model: model)
        }
        .menuBarExtraStyle(.menu)
        .commands {
            AppMenuCommands(model: model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        DispatchQueue.main.async {
            for window in NSApp.windows where window.isVisible {
                window.orderOut(nil)
            }
        }
    }
}

private struct MenuBarStatusLabel: View {
    @ObservedObject var model: AppModel
    @State private var bootstrapped = false

    var body: some View {
        Image(systemName: model.isSessionConnected ? "link.circle.fill" : "link.circle")
            .foregroundStyle(model.isSessionConnected ? .green : .orange)
            .task {
                guard !bootstrapped else { return }
                bootstrapped = true
                model.ensurePreferredBridgePath()
                model.startAutoRefresh()
                await model.refreshStatus(logOutput: false, suppressErrors: true)
                model.refreshServers()
            }
    }
}

private struct MenuBarStatusMenu: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            Label(
                model.isSessionConnected ? "Connected" : "Disconnected",
                systemImage: model.isSessionConnected ? "link.circle.fill" : "link.circle"
            )

            Divider()

            Text("eD2k: \(model.status.ed2k)")
            Text("Kad: \(model.status.kad)")
            Text("D: \(model.status.downloadSpeed)   U: \(model.status.uploadSpeed)")
            Text("Q: \(model.status.queue)")

            Divider()

            Button("Open Main Window") {
                openWindow(id: "downloads-window")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Open Search Window") {
                openWindow(id: "search-window")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Open Servers Window") {
                openWindow(id: "servers-window")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Open Diagnostics Window") {
                openWindow(id: "diagnostics-window")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Show Add Links Panel") {
                openWindow(id: "downloads-window")
                model.requestAddLinksPanel()
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
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

        ToolbarCommands()

        CommandMenu("Tools") {
            Button("Diagnostics") {
                openWindow(id: "diagnostics-window")
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
        }
    }
}
