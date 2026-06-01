#if os(macOS)
import AppKit
import Carbon.HIToolbox
import Foundation
import SharedUI

struct MacOSPasteboardShare: PasteboardShare, @unchecked Sendable {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    func writeString(_ string: String) {
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    func readString() -> String? {
        pasteboard.string(forType: .string)
    }
}

@MainActor
final class MacOSDeepLinkHandler: NSObject, NSApplicationDelegate, DeepLinkHandling {
    private let inbox: PendingIncomingLinkInbox
    private let lifecycle: LifecycleBackground

    override init() {
        self.inbox = .shared
        self.lifecycle = MacOSLifecycleBackground()
        super.init()
    }

    init(
        inbox: PendingIncomingLinkInbox = .shared,
        lifecycle: LifecycleBackground = MacOSLifecycleBackground()
    ) {
        self.inbox = inbox
        self.lifecycle = lifecycle
        super.init()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        registerIncomingLinkHandler()
    }

    func applicationWillTerminate(_ notification: Notification) {
        unregisterIncomingLinkHandler()
    }

    func enqueueIncomingLink(_ rawInput: String) {
        inbox.enqueue(rawInput)
    }

    func drainIncomingLinks() -> [String] {
        inbox.drain()
    }

    func registerIncomingLinkHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(event:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func unregisterIncomingLinkHandler() {
        NSAppleEventManager.shared().removeEventHandler(
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleGetURL(event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let incomingURL = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else {
            return
        }

        enqueueIncomingLink(incomingURL)
        lifecycle.activateApplication()
        lifecycle.bringPrimaryWindowToFront()
    }
}

struct MacOSCredentialStorage: CredentialStorage, @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func readCredential(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    func writeCredential(_ credential: String, forKey key: String) {
        defaults.set(credential, forKey: key)
    }

    func deleteCredential(forKey key: String) {
        defaults.removeObject(forKey: key)
    }
}
#endif

struct MacOSFileExportImport: FileExportImport {
    func exportData(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    func importData(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }
}

@MainActor
final class MacOSLifecycleBackground: LifecycleBackground {
    func activateApplication() {
        NSApp.activate(ignoringOtherApps: true)
    }

    func bringPrimaryWindowToFront() {
        if let downloadsWindow = NSApp.windows.first(where: { $0.title == "Downloads" }) {
            downloadsWindow.makeKeyAndOrderFront(nil)
            return
        }

        if let mainWindow = NSApp.mainWindow {
            mainWindow.makeKeyAndOrderFront(nil)
        }
    }

    func beginBackgroundActivity(reason: String) -> Any? {
        ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled], reason: reason)
    }

    func endBackgroundActivity(_ token: Any?) {
        guard let activity = token as? NSObjectProtocol else { return }
        ProcessInfo.processInfo.endActivity(activity)
    }
}

@MainActor
final class MacOSLocalNetworkErrorPresentation: LocalNetworkErrorPresentation {
    func userFacingMessage(for error: Error) -> String {
        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("operation not permitted") ||
            message.localizedCaseInsensitiveContains("network is unreachable") ||
            message.localizedCaseInsensitiveContains("local network") {
            return "Local network access may be blocked. Allow aMule Remote in System Settings > Privacy & Security > Local Network, then try again.\n\n\(message)"
        }
        return message
    }
}
