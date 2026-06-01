import Foundation
import AMuleECBridgeAdapter
import SharedModels
import SharedServices

struct ServerManagementService: Sendable {
    let bridge: BridgeProtocol

    func fetchServers(config: AMuleConnectionConfig) async throws -> ([BridgeServerPayload], String) {
        try await bridge.servers(config: config)
    }
}
