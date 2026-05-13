#if canImport(UIKit)
import SwiftUI

@main
struct AMuleRemoteiOSApp: App {
    @State private var bridge = IOSFakeBridge()

    var body: some Scene {
        WindowGroup {
            IOSRootView(bridge: bridge)
        }
    }
}
#endif
