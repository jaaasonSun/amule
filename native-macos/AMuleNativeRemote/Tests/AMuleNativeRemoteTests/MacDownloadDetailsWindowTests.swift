import SwiftUI
import XCTest
import SharedModels
@testable import AMuleNativeRemote

@MainActor
final class MacDownloadDetailsWindowTests: XCTestCase {
    private var packageRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.lastPathComponent != "AMuleNativeRemote" {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path {
                XCTFail("Could not locate AMuleNativeRemote package root from \(#filePath)")
                return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            }
            url = parent
        }
        return url
    }

    func testSeparateDetailsWindowRemainsSelectionTrackingAndReusesContent() throws {
        let app = try source("Sources/AMuleNativeRemote/AMuleNativeRemoteApp.swift")
        let window = try source("Sources/AMuleNativeRemote/DownloadDetailsWindowView.swift")
        let content = try source("Sources/AMuleNativeRemote/DownloadDetailsContentView.swift")

        XCTAssertTrue(app.contains("Window(\"Details\", id: \"download-details-window\")"), "Separate Details window scene and ID must remain unchanged.")
        XCTAssertTrue(app.contains("DownloadDetailsWindowView()"), "The separate Details window should still host DownloadDetailsWindowView.")
        XCTAssertTrue(window.contains("DownloadDetailsContentView()"), "The separate Details window must host the window-only details content directly.")
        XCTAssertTrue(content.contains("guard let selectedDownloadID = model.selectedDownloadID else { return nil }"), "The separate Details window is intentionally selection-tracking through model.selectedDownloadID.")
        XCTAssertTrue(content.contains(".onChange(of: model.selectedDownloadID)"), "Selection-tracking details content should resync when the selected download changes.")
        XCTAssertTrue(content.contains(".onChange(of: model.downloads)"), "Selection-tracking details content should notice deleted/stale downloads.")
        XCTAssertTrue(content.contains("struct DownloadDetailsContentView: View"), "The long details UI should live in one reusable view.")
        XCTAssertFalse(content.contains("DownloadDetails" + "Presentation"), "Details content is window-only and should not keep presentation modes.")
        XCTAssertTrue(content.contains("Table(sources, sortOrder: $sortOrder)"), "Shared content should keep the source table implementation.")
        XCTAssertTrue(content.contains("return 230"), "Many-source table height should remain bounded.")
    }

    func testMainContentRoutesDetailsToStandaloneWindowOnly() throws {
        let content = try source("Sources/AMuleNativeRemote/ContentView.swift")

        XCTAssertFalse(content.contains("showsDownload" + "DetailsInspector"), "ContentView should not keep embedded inspector visibility state.")
        XCTAssertFalse(content.contains("downloadDetails" + "InspectorColumn"), "Downloads content should not include a trailing inspector column.")
        XCTAssertFalse(content.contains("DownloadDetailsContentView("), "ContentView should not render Details content inline.")
        XCTAssertFalse(content.contains("initialShowsDownload" + "DetailsInspector"), "Tests and previews should not seed removed inspector state.")
        XCTAssertFalse(content.contains("initialSelected" + "DownloadIDs"), "ContentView should not expose inspector-only selection initializer state.")
        XCTAssertTrue(content.contains("model.selectedDownloadID = nil"), "Stale selected downloads should clear instead of showing wrong details.")
        XCTAssertTrue(content.contains("openDownloadDetailsWindow(for: selectedDownload)"), "Toolbar Details should route the selected download to the standalone window.")
        XCTAssertTrue(content.contains("showDetails: { openDownloadDetailsWindow(for: $0) }"), "Context-menu Details on a specific row should open that row, not a stale selection.")
        XCTAssertTrue(content.contains("selectedDownloadIDs = [item.id]"), "Opening row details should synchronize the table selection.")
        XCTAssertTrue(content.contains("model.selectedDownloadID = item.id"), "Opening details should synchronize the model selection before opening the window.")
        XCTAssertFalse(content.contains("refreshDownloadSources"), "ContentView should not duplicate source refresh; Details content owns automatic refresh.")
        XCTAssertTrue(content.contains("openWindow(id: \"download-details-window\")"), "All Details entry points should use the standalone Details scene ID.")
        XCTAssertTrue(content.contains("NSApp.activate(ignoringOtherApps: true)"), "Details window routing should bring the app forward like other window actions.")
    }

    func testAppMenuShowDetailsOpensDetailsWindowWithoutContentViewNotification() throws {
        let app = try source("Sources/AMuleNativeRemote/AMuleNativeRemoteApp.swift")
        let content = try source("Sources/AMuleNativeRemote/ContentView.swift")

        XCTAssertTrue(app.contains("Button(L(\"Show Details\"))"), "Downloads menu should keep the Show Details command.")
        XCTAssertTrue(app.contains("openWindow(id: \"download-details-window\")"), "App menu Show Details must open the Details scene directly.")
        XCTAssertTrue(app.contains("NSApp.activate(ignoringOtherApps: true)"), "App menu Show Details should activate the app after opening Details.")
        XCTAssertTrue(app.contains(".keyboardShortcut(.defaultAction)"), "Return should keep invoking the Details command.")
        XCTAssertTrue(app.contains(".disabled(model.selectedDownloadID == nil)"), "The app menu command should stay disabled when no download is selected.")
        XCTAssertFalse(app.contains("amuleShowSelected" + "DownloadDetails"), "The app menu must not post a ContentView-only Details notification.")
        XCTAssertFalse(content.contains("amuleShowSelected" + "DownloadDetails"), "ContentView should not be required for app-menu Details routing.")
    }

    func testDownloadSourceRefreshOwnershipIsNotDuplicatedAcrossDetailsRoutes() throws {
        let content = try source("Sources/AMuleNativeRemote/ContentView.swift")
        let details = try source("Sources/AMuleNativeRemote/DownloadDetailsContentView.swift")

        XCTAssertFalse(content.contains("refreshDownloadSources"), "ContentView selection/open routes should not own source refresh.")
        XCTAssertTrue(details.contains(".onAppear {\n            syncSelectionState(refreshSources: true)"), "Details should refresh sources when the window content appears.")
        XCTAssertTrue(details.contains(".onChange(of: model.selectedDownloadID) { _, _ in\n            syncSelectionState(refreshSources: true)"), "Details should refresh sources when the selected download changes.")
        XCTAssertTrue(details.contains(".onChange(of: model.downloads) { _, _ in\n            syncSelectionState(refreshSources: false)"), "Download list polling should only validate stale selection, not refresh sources again.")
        XCTAssertTrue(details.contains("if refreshSources {\n            model.refreshDownloadSources(for: selectedDownload)\n        }"), "Automatic refresh should be gated by the Details lifecycle owner.")
        XCTAssertTrue(details.contains("Button(L(\"Refresh\")) {\n                    model.refreshDownloadSources(for: item)"), "The explicit Refresh button should remain available.")
    }

    func testInspectorOnlyStringsAreRemovedFromChineseTables() throws {
        let zhHans = try source("Resources/zh-Hans.lproj/Localizable.strings")
        let zhCN = try source("Resources/zh_CN.lproj/Localizable.strings")

        [
            "Download " + "Inspector",
            "Close Download " + "Inspector",
            "No download " + "selected",
            "Select a download to " + "inspect its details.",
            "Open Separate " + "Details Window"
        ].forEach { key in
            XCTAssertFalse(zhHans.contains("\"\(key)\" ="), "zh-Hans should remove unreferenced inspector-only key: \(key)")
            XCTAssertFalse(zhCN.contains("\"\(key)\" ="), "zh_CN should remove unreferenced inspector-only key: \(key)")
        }
    }

    func testStandaloneDetailsWindowRenderEvidence() throws {
        let selectedModel = AppModel.previewWithDownloads()
        let selectedID = try XCTUnwrap(selectedModel.downloads.first?.id)
        selectedModel.selectedDownloadID = selectedID
        selectedModel.downloadSourcesByHash[selectedID] = sampleSources(for: selectedModel.downloads[0])

        let noSelectionModel = AppModel.previewWithDownloads()
        noSelectionModel.selectedDownloadID = nil

        try writeRenderedWindowSurface(
            DownloadDetailsWindowView().environmentObject(selectedModel),
            size: CGSize(width: 860, height: 640),
            to: evidenceRoot.appendingPathComponent("standalone-details-window.png"),
            title: "Details"
        )

        try writeRenderedWindowSurface(
            DownloadDetailsWindowView().environmentObject(noSelectionModel),
            size: CGSize(width: 860, height: 320),
            to: evidenceRoot.appendingPathComponent("standalone-details-no-selection.png"),
            title: "Details"
        )
    }

    func testStaleSelectedDownloadFallsBackToStandaloneWindowNoSelectionState() throws {
        let model = AppModel.previewWithDownloads()
        let deletedDownload = try XCTUnwrap(model.downloads.first)

        model.selectedDownloadID = deletedDownload.id
        model.downloads.removeAll { $0.id == deletedDownload.id }
        model.downloadSourcesByHash.removeValue(forKey: deletedDownload.id)

        try writeRenderedWindowSurface(
            DownloadDetailsWindowView().environmentObject(model),
            size: CGSize(width: 860, height: 320),
            to: evidenceRoot.appendingPathComponent("standalone-details-stale-selection.png"),
            title: "Details"
        )

        XCTAssertEqual(model.selectedDownloadID, nil, "Stale deleted download selection must be cleared instead of showing wrong details in the standalone window.")
    }

    func testStaleFinalSelectedDownloadClearsWhenDownloadsBecomeEmpty() throws {
        let model = AppModel.previewWithDownloads()
        let selectedDownload = try XCTUnwrap(model.downloads.first)
        model.downloads = [selectedDownload]
        model.selectedDownloadID = selectedDownload.id
        model.downloads = []

        try writeRenderedWindowSurface(
            DownloadDetailsWindowView().environmentObject(model),
            size: CGSize(width: 860, height: 320),
            to: evidenceRoot.appendingPathComponent("standalone-details-stale-final-download.png"),
            title: "Details"
        )

        XCTAssertEqual(model.selectedDownloadID, nil, "A stale selected final download must clear even when the downloads array becomes empty.")
    }

    private var evidenceRoot: URL {
        repositoryRoot(from: packageRoot)
            .appendingPathComponent(".sisyphus/evidence/task-4-details-hybrid")
    }

    private func sampleSources(for download: DownloadItem) -> [DownloadSourceItem] {
        var sources: [DownloadSourceItem] = []
        for index in 1...8 {
            let isDownloading = index.isMultiple(of: 2)
            let remoteFilename = "Ubuntu ISO mirror \(index).iso"
            let downloadedTotal = index * 4096
            let uploadedTotal = index * 2048
            sources.append(
                DownloadSourceItem(
                id: index,
                requestFileID: download.ecid,
                clientName: "Peer \(index)",
                userIP: "10.0.0.\(index)",
                userPort: 4662,
                serverName: "ExampleServer",
                serverIP: "1.2.3.4",
                serverPort: 4661,
                software: "aMule",
                softwareVersion: "2.3.3",
                downloadState: isDownloading ? 4 : 2,
                downloadStateText: isDownloading ? "Downloading" : "On queue",
                sourceFrom: 1,
                sourceFromText: "Server",
                downSpeedKBps: Double(index) * 12.5,
                availableParts: 8 + index,
                remoteQueueRank: index * 3,
                obfuscationStatus: 1,
                extendedProtocol: true,
                remoteFilename: remoteFilename,
                downloadedTotal: downloadedTotal,
                uploadedTotal: uploadedTotal,
                versionString: "2.3.3",
                sharesFileList: isDownloading
            )
            )
        }
        return sources
    }

    private func source(_ relativePath: String) throws -> String {
        try String(
            contentsOf: packageRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
