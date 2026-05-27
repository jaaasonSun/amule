import SwiftUI

struct SearchPanel: View {
    var body: some View {
        SearchWindowView(embeddedInMainWindow: true)
            .transaction { tx in
                tx.animation = nil
                tx.disablesAnimations = true
            }
    }
}
