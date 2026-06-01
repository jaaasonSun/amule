import Foundation
import SharedCore

struct ServerManagementService: Sendable {
    let bridge: BridgeProtocol

    func fetchServers(config: AMuleConnectionConfig) async throws -> ([BridgeServerPayload], String) {
        try await bridge.servers(config: config)
    }
}
