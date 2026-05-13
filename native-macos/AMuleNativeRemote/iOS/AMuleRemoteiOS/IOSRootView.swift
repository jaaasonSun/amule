#if canImport(UIKit)
import SwiftUI

struct IOSRootView: View {
    let bridge: IOSFakeBridge

    var body: some View {
        NavigationStack {
            List {
                Section("Build Target") {
                    Label("AMuleRemoteiOS", systemImage: "iphone.and.arrow.forward")
                    Text("iOS/iPadOS 26.0 target skeleton")
                        .foregroundStyle(.secondary)
                }

                Section("Bridge") {
                    Label(bridge.capabilities.message, systemImage: "bolt.horizontal.circle")
                    LabeledContent("Schema") {
                        Text("\(bridge.capabilities.schemaVersion)")
                    }
                    LabeledContent("Supported Ops") {
                        Text(bridge.capabilities.ops.joined(separator: ", "))
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("aMule Remote")
        }
    }
}

#Preview {
    IOSRootView(bridge: IOSFakeBridge())
}
#endif
