import AppKit
import SwiftUI
import XCTest

@MainActor
func writeRenderedSurface<V: View>(
    _ view: V,
    size: CGSize,
    to outputURL: URL,
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    let hostingView = NSHostingView(rootView: view)
    hostingView.appearance = NSAppearance(named: .aqua)
    hostingView.frame = NSRect(origin: .zero, size: size)

    let window = NSWindow(
        contentRect: NSRect(origin: .zero, size: size),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.appearance = NSAppearance(named: .aqua)
    window.contentView = hostingView
    window.layoutIfNeeded()
    hostingView.layoutSubtreeIfNeeded()
    hostingView.displayIfNeeded()

    guard let representation = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
        XCTFail("Could not create bitmap representation for rendered surface.", file: file, line: line)
        return
    }
    hostingView.cacheDisplay(in: hostingView.bounds, to: representation)

    guard let pngData = representation.representation(using: .png, properties: [:]) else {
        XCTFail("Could not encode rendered surface as PNG.", file: file, line: line)
        return
    }

    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try pngData.write(to: outputURL, options: .atomic)
    XCTAssertGreaterThan(pngData.count, 4_096, "Rendered surface PNG should not be empty.", file: file, line: line)
}

@MainActor
func writeRenderedWindowSurface<V: View>(
    _ view: V,
    size: CGSize,
    to outputURL: URL,
    title: String = "Settings",
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    let hostingView = NSHostingView(rootView: view)
    hostingView.appearance = NSAppearance(named: .aqua)
    hostingView.frame = NSRect(origin: .zero, size: size)

    let window = NSWindow(
        contentRect: NSRect(origin: .zero, size: size),
        styleMask: [.titled, .closable, .miniaturizable],
        backing: .buffered,
        defer: false
    )
    window.appearance = NSAppearance(named: .aqua)
    window.contentView = hostingView
    window.title = title
    window.layoutIfNeeded()
    hostingView.layoutSubtreeIfNeeded()
    hostingView.displayIfNeeded()

    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    window.layoutIfNeeded()

    let captureView = window.contentView?.superview ?? hostingView
    captureView.layoutSubtreeIfNeeded()
    captureView.displayIfNeeded()

    guard let representation = captureView.bitmapImageRepForCachingDisplay(in: captureView.bounds) else {
        XCTFail("Could not create bitmap representation for rendered window surface.", file: file, line: line)
        return
    }
    captureView.cacheDisplay(in: captureView.bounds, to: representation)

    guard let pngData = representation.representation(using: .png, properties: [:]) else {
        XCTFail("Could not encode rendered window surface as PNG.", file: file, line: line)
        return
    }

    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try pngData.write(to: outputURL, options: .atomic)
    XCTAssertGreaterThan(pngData.count, 4_096, "Rendered window surface PNG should not be empty.", file: file, line: line)
}

func repositoryRoot(from packageRoot: URL) -> URL {
    let fileManager = FileManager.default
    var candidate = packageRoot.standardizedFileURL

    while true {
        if fileManager.fileExists(atPath: candidate.appendingPathComponent(".git").path) {
            return candidate
        }

        let parent = candidate.deletingLastPathComponent()
        if parent.path == candidate.path {
            return packageRoot
        }
        candidate = parent
    }
}
