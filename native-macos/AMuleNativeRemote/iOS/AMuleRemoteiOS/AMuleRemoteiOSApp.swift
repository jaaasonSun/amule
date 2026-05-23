#if canImport(UIKit)
import SwiftUI
import AMuleRemoteIOSShared

@main
struct AMuleRemoteiOSApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(model: IOSAppModel())
        }
    }
}
#endif
