import SwiftUI
import AppKit

struct GlassEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSView {
        let container = NSView(frame: .zero)
        container.wantsLayer = false
        installEffectView(in: container)
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let effectView = nsView.subviews.first else {
            installEffectView(in: nsView)
            return
        }
        if let visual = effectView as? NSVisualEffectView {
            visual.material = material
            visual.blendingMode = blendingMode
            visual.state = .active
            visual.isEmphasized = false
        } else {
            applyGlassPropertiesIfAvailable(effectView)
        }
    }

    private func installEffectView(in container: NSView) {
        container.subviews.forEach { $0.removeFromSuperview() }

        let effectView: NSView
        if let glassClass = NSClassFromString("NSGlassEffectView") as? NSView.Type {
            let glass = glassClass.init(frame: .zero)
            applyGlassPropertiesIfAvailable(glass)
            effectView = glass
        } else {
            let visual = NSVisualEffectView(frame: .zero)
            visual.material = material
            visual.blendingMode = blendingMode
            visual.state = .active
            visual.isEmphasized = false
            effectView = visual
        }

        effectView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(effectView)
        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            effectView.topAnchor.constraint(equalTo: container.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }

    private func applyGlassPropertiesIfAvailable(_ view: NSView) {
        let object = view as NSObject
        let setState = NSSelectorFromString("setState:")
        let setInteractive = NSSelectorFromString("setInteractive:")

        if object.responds(to: setState) {
            object.setValue(1, forKey: "state")
        }
        if object.responds(to: setInteractive) {
            object.setValue(true, forKey: "interactive")
        }
    }
}

struct WindowAppearanceConfigurator: NSViewRepresentable {
    var hideTitle: Bool = false
    var transparentTitlebar: Bool = false
    var fullSizeContentView: Bool = false
    var toolbarStyle: NSWindow.ToolbarStyle? = nil
    var showsToolbarBaselineSeparator: Bool? = nil
    var allowsToolbarCustomization: Bool = false
    var autosavesToolbarConfiguration: Bool = false
    var makeWindowTransparent: Bool = true
    var ensureToolbarWhenTransparentTitlebar: Bool = false
    var windowLevel: NSWindow.Level? = nil
    var windowCollectionBehavior: NSWindow.CollectionBehavior? = nil
    var isMovableByWindowBackground: Bool? = nil
    var panelHidesOnDeactivate: Bool? = nil
    var useUtilityStyleMask: Bool = false
    var isResizable: Bool? = nil
    var hidesStandardWindowButtons: Bool = false
    var showCloseButtonOnly: Bool = false
    var forceNoToolbar: Bool = false
    var toolbarTopGradientHeight: CGFloat? = nil
    var toolbarTopGradientOpacity: CGFloat = 0.0

    final class HostView: NSView {
        var applyConfiguration: ((NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            applyNow()
        }

        override func layout() {
            super.layout()
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

        if hideTitle {
            window.title = ""
            window.titleVisibility = .hidden
        } else {
            window.titleVisibility = .visible
        }

        if makeWindowTransparent {
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
        }

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

        if transparentTitlebar && ensureToolbarWhenTransparentTitlebar && window.toolbar == nil {
            let toolbar = NSToolbar(identifier: "GlassToolbar")
            toolbar.displayMode = .iconOnly
            toolbar.allowsUserCustomization = false
            window.toolbar = toolbar
        } else if transparentTitlebar && !ensureToolbarWhenTransparentTitlebar,
                  let toolbar = window.toolbar,
                  toolbar.identifier == NSToolbar.Identifier("GlassToolbar") {
            window.toolbar = nil
        }

        if fullSizeContentView {
            window.styleMask.insert(.fullSizeContentView)
        } else {
            window.styleMask.remove(.fullSizeContentView)
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
        window.titlebarAppearsTransparent = transparentTitlebar

        if transparentTitlebar {
            window.titlebarSeparatorStyle = .none
            if let themeFrame = window.contentView?.superview {
                themeFrame.wantsLayer = true
                themeFrame.layer?.backgroundColor = NSColor.clear.cgColor
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

        updateToolbarTopGradient(in: window)
    }

    private func updateToolbarTopGradient(in window: NSWindow) {
        guard let themeFrame = window.contentView?.superview else { return }
        let gradientIdentifier = NSUserInterfaceItemIdentifier("AMule.ToolbarTopGradient")
        themeFrame.subviews
            .first(where: { $0.identifier == gradientIdentifier })?
            .removeFromSuperview()
    }
}

private final class ToolbarTopGradientView: NSView {
    private let gradientLayer = CAGradientLayer()
    private var gradientOpacity: CGFloat = 0.35

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.addSublayer(gradientLayer)
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 1.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 0.0)
        updateOpacity(0.35)
    }

    override func layout() {
        super.layout()
        gradientLayer.frame = bounds
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshGradientColors()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func updateOpacity(_ opacity: CGFloat) {
        gradientOpacity = max(0, min(opacity, 1))
        refreshGradientColors()
    }

    private func refreshGradientColors() {
        var resolved = NSColor.windowBackgroundColor
        if #available(macOS 10.14, *) {
            effectiveAppearance.performAsCurrentDrawingAppearance {
                resolved = NSColor.windowBackgroundColor
            }
        }
        gradientLayer.colors = [
            resolved.withAlphaComponent(gradientOpacity).cgColor,
            resolved.withAlphaComponent(gradientOpacity * 0.5).cgColor,
            resolved.withAlphaComponent(0).cgColor
        ]
        gradientLayer.locations = [0.0, 0.45, 1.0]
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
