import Foundation
import AMuleECBridgeAdapter

enum BridgeAdapterFactory {
    static func makeBridgeAdapter() -> AMuleECBridgeAdapter.BridgeProtocol {
        SwiftECBridgeAdapter()
    }
}

func platformDefaultBridgeAdapter() -> AMuleECBridgeAdapter.BridgeProtocol {
    BridgeAdapterFactory.makeBridgeAdapter()
}
