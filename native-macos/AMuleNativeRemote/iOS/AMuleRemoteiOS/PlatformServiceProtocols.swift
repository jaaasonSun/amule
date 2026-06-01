import Foundation
import SharedViews
import SharedModels
import SharedServices
import SwiftUI

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
    public final class Pasteboard: PasteboardShare, @unchecked Sendable {
        private let lock = NSLock()
        private var value: String?

        public func writeString(_ string: String) {
            lock.lock()
            value = string
            lock.unlock()
        }

        public func readString() -> String? {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
    }

    @MainActor
    public final class DeepLinks: DeepLinkHandling {
        private var links: [String] = []

        public func enqueueIncomingLink(_ rawInput: String) {
            links.append(contentsOf: LinkImportSupport.parseLinks(from: rawInput))
        }

        public func drainIncomingLinks() -> [String] {
            let drained = links
            links.removeAll()
            return drained
        }

        public func registerIncomingLinkHandler() {}
        public func unregisterIncomingLinkHandler() {}
    }

    public final class Credentials: CredentialStorage, @unchecked Sendable {
        private let lock = NSLock()
        private var values: [String: String] = [:]

        public func readCredential(forKey key: String) -> String? {
            lock.lock()
            defer { lock.unlock() }
            return values[key]
        }

        public func writeCredential(_ credential: String, forKey key: String) {
            lock.lock()
            values[key] = credential
            lock.unlock()
        }

        public func deleteCredential(forKey key: String) {
            lock.lock()
            values.removeValue(forKey: key)
            lock.unlock()
        }
    }

    public struct Files: FileExportImport {
        public func exportData(_ data: Data, to url: URL) throws {
            try data.write(to: url, options: .atomic)
        }

        public func importData(from url: URL) throws -> Data {
            try Data(contentsOf: url)
        }
    }

    @MainActor
    public final class Lifecycle: LifecycleBackground {
        public private(set) var didActivate = false
        public private(set) var didBringPrimaryWindowToFront = false

        public func activateApplication() {
            didActivate = true
        }

        public func bringPrimaryWindowToFront() {
            didBringPrimaryWindowToFront = true
        }

        public func beginBackgroundActivity(reason: String) -> Any? {
            reason
        }

        public func endBackgroundActivity(_ token: Any?) {}
    }

    @MainActor
    public final class LocalNetworkErrors: LocalNetworkErrorPresentation {
        public func userFacingMessage(for error: Error) -> String {
            error.localizedDescription
        }
    }

    @MainActor
    public final class AppLifecycle: AppLifecycleProtocol {
        public var isNetworkReachable = true

        public func start() {}
        public func stop() {}

        public func handleScenePhaseChange(_ phase: ScenePhase, isSessionConnected: Bool) -> AppLifecycleEffect {
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
