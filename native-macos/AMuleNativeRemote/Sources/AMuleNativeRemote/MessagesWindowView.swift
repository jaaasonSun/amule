import SwiftUI

struct MessagesWindowView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            Text("Remote chat unavailable")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(18)
        }
        .frame(minWidth: 760, minHeight: 500)
        .disabled(!model.isRemoteMessagesSupported)
    }
}
