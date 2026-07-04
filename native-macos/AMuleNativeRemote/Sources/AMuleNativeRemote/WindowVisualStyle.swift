import SwiftUI
import AppKit

struct WindowAppearanceConfigurator: NSViewRepresentable {
    var windowTitle: String? = nil
    var toolbarStyle: NSWindow.ToolbarStyle? = nil
    var showsToolbarBaselineSeparator: Bool? = nil
    var allowsToolbarCustomization: Bool = false
    var autosavesToolbarConfiguration: Bool = false
    var windowLevel: NSWindow.Level? = nil
    var windowCollectionBehavior: NSWindow.CollectionBehavior? = nil
    var isMovableByWindowBackground: Bool? = nil
    var panelHidesOnDeactivate: Bool? = nil
    var useUtilityStyleMask: Bool = false
    var isResizable: Bool? = nil
    var hidesStandardWindowButtons: Bool = false
    var showCloseButtonOnly: Bool = false
    var forceNoToolbar: Bool = false

    final class HostView: NSView {
        var applyConfiguration: ((NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            applyNow()
        }

        func applyNow() {
            guard let window else { return }
            applyConfiguration?(window)
        }
    }

    func makeNSView(context: Context) -> HostView {
        let view = HostView(frame: .zero)
        view.applyConfiguration = apply
        return view
    }

    func updateNSView(_ nsView: HostView, context: Context) {
        nsView.applyConfiguration = apply
        nsView.applyNow()
    }

    private func apply(to window: NSWindow) {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.apply(to: window)
            }
            return
        }

        if let windowTitle {
            window.title = windowTitle
        }

        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.titlebarSeparatorStyle = .automatic
        window.styleMask.remove(.fullSizeContentView)
        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor

        if forceNoToolbar {
            window.toolbar = nil
        }

        if let toolbarStyle {
            window.toolbarStyle = toolbarStyle
        }
        if let showsToolbarBaselineSeparator, let toolbar = window.toolbar {
            let object = toolbar as NSObject
            let selector = NSSelectorFromString("setShowsBaselineSeparator:")
            if object.responds(to: selector) {
                object.setValue(showsToolbarBaselineSeparator, forKey: "showsBaselineSeparator")
            }
        }
        if allowsToolbarCustomization {
            window.toolbar?.allowsUserCustomization = true
        }
        if autosavesToolbarConfiguration {
            window.toolbar?.autosavesConfiguration = true
        }

        if let toolbar = window.toolbar,
           toolbar.identifier == NSToolbar.Identifier("GlassToolbar") {
            window.toolbar = nil
        }

        if useUtilityStyleMask {
            window.styleMask.insert(.utilityWindow)
        } else {
            window.styleMask.remove(.utilityWindow)
        }
        if let isResizable {
            if isResizable {
                window.styleMask.insert(.resizable)
            } else {
                window.styleMask.remove(.resizable)
            }
        }

        if let windowLevel {
            window.level = windowLevel
        }
        if let windowCollectionBehavior {
            window.collectionBehavior = windowCollectionBehavior
        }
        if let isMovableByWindowBackground {
            window.isMovableByWindowBackground = isMovableByWindowBackground
        }
        if let panelHidesOnDeactivate, let panel = window as? NSPanel {
            panel.hidesOnDeactivate = panelHidesOnDeactivate
        }

        if hidesStandardWindowButtons {
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
        } else if showCloseButtonOnly {
            window.standardWindowButton(.closeButton)?.isHidden = false
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
        } else {
            window.standardWindowButton(.closeButton)?.isHidden = false
            window.standardWindowButton(.miniaturizeButton)?.isHidden = false
            window.standardWindowButton(.zoomButton)?.isHidden = false
        }
    }
}

struct WindowTopInsetReader: NSViewRepresentable {
    var onChange: (CGFloat) -> Void

    final class HostView: NSView {
        var onChange: ((CGFloat) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            notify()
        }

        override func layout() {
            super.layout()
            notify()
        }

        private func notify() {
            guard let window,
                  let contentView = window.contentView else {
                return
            }
            let contentFrame = contentView.frame
            let layoutRect = window.contentLayoutRect
            let inset = max(0, contentFrame.maxY - layoutRect.maxY)
            onChange?(inset)
        }
    }

    func makeNSView(context: Context) -> HostView {
        let view = HostView(frame: .zero)
        view.onChange = onChange
        return view
    }

    func updateNSView(_ nsView: HostView, context: Context) {
        nsView.onChange = onChange
        nsView.layoutSubtreeIfNeeded()
    }
}
