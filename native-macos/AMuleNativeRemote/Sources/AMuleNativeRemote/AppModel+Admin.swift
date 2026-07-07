import Foundation
import SharedModels
import SharedServices

extension AppModel {
    func shutdownDaemon() {
        guard isBridgeOpSupported("shutdown") else {
            lastError = L3("Shutdown is not supported by the remote bridge.")
            return
        }

        run(label: "shutdown") {
            let (_, raw) = try await self.bridge.shutdown(config: self.config)
            await MainActor.run {
                self.appendLog("$ shutdown\n\(raw)")
                self.isSessionConnected = false
            }
            _ = try? await self.bridge.disconnect(config: self.config)
        }
    }
}
