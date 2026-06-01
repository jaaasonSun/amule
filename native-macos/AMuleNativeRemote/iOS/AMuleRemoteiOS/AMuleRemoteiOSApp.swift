#if canImport(UIKit)
import SwiftUI

@main
struct AMuleRemoteiOSApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(model: IOSAppModel())
        }
    }
}
#endif
