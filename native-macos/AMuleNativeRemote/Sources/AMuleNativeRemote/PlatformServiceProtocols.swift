import Foundation
import SharedUI

protocol BridgeInvocation: Sendable {
    func invokeBridge(
        op: String,
        extraArgs: [String],
        config: AMuleConnectionConfig
    ) async throws -> (envelope: BridgeEnvelope, raw: String)
}

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
    #if os(macOS)
    MacOSPasteboardShare()
    #else
    PlatformServiceStubs.Pasteboard()
    #endif
}

struct PlatformServiceStubs {
    final class Pasteboard: PasteboardShare, @unchecked Sendable {
        private let lock = NSLock()
        private var value: String?

        func writeString(_ string: String) {
            lock.lock()
            value = string
            lock.unlock()
        }

        func readString() -> String? {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
    }

    final class DeepLinks: DeepLinkHandling {
        private var links: [String] = []

        func enqueueIncomingLink(_ rawInput: String) {
            links.append(contentsOf: LinkImportSupport.parseLinks(from: rawInput))
        }

        func drainIncomingLinks() -> [String] {
            let drained = links
            links.removeAll()
            return drained
        }

        func registerIncomingLinkHandler() {}
        func unregisterIncomingLinkHandler() {}
    }

    final class Credentials: CredentialStorage, @unchecked Sendable {
        private let lock = NSLock()
        private var values: [String: String] = [:]

        func readCredential(forKey key: String) -> String? {
            lock.lock()
            defer { lock.unlock() }
            return values[key]
        }

        func writeCredential(_ credential: String, forKey key: String) {
            lock.lock()
            values[key] = credential
            lock.unlock()
        }

        func deleteCredential(forKey key: String) {
            lock.lock()
            values.removeValue(forKey: key)
            lock.unlock()
        }
    }

    struct Files: FileExportImport {
        func exportData(_ data: Data, to url: URL) throws {
            try data.write(to: url, options: .atomic)
        }

        func importData(from url: URL) throws -> Data {
            try Data(contentsOf: url)
        }
    }

    final class Lifecycle: LifecycleBackground {
        private(set) var didActivate = false
        private(set) var didBringPrimaryWindowToFront = false

        func activateApplication() {
            didActivate = true
        }

        func bringPrimaryWindowToFront() {
            didBringPrimaryWindowToFront = true
        }

        func beginBackgroundActivity(reason: String) -> Any? {
            reason
        }

        func endBackgroundActivity(_ token: Any?) {}
    }

    final class LocalNetworkErrors: LocalNetworkErrorPresentation {
        func userFacingMessage(for error: Error) -> String {
            error.localizedDescription
        }
    }
}
