import Foundation
import SharedUI

#if canImport(Security)
import Security

struct IOSKeychainCredentialStorage: CredentialStorage, @unchecked Sendable {
    let service: String

    init(service: String = IOSKeychainCredentialStorage.defaultServiceName) {
        self.service = service
    }

    func readCredential(forKey key: String) -> String? {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(readQuery(forKey: key) as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil
        default:
            return nil
        }
    }

    func writeCredential(_ credential: String, forKey key: String) {
        guard let data = credential.data(using: .utf8) else { return }
        let status = SecItemAdd(writeQuery(forKey: key, data: data) as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let update: [CFString: Any] = [kSecValueData: data]
            SecItemUpdate(baseQuery(forKey: key) as CFDictionary, update as CFDictionary)
        }
    }

    func deleteCredential(forKey key: String) {
        SecItemDelete(baseQuery(forKey: key) as CFDictionary)
    }

    private func readQuery(forKey key: String) -> [CFString: Any] {
        var query = baseQuery(forKey: key)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        return query
    }

    private func writeQuery(forKey key: String, data: Data) -> [CFString: Any] {
        var query = baseQuery(forKey: key)
        query[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlocked
        query[kSecValueData] = data
        return query
    }

    private func baseQuery(forKey key: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
    }

    private static let defaultServiceName = Bundle.main.bundleIdentifier ?? "org.amule.remote.ios.credentials"
}
#endif

@MainActor
final class IOSDeepLinkHandler: DeepLinkHandling {
    private let inbox: PendingIncomingLinkInbox

    init(inbox: PendingIncomingLinkInbox = .shared) {
        self.inbox = inbox
    }

    func enqueueIncomingLink(_ rawInput: String) {
        inbox.enqueue(rawInput)
    }

    func drainIncomingLinks() -> [String] {
        inbox.drain()
    }

    func registerIncomingLinkHandler() {}
    func unregisterIncomingLinkHandler() {}

    func handleOpenURL(_ url: URL) {
        let rawValue = url.absoluteString
        let lowercased = rawValue.lowercased()
        guard lowercased.hasPrefix("ed2k://") || lowercased.hasPrefix("magnet:?") else { return }
        enqueueIncomingLink(rawValue)
    }
}

struct IOSFileExportImport: FileExportImport {
    func exportData(_ data: Data, to url: URL) throws {
        let parentURL = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentURL, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    func importData(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }
}

@MainActor
final class IOSLocalNetworkErrorPresentation: LocalNetworkErrorPresentation {
    func userFacingMessage(for error: Error) -> String {
        let message = error.localizedDescription
        let lowercased = message.lowercased()
        if lowercased.contains("operation not permitted") ||
            lowercased.contains("not permitted") ||
            lowercased.contains("permission denied") ||
            lowercased.contains("local network") ||
            lowercased.contains("network is unreachable") {
            return "Local network access may be blocked. Allow aMule Remote in Settings > Privacy & Security > Local Network, then try again.\n\n\(message)"
        }
        return message
    }
}

#if canImport(UIKit)
import UIKit

struct IOSPasteboardShare: PasteboardShare, @unchecked Sendable {
    func writeString(_ string: String) {
        UIPasteboard.general.string = string
    }

    func readString() -> String? {
        UIPasteboard.general.string
    }
}

@MainActor
final class IOSLifecycleBackground: LifecycleBackground {
    func activateApplication() {}
    func bringPrimaryWindowToFront() {}

    func beginBackgroundActivity(reason: String) -> Any? {
        UIApplication.shared.beginBackgroundTask(withName: reason)
    }

    func endBackgroundActivity(_ token: Any?) {
        guard let identifier = token as? UIBackgroundTaskIdentifier, identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
    }
}

@MainActor
protocol ShareSheetPresenting: AnyObject {
    func present(items: [Any])
}

@MainActor
final class IOSShareSheetPresenter: ShareSheetPresenting {
    func present(items: [Any]) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }),
            let rootViewController = scene.windows.first(where: \.isKeyWindow)?.rootViewController else {
            return
        }

        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            popover.sourceView = rootViewController.view
            popover.sourceRect = CGRect(
                x: rootViewController.view.bounds.midX,
                y: rootViewController.view.bounds.midY,
                width: 1,
                height: 1
            )
        }
        rootViewController.present(controller, animated: true)
    }
}
#endif
