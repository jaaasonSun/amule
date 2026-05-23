import Foundation
import Security
import SharedUI

public struct IOSKeychainCredentialStorage: CredentialStorage, @unchecked Sendable {
    let service: String

    init(service: String = IOSKeychainCredentialStorage.defaultServiceName) {
        self.service = service
    }

    public func readCredential(forKey key: String) -> String? {
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

    public func writeCredential(_ credential: String, forKey key: String) {
        guard let data = credential.data(using: .utf8) else { return }
        let status = SecItemAdd(writeQuery(forKey: key, data: data) as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let update: [CFString: Any] = [kSecValueData: data]
            SecItemUpdate(baseQuery(forKey: key) as CFDictionary, update as CFDictionary)
        }
    }

    public func deleteCredential(forKey key: String) {
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

@MainActor
public final class IOSDeepLinkHandler: DeepLinkHandling {
    private let inbox: PendingIncomingLinkInbox

    public init(inbox: PendingIncomingLinkInbox = .shared) {
        self.inbox = inbox
    }

    public func enqueueIncomingLink(_ rawInput: String) {
        inbox.enqueue(rawInput)
    }

    public func drainIncomingLinks() -> [String] {
        inbox.drain()
    }

    public func registerIncomingLinkHandler() {}
    public func unregisterIncomingLinkHandler() {}

    public func handleOpenURL(_ url: URL) {
        let rawValue = url.absoluteString
        let lowercased = rawValue.lowercased()
        guard lowercased.hasPrefix("ed2k://") || lowercased.hasPrefix("magnet:?") else { return }
        enqueueIncomingLink(rawValue)
    }
}

public struct IOSFileExportImport: FileExportImport {
    public func exportData(_ data: Data, to url: URL) throws {
        let parentURL = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentURL, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    public func importData(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }
}

@MainActor
public final class IOSLocalNetworkErrorPresentation: LocalNetworkErrorPresentation {
    public func userFacingMessage(for error: Error) -> String {
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = message.lowercased()

        if lowercased.contains("operation not permitted") ||
            lowercased.contains("not permitted") ||
            lowercased.contains("permission denied") ||
            lowercased.contains("local network") {
            return detailedMessage(
                summary: localized("This app needs local network access to connect to aMule. Please enable it in Settings > Privacy & Security > Local Network."),
                details: message
            )
        }

        if lowercased.contains("wrong password") ||
            lowercased.contains("incorrect password") ||
            lowercased.contains("authentication failed") ||
            lowercased.contains("access denied") {
            return detailedMessage(
                summary: localized("Incorrect password. Please check your connection settings."),
                details: message
            )
        }

        if lowercased.contains("invalid port") ||
            lowercased.contains("port out of range") {
            return detailedMessage(
                summary: localized("Invalid port. Enter a value between 1 and 65535."),
                details: message
            )
        }

        if lowercased.contains("timed out") || lowercased.contains("timeout") {
            return detailedMessage(
                summary: localized("Connection timed out. Please check the host and port."),
                details: message
            )
        }

        if lowercased.contains("connection closed") {
            return detailedMessage(
                summary: localized("Connection closed by the aMule daemon. Please check the host, EC port, and password."),
                details: message
            )
        }

        if lowercased.contains("connection refused") ||
            lowercased.contains("could not connect") ||
            lowercased.contains("host unreachable") ||
            lowercased.contains("no route to host") ||
            lowercased.contains("network is unreachable") {
            return detailedMessage(
                summary: localized("Cannot connect to aMule daemon. Please check that it's running."),
                details: message
            )
        }

        return message
    }

    private func detailedMessage(summary: String, details: String) -> String {
        guard !details.isEmpty, details.caseInsensitiveCompare(summary) != .orderedSame else {
            return summary
        }
        return "\(summary)\n\n\(details)"
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, bundle: .main, comment: "")
    }
}

#if canImport(UIKit)
import UIKit

public struct IOSPasteboardShare: PasteboardShare, @unchecked Sendable {
    public func writeString(_ string: String) {
        UIPasteboard.general.string = string
    }

    public func readString() -> String? {
        UIPasteboard.general.string
    }
}

@MainActor
public final class IOSLifecycleBackground: LifecycleBackground {
    public func activateApplication() {}
    public func bringPrimaryWindowToFront() {}

    public func beginBackgroundActivity(reason: String) -> Any? {
        UIApplication.shared.beginBackgroundTask(withName: reason)
    }

    public func endBackgroundActivity(_ token: Any?) {
        guard let identifier = token as? UIBackgroundTaskIdentifier, identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
    }
}

@MainActor
public protocol ShareSheetPresenting: AnyObject {
    func present(items: [Any])
}

@MainActor
public final class IOSShareSheetPresenter: ShareSheetPresenting {
    public init() {}

    public func present(items: [Any]) {
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
