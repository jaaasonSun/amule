import Foundation
import SharedUI

protocol PasteboardShare: Sendable {
    func writeString(_ string: String)
    func readString() -> String?
}

@MainActor
protocol DeepLinkHandling: AnyObject {
    func enqueueIncomingLink(_ rawInput: String)
    func drainIncomingLinks() -> [String]
    func registerIncomingLinkHandler()
    func unregisterIncomingLinkHandler()
}

protocol CredentialStorage: Sendable {
    func readCredential(forKey key: String) -> String?
    func writeCredential(_ credential: String, forKey key: String)
    func deleteCredential(forKey key: String)
}

protocol FileExportImport: Sendable {
    func exportData(_ data: Data, to url: URL) throws
    func importData(from url: URL) throws -> Data
}

@MainActor
protocol LifecycleBackground: AnyObject {
    func activateApplication()
    func bringPrimaryWindowToFront()
    func beginBackgroundActivity(reason: String) -> Any?
    func endBackgroundActivity(_ token: Any?)
}

@MainActor
protocol LocalNetworkErrorPresentation: AnyObject {
    func userFacingMessage(for error: Error) -> String
}

func platformDefaultPasteboardShare() -> PasteboardShare {
    MacOSPasteboardShare()
}
