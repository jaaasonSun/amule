import SwiftUI
import AppKit

@main
struct AMuleNativeRemoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("aMule Native Remote", id: "downloads-window") {
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

        Window("Download Details", id: "download-details-window") {
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

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installObservers()
        updateDockIconVisibility()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func installObservers() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            NSWindow.didBecomeMainNotification,
            NSWindow.didResignMainNotification,
            NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification,
            NSWindow.willCloseNotification,
            NSApplication.didHideNotification,
            NSApplication.didUnhideNotification
        ]

        for name in names {
            center.addObserver(
                self,
                selector: #selector(handleWindowStateChange(_:)),
                name: name,
                object: nil
            )
        }
    }

    @objc
    private func handleWindowStateChange(_ notification: Notification) {
        updateDockIconVisibility()
    }

    private func updateDockIconVisibility() {
        let shouldShowDock = NSApp.windows.contains(where: shouldShowInDock(window:))
        let targetPolicy: NSApplication.ActivationPolicy = shouldShowDock ? .regular : .accessory
        if NSApp.activationPolicy() != targetPolicy {
            NSApp.setActivationPolicy(targetPolicy)
        }
    }

    private func shouldShowInDock(window: NSWindow) -> Bool {
        guard window.isVisible, !window.isMiniaturized else { return false }
        guard !(window is NSPanel) else { return false }
        return window.styleMask.contains(.titled)
    }
}

@MainActor
private func prepareForWindowPresentation() {
    if NSApp.activationPolicy() != .regular {
        NSApp.setActivationPolicy(.regular)
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
                prepareForWindowPresentation()
                openWindow(id: "downloads-window")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Open Search Window") {
                prepareForWindowPresentation()
                openWindow(id: "search-window")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Open Servers Window") {
                prepareForWindowPresentation()
                openWindow(id: "servers-window")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Open Diagnostics Window") {
                prepareForWindowPresentation()
                openWindow(id: "diagnostics-window")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Show Add Links Panel") {
                prepareForWindowPresentation()
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

        CommandGroup(replacing: .newItem) {
            Button("Add Links…") {
                prepareForWindowPresentation()
                openWindow(id: "downloads-window")
                model.requestAddLinksPanel()
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("n", modifiers: [.command])
        }

        ToolbarCommands()

        CommandMenu("Tools") {
            Button("Show Details") {
                prepareForWindowPresentation()
                openWindow(id: "download-details-window")
            }
            .keyboardShortcut("i", modifiers: [.command])
            .disabled(model.selectedDownloadID == nil)

            Button("Diagnostics") {
                prepareForWindowPresentation()
                openWindow(id: "diagnostics-window")
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
        }
    }
}
