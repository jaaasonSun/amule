import Foundation
import SharedUI
import SwiftUI

public protocol BridgeInvocation: Sendable {
    func invokeBridge(
        op: String,
        extraArgs: [String],
        config: AMuleConnectionConfig
    ) async throws -> (envelope: BridgeEnvelope, raw: String)
}

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

@MainActor
public protocol AppLifecycleProtocol: AnyObject {
    var isNetworkReachable: Bool { get }
    func start()
    func stop()
    func handleScenePhaseChange(_ phase: ScenePhase, isSessionConnected: Bool) -> AppLifecycleEffect
}

public func platformDefaultPasteboardShare() -> PasteboardShare {
    #if canImport(UIKit)
    IOSPasteboardShare()
    #else
    PlatformServiceStubs.Pasteboard()
    #endif
}

@MainActor
public func platformDefaultDeepLinkHandler() -> DeepLinkHandling {
    #if canImport(UIKit)
    IOSDeepLinkHandler()
    #else
    PlatformServiceStubs.DeepLinks()
    #endif
}

public func platformDefaultCredentialStorage() -> CredentialStorage {
    #if canImport(Security)
    IOSKeychainCredentialStorage()
    #else
    PlatformServiceStubs.Credentials()
    #endif
}

public func platformDefaultFileExportImport() -> FileExportImport {
    #if canImport(UIKit)
    IOSFileExportImport()
    #else
    PlatformServiceStubs.Files()
    #endif
}

@MainActor
public func platformDefaultLifecycleBackground() -> LifecycleBackground {
    #if canImport(UIKit)
    IOSLifecycleBackground()
    #else
    PlatformServiceStubs.Lifecycle()
    #endif
}

@MainActor
public func platformDefaultLocalNetworkErrorPresentation() -> LocalNetworkErrorPresentation {
    #if canImport(UIKit)
    IOSLocalNetworkErrorPresentation()
    #else
    PlatformServiceStubs.LocalNetworkErrors()
    #endif
}

@MainActor
public func platformDefaultAppLifecycleService() -> AppLifecycleProtocol {
    #if canImport(UIKit)
    IOSLifecycleService()
    #else
    PlatformServiceStubs.AppLifecycle()
    #endif
}

public struct PlatformServiceStubs {
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
        func handleOpenURL(_ url: URL) {
            enqueueIncomingLink(url.absoluteString)
        }
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

    final class AppLifecycle: AppLifecycleProtocol {
        var isNetworkReachable = true

        func start() {}
        func stop() {}

        func handleScenePhaseChange(_ phase: ScenePhase, isSessionConnected: Bool) -> AppLifecycleEffect {
            switch phase {
            case .background:
                return .pauseAutoRefresh
            case .active:
                return .resumeAutoRefresh(shouldReconnect: isSessionConnected)
            default:
                return .none
            }
        }
    }
}
