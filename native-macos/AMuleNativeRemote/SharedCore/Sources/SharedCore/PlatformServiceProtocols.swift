import Foundation

public protocol PasteboardShare: Sendable {
    func writeString(_ string: String)
    func readString() -> String?
}

@MainActor
public protocol DeepLinkHandling: AnyObject {
    func enqueueIncomingLink(_ rawInput: String)
    func drainIncomingLinks() -> [String]
    func registerIncomingLinkHandler()
    func unregisterIncomingLinkHandler()
    func handleOpenURL(_ url: URL)
}

extension DeepLinkHandling {
    public func handleOpenURL(_ url: URL) {
        enqueueIncomingLink(url.absoluteString)
    }
}

public protocol CredentialStorage: Sendable {
    func readCredential(forKey key: String) -> String?
    func writeCredential(_ credential: String, forKey key: String)
    func deleteCredential(forKey key: String)
}

public protocol FileExportImport: Sendable {
    func exportData(_ data: Data, to url: URL) throws
    func importData(from url: URL) throws -> Data
}

@MainActor
public protocol LifecycleBackground: AnyObject {
    func activateApplication()
    func bringPrimaryWindowToFront()
    func beginBackgroundActivity(reason: String) -> Any?
    func endBackgroundActivity(_ token: Any?)
}

@MainActor
public protocol LocalNetworkErrorPresentation: AnyObject {
    func userFacingMessage(for error: Error) -> String
}
