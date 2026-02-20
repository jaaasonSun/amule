import SwiftUI

@main
struct AMuleNativeRemoteApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh Status") {
                    Task { await model.refreshStatus() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}
