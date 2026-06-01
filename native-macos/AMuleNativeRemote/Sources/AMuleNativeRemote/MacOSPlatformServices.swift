#if os(macOS)
import AppKit
import AMuleECBridgeAdapter
import Carbon.HIToolbox
import Foundation
import SharedViews
import SharedModels
import SharedServices

extension AMuleConnectionConfig {
    static let fallbackBridgeCommand = "amule-ec-bridge"

    static var bundledBridgePath: String? {
        let fm = FileManager.default
        if let resource = Bundle.main.resourceURL?.appendingPathComponent("amule-ec-bridge").path,
           fm.isExecutableFile(atPath: resource) {
            return resource
        }

        let appBundlePath = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/amule-ec-bridge")
            .path
        if fm.isExecutableFile(atPath: appBundlePath) {
            return appBundlePath
        }
        return nil
    }

    static func preferredDefaultPath() -> String {
        let fm = FileManager.default
        if let bundled = bundledBridgePath {
            return bundled
        }

        let cwd = fm.currentDirectoryPath
        let candidates = [
            URL(fileURLWithPath: cwd)
                .appendingPathComponent("build/src/amule-ec-bridge")
                .path,
            URL(fileURLWithPath: cwd)
                .appendingPathComponent("../build/src/amule-ec-bridge")
                .standardized.path,
            URL(fileURLWithPath: cwd)
                .appendingPathComponent("../../build/src/amule-ec-bridge")
                .standardized.path,
            "/opt/homebrew/bin/amule-ec-bridge",
            "/usr/local/bin/amule-ec-bridge"
        ]

        for candidate in candidates where fm.isExecutableFile(atPath: candidate) {
            return candidate
        }

        return fallbackBridgeCommand
    }
}

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

func platformDefaultPasteboardShare() -> PasteboardShare {
    MacOSPasteboardShare()
}
