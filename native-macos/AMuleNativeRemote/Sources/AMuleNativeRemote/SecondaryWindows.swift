import SwiftUI
import AppKit

private func L2(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func LF2(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), locale: .current, arguments: args)
}

private enum ServerWindowConnectionState2 {
    case connected
    case disconnected
    case transitional
    case unknown
}

private func connectionState2(from value: String) -> ServerWindowConnectionState2 {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty || trimmed == "-" { return .unknown }

    let lower = trimmed.lowercased()
    if ["disconnected", "not connected", "offline", "stopped", "off", "断开", "未连接", "離線", "离线", "未連線"]
        .contains(where: { lower.contains($0) }) {
        return .disconnected
    }
    if ["connecting", "starting", "initializing", "pending", "run", "running", "连接中", "正在连接", "連線中", "初始化"]
        .contains(where: { lower.contains($0) }) {
        return .transitional
    }
    if ["connected", "lowid", "highid", "firewalled", "on", "已连接", "已連線", "连接", "連線"]
        .contains(where: { lower.contains($0) }) {
        return .connected
    }
    return .unknown
}

private func localizedConnectionStateText2(_ state: ServerWindowConnectionState2) -> String {
    switch state {
    case .connected: return L2("Connected")
    case .disconnected: return L2("Disconnected")
    case .transitional: return L2("Connecting")
    case .unknown: return L2("Unknown")
    }
}

private func extractED2kServerName2(from value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let prefixes = ["Connected to ", "Connecting to "]
    guard let prefix = prefixes.first(where: { trimmed.hasPrefix($0) }) else { return nil }

    var rest = String(trimmed.dropFirst(prefix.count))
    if let suffixRange = rest.range(of: #"\s+(LowID|HighID)\s*$"#, options: .regularExpression) {
        rest.removeSubrange(suffixRange)
    }
    if let endpointRange = rest.range(
        of: #"\s+\[?[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(?::[0-9]+)?\]?$"#,
        options: .regularExpression
    ) {
        rest.removeSubrange(endpointRange)
    }
    let name = rest.trimmingCharacters(in: .whitespacesAndNewlines)
    return name.isEmpty ? nil : name
}

private func localizedED2kStatusSummary2(_ value: String) -> String {
    let state = connectionState2(from: value)
    switch state {
    case .connected:
        if let name = extractED2kServerName2(from: value) {
            return LF2("Connected to %@", name)
        }
    case .transitional:
        if let name = extractED2kServerName2(from: value) {
            return LF2("Connecting to %@", name)
        }
    case .disconnected, .unknown:
        break
    }
    return localizedConnectionStateText2(state)
}

private enum SearchOutlineSortKey: String {
    case index
    case name
    case sizeBytes
    case sources
    case completeSources
    case statusCode
    case alreadyHave
    case hash
}

private struct SearchTreeNode: Identifiable, Hashable {
    let result: SearchResult
    var children: [SearchTreeNode]

    var id: SearchResult.ID { result.id }
}

struct SearchWindowView: View {
    @EnvironmentObject private var model: AppModel

    let embeddedInMainWindow: Bool
    let mockMode: Bool

    init(embeddedInMainWindow: Bool = false, mockMode: Bool = false) {
        self.embeddedInMainWindow = embeddedInMainWindow
        self.mockMode = mockMode
    }

    @State private var searchSortDescriptors = [
        NSSortDescriptor(key: SearchOutlineSortKey.index.rawValue, ascending: true)
    ]
    @State private var displayedSearchResults: [SearchResult] = []
    @State private var selectedSearchResultIDs: Set<SearchResult.ID> = []
    @State private var mockSearchQuery: String = ""
    @State private var mockSearchScope: String = "global"

    private var selectedSearchResults: [SearchResult] {
        displayedSearchResults.filter { selectedSearchResultIDs.contains($0.id) }
    }

    private var searchTree: [SearchTreeNode] {
        buildSearchTree(from: displayedSearchResults, using: searchSortDescriptors)
    }

    private var searchOutlineAutosaveName: String {
        if mockMode {
            return "AMuleNativeRemote.SearchOutline.Mock"
        }
        return embeddedInMainWindow
            ? "AMuleNativeRemote.SearchOutline.Main"
            : "AMuleNativeRemote.SearchOutline.Window"
    }

    private var activeSearchScopeValue: String {
        mockMode ? mockSearchScope : model.searchScope
    }

    private var searchScopeMenuLabel: String {
        switch activeSearchScopeValue.lowercased() {
        case "kad":
            return L2("Kad")
        case "local":
            return L2("Local")
        default:
            return L2("Global")
        }
    }

    private var searchToolbarPlaceholder: String { L2("Search") }

    private var searchQueryBinding: Binding<String> {
        if mockMode {
            return $mockSearchQuery
        }
        return $model.searchQuery
    }

    private var isSearchInProgressForUI: Bool {
        mockMode ? false : model.isSearchInProgress
    }

    private var canDownloadSelectedSearchResults: Bool {
        !mockMode && !selectedSearchResults.isEmpty && !model.isBusy
    }

    var body: some View {
        if embeddedInMainWindow {
            baseSearchContent
        } else {
            baseSearchContent
                .frame(minWidth: 920, minHeight: 320)
                .background(
                    GlassEffectBackground(material: .underWindowBackground)
                        .ignoresSafeArea()
                )
                .background(
                    WindowAppearanceConfigurator(
                        hideTitle: true,
                        transparentTitlebar: true,
                        fullSizeContentView: true,
                        toolbarStyle: .automatic,
                        makeWindowTransparent: true,
                        ensureToolbarWhenTransparentTitlebar: false
                    )
                )
        }
    }

    private var baseSearchContent: some View {
        SearchResultsOutlineView(
            nodes: searchTree,
            selection: $selectedSearchResultIDs,
            sortDescriptors: $searchSortDescriptors,
            autosaveName: searchOutlineAutosaveName
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .frame(minHeight: 320)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    guard !mockMode else { return }
                    model.downloadResults(selectedSearchResults)
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                }
                .help("Download Selected")
                .disabled(!canDownloadSelectedSearchResults)

                Button {
                    guard !mockMode else { return }
                    model.stopSearch()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .help("Stop Search")
                .disabled(!isSearchInProgressForUI)

                Menu {
                    Button {
                        setSearchScope("kad")
                    } label: {
                        HStack {
                            Text("Kad")
                            if activeSearchScopeValue.lowercased() == "kad" {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    Button {
                        setSearchScope("global")
                    } label: {
                        HStack {
                            Text("Global")
                            if activeSearchScopeValue.lowercased() == "global" {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    Button {
                        setSearchScope("local")
                    } label: {
                        HStack {
                            Text("Local")
                            if activeSearchScopeValue.lowercased() == "local" {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    Text(searchScopeMenuLabel)
                }
                .help("Search Scope")
            }
        }
        .searchable(
            text: searchQueryBinding,
            placement: .toolbar,
            prompt: Text(searchToolbarPlaceholder)
        )
        .onSubmit(of: .search) {
            guard !mockMode else { return }
            model.performSearch()
        }
        .task {
            refreshDisplayedSearchResults()
        }
        .onChange(of: model.searchResults) {
            refreshDisplayedSearchResults()
        }
        .onChange(of: mockSearchQuery) {
            guard mockMode else { return }
            refreshDisplayedSearchResults()
        }
        .onChange(of: mockSearchScope) {
            guard mockMode else { return }
            refreshDisplayedSearchResults()
        }
    }

    private func refreshDisplayedSearchResults() {
        if mockMode {
            displayedSearchResults = mockSearchResults(scope: activeSearchScopeValue, query: mockSearchQuery)
        } else {
            displayedSearchResults = model.searchResults
        }
        let validIDs = Set(displayedSearchResults.map(\.id))
        selectedSearchResultIDs = selectedSearchResultIDs.intersection(validIDs)
    }

    private func setSearchScope(_ scope: String) {
        if mockMode {
            mockSearchScope = scope
        } else {
            model.searchScope = scope
        }
    }

    private func mockSearchResults(scope: String, query: String) -> [SearchResult] {
        let seed = mockSearchSeedResults(scope: scope)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return seed }

        let tokens = trimmed
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        guard !tokens.isEmpty else { return seed }

        return seed.filter { result in
            let haystack = (result.name + " " + result.hash)
                .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            return tokens.allSatisfy { haystack.contains($0) }
        }
    }

    private func mockSearchSeedResults(scope: String) -> [SearchResult] {
        let scopeLabel: String
        switch scope.lowercased() {
        case "kad":
            scopeLabel = "Kad"
        case "local":
            scopeLabel = "Local"
        default:
            scopeLabel = "Global"
        }

        func item(
            _ index: Int,
            _ name: String,
            sizeMB: UInt64,
            sources: Int,
            complete: Int,
            statusCode: Int,
            status: String,
            parentID: Int = 0,
            alreadyHave: Bool = false
        ) -> SearchResult {
            SearchResult(
                index: index,
                hash: String(format: "%032X", index * 4099 + 17),
                name: "[\(scopeLabel)] \(name)",
                sizeBytes: sizeMB * 1024 * 1024,
                sources: sources,
                completeSources: complete,
                statusCode: statusCode,
                status: status,
                parentID: parentID,
                alreadyHave: alreadyHave
            )
        }

        return [
            item(100, "Ubuntu 24.04 Desktop ISO", sizeMB: 6144, sources: 132, complete: 41, statusCode: 0, status: "New"),
            item(101, "ubuntu-24.04-desktop-amd64.iso", sizeMB: 6144, sources: 78, complete: 33, statusCode: 2, status: "Queued", parentID: 100),
            item(102, "Ubuntu_24.04_Desktop_x64.iso", sizeMB: 6144, sources: 44, complete: 8, statusCode: 0, status: "New", parentID: 100),

            item(200, "Blender Training Pack 2026", sizeMB: 2048, sources: 51, complete: 12, statusCode: 0, status: "New"),
            item(201, "Blender.Training.Pack.2026.part1.zip", sizeMB: 2048, sources: 22, complete: 4, statusCode: 0, status: "New", parentID: 200),
            item(202, "Blender_Training_Pack_2026.zip", sizeMB: 2048, sources: 19, complete: 5, statusCode: 2, status: "Queued", parentID: 200),
            item(203, "BTP-2026.zip", sizeMB: 2048, sources: 10, complete: 3, statusCode: 1, status: "Downloaded", parentID: 200, alreadyHave: true),

            item(300, "Daft Punk - Alive 2007 (FLAC)", sizeMB: 420, sources: 38, complete: 11, statusCode: 0, status: "New"),
            item(301, "Daft.Punk.Alive.2007.FLAC", sizeMB: 420, sources: 12, complete: 2, statusCode: 4, status: "Queued (Canceled)", parentID: 300),
            item(302, "Daft Punk - Alive 2007 [FLAC].zip", sizeMB: 420, sources: 17, complete: 6, statusCode: 3, status: "Canceled", parentID: 300),

            item(400, "Inception (2010) 1080p BluRay x264", sizeMB: 8192, sources: 26, complete: 7, statusCode: 0, status: "New"),
            item(500, "orphaned child demo (invalid parent id)", sizeMB: 55, sources: 4, complete: 1, statusCode: 0, status: "New", parentID: 9999)
        ]
    }

    private func buildSearchTree(from results: [SearchResult], using sortDescriptors: [NSSortDescriptor]) -> [SearchTreeNode] {
        guard !results.isEmpty else { return [] }

        let byIndex = Dictionary(uniqueKeysWithValues: results.map { ($0.index, $0) })
        let childrenByParent = Dictionary(grouping: results, by: \.parentID)

        var visited = Set<Int>()
        var currentPath = Set<Int>()

        func makeNode(_ result: SearchResult) -> SearchTreeNode {
            guard !currentPath.contains(result.index) else {
                visited.insert(result.index)
                return SearchTreeNode(result: result, children: [])
            }

            currentPath.insert(result.index)
            visited.insert(result.index)

            let childResults = sortSearchResults(
                (childrenByParent[result.index] ?? []).filter { $0.index != result.index },
                using: sortDescriptors
            )
            let childNodes = childResults.map { makeNode($0) }

            currentPath.remove(result.index)
            return SearchTreeNode(result: result, children: childNodes)
        }

        let rootCandidates = sortSearchResults(
            results.filter { $0.parentID == 0 || byIndex[$0.parentID] == nil },
            using: sortDescriptors
        )

        var rootNodes = rootCandidates.map { makeNode($0) }

        let unvisited = sortSearchResults(
            results.filter { !visited.contains($0.index) },
            using: sortDescriptors
        )
        rootNodes.append(contentsOf: unvisited.map { makeNode($0) })

        return rootNodes
    }

    private func sortSearchResults(_ results: [SearchResult], using sortDescriptors: [NSSortDescriptor]) -> [SearchResult] {
        let descriptors = sortDescriptors.isEmpty
            ? [NSSortDescriptor(key: SearchOutlineSortKey.index.rawValue, ascending: true)]
            : sortDescriptors

        return results.sorted { lhs, rhs in
            for descriptor in descriptors {
                guard let keyRaw = descriptor.key,
                      let key = SearchOutlineSortKey(rawValue: keyRaw) else {
                    continue
                }
                let comparison = compareSearchResult(lhs, rhs, by: key)
                if comparison == .orderedSame {
                    continue
                }
                if descriptor.ascending {
                    return comparison == .orderedAscending
                } else {
                    return comparison == .orderedDescending
                }
            }
            return lhs.index < rhs.index
        }
    }

    private func compareSearchResult(_ lhs: SearchResult, _ rhs: SearchResult, by key: SearchOutlineSortKey) -> ComparisonResult {
        switch key {
        case .index:
            if lhs.index == rhs.index { return .orderedSame }
            return lhs.index < rhs.index ? .orderedAscending : .orderedDescending
        case .name:
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        case .sizeBytes:
            if lhs.sizeBytes == rhs.sizeBytes { return .orderedSame }
            return lhs.sizeBytes < rhs.sizeBytes ? .orderedAscending : .orderedDescending
        case .sources:
            if lhs.sources == rhs.sources { return .orderedSame }
            return lhs.sources < rhs.sources ? .orderedAscending : .orderedDescending
        case .completeSources:
            if lhs.completeSources == rhs.completeSources { return .orderedSame }
            return lhs.completeSources < rhs.completeSources ? .orderedAscending : .orderedDescending
        case .statusCode:
            if lhs.statusCode == rhs.statusCode {
                return lhs.status.localizedCaseInsensitiveCompare(rhs.status)
            }
            return lhs.statusCode < rhs.statusCode ? .orderedAscending : .orderedDescending
        case .alreadyHave:
            let lhsValue = lhs.alreadyHave ? 1 : 0
            let rhsValue = rhs.alreadyHave ? 1 : 0
            if lhsValue == rhsValue { return .orderedSame }
            return lhsValue < rhsValue ? .orderedAscending : .orderedDescending
        case .hash:
            return lhs.hash.localizedCaseInsensitiveCompare(rhs.hash)
        }
    }
}

private func searchStatusSymbol(for item: SearchResult) -> String {
    switch item.statusCode {
    case 1:
        return "checkmark.circle"
    case 2:
        return "arrow.down.circle"
    case 3:
        return "xmark.circle"
    case 4:
        return "arrow.down.circle.badge.xmark"
    default:
        return "circle"
    }
}

@MainActor
private struct SearchResultsOutlineView: NSViewRepresentable {
    let nodes: [SearchTreeNode]
    @Binding var selection: Set<SearchResult.ID>
    @Binding var sortDescriptors: [NSSortDescriptor]
    let autosaveName: String

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection, sortDescriptors: $sortDescriptors)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView(frame: .zero)
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true

        let outlineView = NSOutlineView(frame: .zero)
        outlineView.headerView = NSTableHeaderView(
            frame: NSRect(x: 0, y: 0, width: 32, height: 24)
        )
        outlineView.dataSource = context.coordinator
        outlineView.delegate = context.coordinator
        outlineView.allowsMultipleSelection = true
        outlineView.usesAlternatingRowBackgroundColors = true
        outlineView.floatsGroupRows = false
        outlineView.backgroundColor = .clear
        outlineView.selectionHighlightStyle = .regular
        outlineView.columnAutoresizingStyle = .noColumnAutoresizing
        outlineView.focusRingType = .none
        outlineView.autosaveName = autosaveName
        outlineView.autosaveTableColumns = true

        let nameColumn = makeColumn(
            key: .name,
            title: "Name",
            width: 560,
            minWidth: 360,
            maxWidth: 2600
        )
        outlineView.addTableColumn(nameColumn)
        outlineView.outlineTableColumn = nameColumn

        outlineView.addTableColumn(makeColumn(key: .sizeBytes, title: "Size", width: 70, minWidth: 54, maxWidth: 180))
        outlineView.addTableColumn(makeColumn(key: .sources, title: "Src", width: 44, minWidth: 34, maxWidth: 100))
        outlineView.addTableColumn(makeColumn(key: .completeSources, title: "Comp", width: 54, minWidth: 40, maxWidth: 120))
        outlineView.addTableColumn(makeColumn(key: .statusCode, title: "Status", width: 44, minWidth: 34, maxWidth: 88))
        outlineView.addTableColumn(makeColumn(key: .alreadyHave, title: "Have", width: 40, minWidth: 32, maxWidth: 84))
        outlineView.addTableColumn(makeColumn(key: .hash, title: "Hash", width: 300, minWidth: 280, maxWidth: 420))

        outlineView.sortDescriptors = sortDescriptors

        scrollView.documentView = outlineView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let outlineView = scrollView.documentView as? NSOutlineView else { return }
        context.coordinator.selectionBinding = $selection
        context.coordinator.sortDescriptorsBinding = $sortDescriptors

        if !context.coordinator.areSortDescriptorsEqual(outlineView.sortDescriptors, sortDescriptors) {
            outlineView.sortDescriptors = sortDescriptors
        }

        context.coordinator.setNodes(nodes, in: outlineView)
        context.coordinator.applySelection(in: outlineView)
    }

    private func makeColumn(
        key: SearchOutlineSortKey,
        title: String,
        width: CGFloat,
        minWidth: CGFloat,
        maxWidth: CGFloat
    ) -> NSTableColumn {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(key.rawValue))
        column.title = L2(title)
        column.width = width
        column.minWidth = minWidth
        column.maxWidth = maxWidth
        column.sortDescriptorPrototype = NSSortDescriptor(key: key.rawValue, ascending: true)
        return column
    }

    @MainActor
    final class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
        final class NodeRef: NSObject {
            let result: SearchResult
            var children: [NodeRef]

            init(result: SearchResult, children: [NodeRef] = []) {
                self.result = result
                self.children = children
            }
        }

        var selectionBinding: Binding<Set<SearchResult.ID>>
        var sortDescriptorsBinding: Binding<[NSSortDescriptor]>

        private var rootNodes: [NodeRef] = []
        private var nodeByID: [SearchResult.ID: NodeRef] = [:]
        private var parentByID: [SearchResult.ID: SearchResult.ID] = [:]
        private var expandedIDs: Set<SearchResult.ID> = []
        private var isApplyingSelection = false

        init(selection: Binding<Set<SearchResult.ID>>, sortDescriptors: Binding<[NSSortDescriptor]>) {
            self.selectionBinding = selection
            self.sortDescriptorsBinding = sortDescriptors
        }

        func setNodes(_ nodes: [SearchTreeNode], in outlineView: NSOutlineView) {
            var lookup: [SearchResult.ID: NodeRef] = [:]
            var parents: [SearchResult.ID: SearchResult.ID] = [:]

            func mapNode(_ node: SearchTreeNode, parentID: SearchResult.ID?) -> NodeRef {
                let mappedChildren = node.children.map { mapNode($0, parentID: node.result.id) }
                let mapped = NodeRef(result: node.result, children: mappedChildren)
                lookup[node.result.id] = mapped
                if let parentID {
                    parents[node.result.id] = parentID
                }
                return mapped
            }

            rootNodes = nodes.map { mapNode($0, parentID: nil) }
            nodeByID = lookup
            parentByID = parents

            outlineView.reloadData()
            restoreExpandedState(in: outlineView)
        }

        func applySelection(in outlineView: NSOutlineView) {
            let validSelection = selectionBinding.wrappedValue.intersection(Set(nodeByID.keys))
            if validSelection != selectionBinding.wrappedValue {
                selectionBinding.wrappedValue = validSelection
            }

            for selectedID in validSelection {
                expandAncestors(of: selectedID, in: outlineView)
            }

            var selectedRows = IndexSet()
            for selectedID in validSelection {
                guard let node = nodeByID[selectedID] else { continue }
                let row = outlineView.row(forItem: node)
                if row >= 0 {
                    selectedRows.insert(row)
                }
            }

            isApplyingSelection = true
            outlineView.selectRowIndexes(selectedRows, byExtendingSelection: false)
            isApplyingSelection = false
        }

        func areSortDescriptorsEqual(_ lhs: [NSSortDescriptor], _ rhs: [NSSortDescriptor]) -> Bool {
            guard lhs.count == rhs.count else { return false }
            for (left, right) in zip(lhs, rhs) {
                if left.key != right.key || left.ascending != right.ascending {
                    return false
                }
            }
            return true
        }

        private func restoreExpandedState(in outlineView: NSOutlineView) {
            func restore(node: NodeRef) {
                if expandedIDs.contains(node.result.id), !node.children.isEmpty {
                    outlineView.expandItem(node)
                }
                node.children.forEach { restore(node: $0) }
            }
            rootNodes.forEach { restore(node: $0) }
        }

        private func expandAncestors(of nodeID: SearchResult.ID, in outlineView: NSOutlineView) {
            var currentParent = parentByID[nodeID]
            while let parentID = currentParent {
                if let parentNode = nodeByID[parentID] {
                    outlineView.expandItem(parentNode)
                }
                currentParent = parentByID[parentID]
            }
        }

        func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            if let node = item as? NodeRef {
                return node.children.count
            }
            return rootNodes.count
        }

        func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            if let node = item as? NodeRef {
                return node.children[index]
            }
            return rootNodes[index]
        }

        func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
            guard let node = item as? NodeRef else { return false }
            return !node.children.isEmpty
        }

        func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
            guard let node = item as? NodeRef,
                  let tableColumn,
                  let key = SearchOutlineSortKey(rawValue: tableColumn.identifier.rawValue) else {
                return nil
            }

            let result = node.result
            switch key {
            case .index:
                return makeTextCell(
                    in: outlineView,
                    identifier: "search.index",
                    text: String(result.index),
                    alignment: .right,
                    monospaced: true
                )
            case .name:
                return makeTextCell(
                    in: outlineView,
                    identifier: "search.name",
                    text: result.name,
                    alignment: .left,
                    monospaced: false,
                    lineBreakMode: .byTruncatingMiddle
                )
            case .sizeBytes:
                return makeTextCell(in: outlineView, identifier: "search.size", text: result.sizeDisplay, alignment: .right)
            case .sources:
                return makeTextCell(in: outlineView, identifier: "search.src", text: String(result.sources), alignment: .right, monospaced: true)
            case .completeSources:
                return makeTextCell(in: outlineView, identifier: "search.comp", text: String(result.completeSources), alignment: .right, monospaced: true)
            case .statusCode:
                return makeSymbolCell(
                    in: outlineView,
                    identifier: "search.status",
                    symbolName: searchStatusSymbol(for: result),
                    tooltip: result.status
                )
            case .alreadyHave:
                return makeSymbolCell(
                    in: outlineView,
                    identifier: "search.have",
                    symbolName: result.alreadyHave ? "checkmark.circle.fill" : "circle",
                    tooltip: result.alreadyHaveText
                )
            case .hash:
                return makeTextCell(
                    in: outlineView,
                    identifier: "search.hash",
                    text: result.hash,
                    alignment: .left,
                    monospaced: true,
                    lineBreakMode: .byTruncatingMiddle
                )
            }
        }

        func outlineViewSelectionDidChange(_ notification: Notification) {
            guard !isApplyingSelection,
                  let outlineView = notification.object as? NSOutlineView else { return }

            var ids = Set<SearchResult.ID>()
            for row in outlineView.selectedRowIndexes {
                if let node = outlineView.item(atRow: row) as? NodeRef {
                    ids.insert(node.result.id)
                }
            }
            if ids != selectionBinding.wrappedValue {
                selectionBinding.wrappedValue = ids
            }
        }

        func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
            let descriptors = outlineView.sortDescriptors
            if !areSortDescriptorsEqual(descriptors, sortDescriptorsBinding.wrappedValue) {
                sortDescriptorsBinding.wrappedValue = descriptors
            }
        }

        func outlineViewItemDidExpand(_ notification: Notification) {
            guard let node = notification.userInfo?["NSObject"] as? NodeRef else { return }
            expandedIDs.insert(node.result.id)
        }

        func outlineViewItemDidCollapse(_ notification: Notification) {
            guard let node = notification.userInfo?["NSObject"] as? NodeRef else { return }
            expandedIDs.remove(node.result.id)
        }

        private func makeTextCell(
            in outlineView: NSOutlineView,
            identifier: String,
            text: String,
            alignment: NSTextAlignment,
            monospaced: Bool = false,
            lineBreakMode: NSLineBreakMode = .byTruncatingTail
        ) -> NSTableCellView {
            let cellIdentifier = NSUserInterfaceItemIdentifier(identifier)
            let cell: NSTableCellView
            if let reused = outlineView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
                cell = reused
            } else {
                let created = NSTableCellView()
                created.identifier = cellIdentifier

                let textField = NSTextField(labelWithString: "")
                textField.translatesAutoresizingMaskIntoConstraints = false
                textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                created.addSubview(textField)
                created.textField = textField

                NSLayoutConstraint.activate([
                    textField.leadingAnchor.constraint(equalTo: created.leadingAnchor, constant: 4),
                    textField.trailingAnchor.constraint(equalTo: created.trailingAnchor, constant: -4),
                    textField.centerYAnchor.constraint(equalTo: created.centerYAnchor)
                ])

                cell = created
            }

            if let field = cell.textField {
                field.stringValue = text
                field.alignment = alignment
                field.lineBreakMode = lineBreakMode
                field.font = monospaced
                    ? NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
                    : NSFont.systemFont(ofSize: NSFont.systemFontSize)
                field.textColor = .labelColor
            }
            cell.toolTip = text
            return cell
        }

        private func makeSymbolCell(
            in outlineView: NSOutlineView,
            identifier: String,
            symbolName: String,
            tooltip: String
        ) -> NSTableCellView {
            let cellIdentifier = NSUserInterfaceItemIdentifier(identifier)
            let cell: NSTableCellView
            if let reused = outlineView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
                cell = reused
            } else {
                let created = NSTableCellView()
                created.identifier = cellIdentifier

                let imageView = NSImageView()
                imageView.translatesAutoresizingMaskIntoConstraints = false
                imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
                imageView.contentTintColor = .secondaryLabelColor
                imageView.imageScaling = .scaleProportionallyDown
                created.addSubview(imageView)
                created.imageView = imageView

                NSLayoutConstraint.activate([
                    imageView.centerXAnchor.constraint(equalTo: created.centerXAnchor),
                    imageView.centerYAnchor.constraint(equalTo: created.centerYAnchor)
                ])

                cell = created
            }

            cell.imageView?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
            cell.toolTip = tooltip
            return cell
        }
    }
}

struct AddLinksWindowView: View {
    @EnvironmentObject private var model: AppModel
    @State private var linksDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add eD2k Links")
                .font(.headline)

            Text("Paste one link per line (ed2k:// or magnet:? links).")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $linksDraft)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Button("Clear") {
                    linksDraft = ""
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Start Download") {
                    model.addLinks(linksDraft)
                }
                .buttonStyle(.borderedProminent)
                .disabled(linksDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isBusy)
            }
        }
        .padding(14)
        .frame(minWidth: 520, idealWidth: 560, maxWidth: 700, minHeight: 280, idealHeight: 320)
        .background(GlassEffectBackground(material: .underWindowBackground))
        .background(
            WindowAppearanceConfigurator(
                hideTitle: true,
                transparentTitlebar: true,
                fullSizeContentView: true,
                toolbarStyle: .automatic,
                makeWindowTransparent: true,
                ensureToolbarWhenTransparentTitlebar: false,
                windowLevel: .floating,
                windowCollectionBehavior: [.fullScreenAuxiliary, .moveToActiveSpace],
                isMovableByWindowBackground: true,
                panelHidesOnDeactivate: false,
                useUtilityStyleMask: true,
                isResizable: false,
                hidesStandardWindowButtons: true
            )
        )
    }
}

struct DownloadDetailsWindowView: View {
    @EnvironmentObject private var model: AppModel

    @State private var sourceSortOrder = [KeyPathComparator(\DownloadSourceItem.clientName, order: .forward)]
    @State private var downloadRenameDraft: String = ""
    @State private var isEditingDownloadName = false

    private var selectedDownload: DownloadItem? {
        guard let selectedDownloadID = model.selectedDownloadID else { return nil }
        return model.downloads.first(where: { $0.id == selectedDownloadID })
    }

    private var selectedDownloadSources: [DownloadSourceItem] {
        model.sources(for: selectedDownload).sorted(using: sourceSortOrder)
    }

    private var canRenameSelectedDownload: Bool {
        guard let item = selectedDownload else { return false }
        return !item.isCompletedLike
    }

    private var sourcesTableHeight: CGFloat {
        let rowHeight: CGFloat = 28
        let headerHeight: CGFloat = 30
        let clampedRows = max(1, min(selectedDownloadSources.count, 5))
        if selectedDownloadSources.count <= 5 {
            return headerHeight + rowHeight * CGFloat(clampedRows) + 4
        }
        return 230
    }

    var body: some View {
        VStack(spacing: 12) {
            if let item = selectedDownload {
                VStack(alignment: .leading, spacing: 12) {
                    if isEditingDownloadName && canRenameSelectedDownload {
                        HStack(spacing: 8) {
                            TextField("New file name", text: $downloadRenameDraft)
                                .textFieldStyle(.roundedBorder)
                            Button("Apply") {
                                model.renameDownload(item, to: downloadRenameDraft)
                                isEditingDownloadName = false
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(
                                model.isBusy ||
                                downloadRenameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                downloadRenameDraft == item.name
                            )
                            Button("Cancel") {
                                downloadRenameDraft = item.name
                                isEditingDownloadName = false
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.isBusy)
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(item.name)
                                .font(.title3)
                                .lineLimit(2)
                                .truncationMode(.middle)
                            Spacer()
                            if canRenameSelectedDownload {
                                Button("Edit") {
                                    downloadRenameDraft = item.name
                                    isEditingDownloadName = true
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(model.isBusy)
                            }
                        }
                    }

                    Text(item.id)
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        DownloadSegmentedProgressBar(
                            colors: item.progressColors,
                            fallbackProgress: item.progressDisplayValue / 100.0
                        )
                        Text(LF2("Progress: %@", item.progressText))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    HStack(spacing: 10) {
                        Text(item.ed2kLink)
                            .font(.callout.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                        Button("Copy") {
                            model.copyDownloadLinkToClipboard(item)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 22) {
                            VStack(alignment: .leading, spacing: 8) {
                                detailRowLarge("Completed", item.completionText)
                                detailRowLarge("Transferred", item.transferredText)
                                detailRowLarge("Sources", item.sourcesText)
                                detailRowLarge("Priority", item.priorityText)
                                detailRowLarge("Category", String(item.category))
                                detailRowLarge("Part File", item.partMetName.isEmpty ? "-" : item.partMetName)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            VStack(alignment: .leading, spacing: 8) {
                                detailRowLarge("Transferring", String(item.sourceTransferring))
                                detailRowLarge("A4AF", String(item.sourceA4AF))
                                detailRowLarge("Available Parts", String(item.availableParts))
                                detailRowLarge("Active Time", item.activeTimeText)
                                detailRowLarge("Last Seen Complete", item.lastSeenCompleteText)
                                detailRowLarge("Last Received", item.lastReceivedText)
                                detailRowLarge("Shared", item.shared ? L2("Yes") : L2("No"))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if !item.alternativeNames.isEmpty {
                            Divider()
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Alternative Names")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                ForEach(item.alternativeNames.sorted(by: { $0.count > $1.count })) { alt in
                                    HStack(spacing: 10) {
                                        Text(alt.name)
                                            .font(.body)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer()
                                        Text("x\(alt.count)")
                                            .font(.body)
                                            .foregroundStyle(.secondary)
                                        if canRenameSelectedDownload {
                                            Button("Use") {
                                                downloadRenameDraft = alt.name
                                                isEditingDownloadName = true
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                        }
                                    }
                                }
                            }
                        }

                        Divider()

                        HStack {
                            Text("Sources")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if model.isRefreshingSources {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Button("Refresh") {
                                model.refreshDownloadSources(for: item)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(model.isRefreshingSources)
                        }

                        if selectedDownloadSources.isEmpty {
                            Text("No sources available yet.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                        } else {
                            Table(selectedDownloadSources, sortOrder: $sourceSortOrder) {
                                TableColumn("Client", value: \.clientName) { source in
                                    Text(source.clientDisplayName)
                                }
                                .width(min: 160, ideal: 220, max: 360)

                                TableColumn("Endpoint", value: \.userIP) { source in
                                    Text(source.endpoint)
                                        .font(.system(.body, design: .monospaced))
                                }
                                .width(min: 130, ideal: 160, max: 250)

                                TableColumn("Software", value: \.softwareVersion) { source in
                                    Text(source.softwareDisplay)
                                        .lineLimit(1)
                                }
                                .width(min: 120, ideal: 170, max: 260)

                                TableColumn("State", value: \.downloadStateText) { source in
                                    Text(source.downloadStateText)
                                }
                                .width(min: 130, ideal: 160, max: 260)

                                TableColumn("Speed", value: \.downSpeedKBps) { source in
                                    Text(source.speedText)
                                }
                                .width(min: 90, ideal: 110, max: 180)

                                TableColumn("Avail", value: \.availableParts) { source in
                                    Text(String(source.availableParts))
                                }
                                .width(min: 60, ideal: 80, max: 110)

                                TableColumn("Queue", value: \.remoteQueueRank) { source in
                                    Text(source.queueRankText)
                                }
                                .width(min: 70, ideal: 82, max: 120)

                                TableColumn("From", value: \.sourceFromText) { source in
                                    Text(source.sourceFromText)
                                }
                                .width(min: 110, ideal: 140, max: 210)

                                TableColumn("Server", value: \.serverName) { source in
                                    Text(source.serverEndpoint)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                .width(min: 170, ideal: 240, max: 360)

                                TableColumn("Remote Name", value: \.remoteFilename) { source in
                                    Text(source.remoteFilename.isEmpty ? "-" : source.remoteFilename)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                .width(min: 220, ideal: 340, max: 520)
                            }
                            .frame(height: sourcesTableHeight)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Select a download item in the Downloads window first.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .padding(14)
        .frame(width: 820, alignment: .topLeading)
        .frame(minHeight: 180, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            GlassEffectBackground(material: .underWindowBackground)
                .ignoresSafeArea()
        )
        .background(
            WindowAppearanceConfigurator(
                hideTitle: true,
                transparentTitlebar: true,
                fullSizeContentView: true,
                toolbarStyle: .automatic,
                showsToolbarBaselineSeparator: false,
                makeWindowTransparent: true,
                ensureToolbarWhenTransparentTitlebar: false,
                forceNoToolbar: true
            )
        )
        .onAppear {
            syncSelectionState()
        }
        .onChange(of: model.selectedDownloadID) { _, _ in
            syncSelectionState()
        }
        .onChange(of: model.downloads) {
            syncSelectionState()
        }
    }

    private func syncSelectionState() {
        guard let selectedDownload else {
            downloadRenameDraft = ""
            isEditingDownloadName = false
            return
        }
        if !isEditingDownloadName || downloadRenameDraft.isEmpty {
            downloadRenameDraft = selectedDownload.name
        }
        if !canRenameSelectedDownload {
            isEditingDownloadName = false
        }
        model.refreshDownloadSources(for: selectedDownload)
    }

    private func detailRowLarge(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(L2(title) + ":")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 145, alignment: .leading)
            Text(value)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ServersWindowView: View {
    @EnvironmentObject private var model: AppModel

    @State private var serverSortOrder = [
        KeyPathComparator(\ServerItem.files, order: .reverse),
        KeyPathComparator(\ServerItem.name, order: .forward)
    ]
    @State private var displayedServers: [ServerItem] = []
    @State private var selectedServerID: ServerItem.ID? = nil
    @State private var showingAddServerSheet = false
    @State private var showingImportServerMetSheet = false

    private var selectedServer: ServerItem? {
        guard let selectedServerID else { return nil }
        return displayedServers.first(where: { $0.id == selectedServerID })
    }

    @ToolbarContentBuilder
    private var serversToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            ControlGroup {
                Button {
                    showingAddServerSheet = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .help("Add Server")
                .disabled(model.isBusy)

                Button {
                    model.refreshServers()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh Servers")
                .disabled(model.isBusy)

                Button {
                    if let selectedServer {
                        model.removeServer(selectedServer)
                    }
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .help("Remove Selected Server")
                .disabled(model.isBusy || selectedServer == nil)
            }
            .controlGroupStyle(.navigation)
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                showingImportServerMetSheet = true
            } label: {
                Label("Import .met", systemImage: "arrow.down.circle")
            }
            .help("Import server list from URL")
            .disabled(model.isBusy)
        }

        ToolbarItem(placement: .primaryAction) {
            ControlGroup {
                Button {
                    model.connectServer(selectedServer)
                } label: {
                    Label("Connect", systemImage: "link")
                }
                .help("Connect Selected Server")
                .disabled(model.isBusy || selectedServer == nil)

                Button {
                    model.disconnectServer()
                } label: {
                    Label("Disconnect", systemImage: "minus.circle")
                }
                .help("Disconnect Current Server")
                .disabled(model.isBusy)
            }
            .controlGroupStyle(.navigation)
        }
    }

    var body: some View {
        baseServersContent
            .frame(minWidth: 1040, minHeight: 620)
            .background(
                GlassEffectBackground(material: .underWindowBackground)
                    .ignoresSafeArea()
            )
            .background(
                WindowAppearanceConfigurator(
                    windowTitle: "eD2k",
                    hideTitle: false,
                    transparentTitlebar: true,
                    fullSizeContentView: true,
                    toolbarStyle: .automatic,
                    makeWindowTransparent: true,
                    ensureToolbarWhenTransparentTitlebar: false
                )
            )
    }

    private var baseServersContent: some View {
        VStack(spacing: 0) {
            Table(displayedServers, selection: $selectedServerID, sortOrder: $serverSortOrder) {
                TableColumn("Name", value: \.name) { item in
                    HStack(spacing: 6) {
                        if isConnectedServer(item) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .help("Connected Server")
                        }
                        Text(item.name.isEmpty ? L2("(unnamed)") : item.name)
                            .fontWeight(isConnectedServer(item) ? .semibold : .regular)
                    }
                        .contextMenu { serverContextMenu(item) }
                }
                .width(min: 180, ideal: 220, max: 420)

                TableColumn("Address", value: \.endpointText) { item in
                    Text(item.endpointText)
                        .contextMenu { serverContextMenu(item) }
                }
                .width(170)

                TableColumn("Users", value: \.users) { item in
                    Text(item.usersText)
                        .contextMenu { serverContextMenu(item) }
                }
                .width(95)

                TableColumn("Files", value: \.files) { item in
                    Text(String(item.files))
                        .contextMenu { serverContextMenu(item) }
                }
                .width(90)

                TableColumn("Ping", value: \.ping) { item in
                    Text(item.ping > 0 ? "\(item.ping) ms" : "-")
                        .contextMenu { serverContextMenu(item) }
                }
                .width(90)

                TableColumn("Failed", value: \.failed) { item in
                    Text(String(item.failed))
                        .contextMenu { serverContextMenu(item) }
                }
                .width(75)

                TableColumn("Version", value: \.version) { item in
                    Text(item.version)
                        .contextMenu { serverContextMenu(item) }
                }
                .width(90)

                TableColumn("Prio", value: \.priority) { item in
                    Text(String(item.priority))
                        .contextMenu { serverContextMenu(item) }
                }
                .width(70)

                TableColumn("Static") { item in
                    Text(item.isStatic ? L2("Yes") : L2("No"))
                        .contextMenu { serverContextMenu(item) }
                }
                .width(70)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollContentBackground(.hidden)
            .background(
                ServersTableAutosaveConfigurator(
                    autosaveName: "AMuleNativeRemote.ServersTable"
                )
            )

            Divider()
            HStack(spacing: 8) {
                if let selectedServer {
                    Text("Description:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(selectedServer.description.isEmpty ? "-" : selectedServer.description)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer()
                Text(localizedED2kStatusSummary2(model.status.ed2k))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(LF2("%lld server(s)", Int64(displayedServers.count)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .toolbar { serversToolbar }
        .task {
            refreshDisplayedServers()
            model.refreshServers()
        }
        .onChange(of: model.servers) {
            refreshDisplayedServers()
        }
        .onChange(of: serverSortOrder) {
            refreshDisplayedServers()
        }
        .onChange(of: model.status.ed2k) {
            refreshDisplayedServers()
        }
        .sheet(isPresented: $showingAddServerSheet) {
            AddServerSheetView(isBusy: model.isBusy) { address, name in
                model.serverAddressInput = address
                model.serverNameInput = name
                model.addServer()
                showingAddServerSheet = false
            }
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showingImportServerMetSheet) {
            ImportServerMetSheetView(isBusy: model.isBusy) { url in
                model.updateServerListFromURL(url)
                showingImportServerMetSheet = false
            }
            .presentationDetents([.height(200)])
            .presentationDragIndicator(.hidden)
        }
    }

    @ViewBuilder
    private func serverContextMenu(_ item: ServerItem) -> some View {
        Button("Connect") {
            model.connectServer(item)
        }
        Button("Remove") {
            model.removeServer(item)
        }
    }

    private func refreshDisplayedServers() {
        var sorted = model.servers.sorted(using: serverSortOrder)
        let connected = sorted.filter(isConnectedServer)
        if !connected.isEmpty {
            let others = sorted.filter { !isConnectedServer($0) }
            sorted = connected + others
        }
        displayedServers = sorted
        if let selectedServerID,
           !displayedServers.contains(where: { $0.id == selectedServerID }) {
            self.selectedServerID = nil
        }
    }

    private func isConnectedServer(_ server: ServerItem) -> Bool {
        guard let endpoint = currentConnectedServerEndpoint else { return false }
        return server.ip == endpoint.ip && server.port == endpoint.port
    }

    private var currentConnectedServerEndpoint: (ip: String, port: Int)? {
        let text = model.status.ed2k.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        // Extract the first IPv4:port endpoint from eD2k status text, e.g.
        // "Connected to Foo [1.2.3.4:4661] LowID".
        guard let range = text.range(
            of: #"\b([0-9]{1,3}(?:\.[0-9]{1,3}){3}):([0-9]{1,5})\b"#,
            options: .regularExpression
        ) else {
            return nil
        }

        let endpoint = String(text[range])
        let parts = endpoint.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let port = Int(parts[1]) else { return nil }
        return (ip: parts[0], port: port)
    }
}

private struct AddServerSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let isBusy: Bool
    let onAdd: (_ address: String, _ name: String) -> Void

    @State private var address: String = ""
    @State private var name: String = ""

    private var trimmedAddress: String {
        address.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Server")
                .font(.headline)

            TextField("Server address (IP:Port)", text: $address)
                .textFieldStyle(.roundedBorder)

            TextField("Name (optional)", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Add Server") {
                    onAdd(trimmedAddress, trimmedName)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy || trimmedAddress.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 440)
    }
}

private struct ImportServerMetSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let isBusy: Bool
    let onAdd: (_ url: String) -> Void

    @State private var url: String = ""

    private var trimmedURL: String {
        url.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import Server List")
                .font(.headline)

            TextField("http://example.com/server.met", text: $url)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Add") {
                    onAdd(trimmedURL)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy || trimmedURL.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 520)
    }
}

struct DiagnosticsWindowView: View {
    @EnvironmentObject private var model: AppModel

    private enum DiagnosticsTab: String, CaseIterable {
        case log = "Log"
        case downloads = "Raw DL"
        case sources = "Raw Src"
        case search = "Raw Search"
        case servers = "Raw Servers"
        case coreLog = "Core Log"
        case coreDebugLog = "Core Debug"

        var localizedTitle: String { L2(rawValue) }
    }

    @State private var diagnosticsTab: DiagnosticsTab = .log

    private var availableTabs: [DiagnosticsTab] {
        var tabs: [DiagnosticsTab] = [.log, .downloads, .sources, .search, .servers]
        if model.isBridgeOpSupported("log") {
            tabs.append(.coreLog)
        }
        if model.isBridgeOpSupported("debug-log") {
            tabs.append(.coreDebugLog)
        }
        return tabs
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Picker("Diagnostics", selection: $diagnosticsTab) {
                        ForEach(availableTabs, id: \.self) { tab in
                            Text(tab.localizedTitle).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 460)

                    Spacer()

                    Button("Copy") {
                        copyCurrentDiagnostics()
                    }
                    .buttonStyle(.bordered)

                    if diagnosticsTab == .log {
                        Button("Clear Log") {
                            model.resetLog()
                        }
                        .buttonStyle(.bordered)
                    }

                    if diagnosticsTab == .coreLog {
                        Button("Refresh") {
                            model.refreshCoreLog()
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.isBusy || !model.isBridgeOpSupported("log"))
                    }

                    if diagnosticsTab == .coreDebugLog {
                        Button("Refresh") {
                            model.refreshCoreDebugLog()
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.isBusy || !model.isBridgeOpSupported("debug-log"))
                    }
                }

                ScrollView {
                    Text(currentDiagnosticsText)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(14)
            .padding(.top, proxy.safeAreaInsets.top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(minWidth: 920, minHeight: 520)
        .background(GlassEffectBackground(material: .underWindowBackground))
        .background(
            WindowAppearanceConfigurator(
                hideTitle: false,
                transparentTitlebar: true,
                fullSizeContentView: true,
                toolbarStyle: .unified,
                makeWindowTransparent: true,
                ensureToolbarWhenTransparentTitlebar: true
            )
        )
        .onAppear {
            if !availableTabs.contains(diagnosticsTab), let first = availableTabs.first {
                diagnosticsTab = first
            }
        }
        .onChange(of: model.bridgeOps) {
            if !availableTabs.contains(diagnosticsTab), let first = availableTabs.first {
                diagnosticsTab = first
            }
        }
    }

    private var currentDiagnosticsText: String {
        switch diagnosticsTab {
        case .log:
            return model.outputLog.isEmpty ? L2("No command output yet.") : model.outputLog
        case .downloads:
            return model.lastDownloadsRawOutput.isEmpty ? L2("No raw download queue output captured yet.") : model.lastDownloadsRawOutput
        case .sources:
            return model.lastSourcesRawOutput.isEmpty ? L2("No raw source output captured yet.") : model.lastSourcesRawOutput
        case .search:
            return model.lastSearchRawOutput.isEmpty ? L2("No raw search output captured yet.") : model.lastSearchRawOutput
        case .servers:
            return model.lastServersRawOutput.isEmpty ? L2("No raw server-list output captured yet.") : model.lastServersRawOutput
        case .coreLog:
            return model.coreLogLines.isEmpty ? L2("No core log lines captured yet.") : model.coreLogLines.joined(separator: "\n")
        case .coreDebugLog:
            return model.coreDebugLogLines.isEmpty ? L2("No core debug log lines captured yet.") : model.coreDebugLogLines.joined(separator: "\n")
        }
    }

    private func copyCurrentDiagnostics() {
        switch diagnosticsTab {
        case .log:
            model.copyLogToClipboard()
        case .downloads:
            model.copyDownloadsRawToClipboard()
        case .sources:
            model.copySourcesRawToClipboard()
        case .search:
            model.copySearchRawToClipboard()
        case .servers:
            model.copyServersRawToClipboard()
        case .coreLog:
            model.copyCoreLogRawToClipboard()
        case .coreDebugLog:
            model.copyCoreDebugLogRawToClipboard()
        }
    }
}

struct UploadsWindowView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    model.refreshUploads()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy || !model.isBridgeOpSupported("uploads"))

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if !model.isBridgeOpSupported("uploads") {
                Text("Uploads are unsupported by this bridge.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(18)
            } else if model.uploads.isEmpty {
                Text("No active uploads.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(18)
            } else {
                List(model.uploads, id: \.clientID) { upload in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(upload.clientName.isEmpty ? "Client \(upload.clientID)" : upload.clientName)
                                .font(.headline)
                            Spacer()
                            Text("↑ \(upload.speedUp)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(upload.userIP):\(upload.userPort)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 760, minHeight: 500)
        .background(GlassEffectBackground(material: .underWindowBackground).ignoresSafeArea())
        .background(
            WindowAppearanceConfigurator(
                windowTitle: "Uploads",
                hideTitle: false,
                transparentTitlebar: true,
                fullSizeContentView: true,
                toolbarStyle: .automatic,
                makeWindowTransparent: true,
                ensureToolbarWhenTransparentTitlebar: false
            )
        )
        .task { model.refreshUploads() }
    }
}

struct SharedFilesWindowView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    model.refreshSharedFiles()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy || !model.isBridgeOpSupported("shared-files"))

                Button("Reload") {
                    model.reloadSharedFiles()
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy || !model.isBridgeOpSupported("shared-files-reload"))

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if !model.isBridgeOpSupported("shared-files") {
                Text("Shared files are unsupported by this bridge.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(18)
            } else if model.sharedFiles.isEmpty {
                Text("No shared files available.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(18)
            } else {
                List(model.sharedFiles, id: \.hash) { file in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(file.name)
                            .font(.headline)
                        Text(file.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 760, minHeight: 500)
        .background(GlassEffectBackground(material: .underWindowBackground).ignoresSafeArea())
        .background(
            WindowAppearanceConfigurator(
                windowTitle: "Shared Files",
                hideTitle: false,
                transparentTitlebar: true,
                fullSizeContentView: true,
                toolbarStyle: .automatic,
                makeWindowTransparent: true,
                ensureToolbarWhenTransparentTitlebar: false
            )
        )
        .task { model.refreshSharedFiles() }
    }
}

struct CategoriesWindowView: View {
    @EnvironmentObject private var model: AppModel
    @State private var newCategoryName = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    model.refreshCategories()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy || !model.isBridgeOpSupported("categories"))

                TextField("New category name", text: $newCategoryName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 280)

                Button("Create") {
                    model.createCategory(name: newCategoryName, path: "", comment: "", color: 0, priority: 0)
                    newCategoryName = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy || !model.isBridgeOpSupported("category-create"))

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if !model.isBridgeOpSupported("categories") {
                Text("Categories are unsupported by this bridge.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(18)
            } else if model.categories.isEmpty {
                Text("No categories available.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(18)
            } else {
                List(model.categories, id: \.id) { category in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.title.isEmpty ? "Category \(category.id)" : category.title)
                                .font(.headline)
                            Text("ID: \(category.id)  Priority: \(category.priority)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Delete") {
                            model.deleteCategory(id: category.id)
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.isBusy || !model.isBridgeOpSupported("category-delete"))
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 700, minHeight: 460)
        .background(GlassEffectBackground(material: .underWindowBackground).ignoresSafeArea())
        .background(
            WindowAppearanceConfigurator(
                windowTitle: "Categories",
                hideTitle: false,
                transparentTitlebar: true,
                fullSizeContentView: true,
                toolbarStyle: .automatic,
                makeWindowTransparent: true,
                ensureToolbarWhenTransparentTitlebar: false
            )
        )
        .task { model.refreshCategories() }
    }
}

struct FriendsWindowView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    model.refreshFriends()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy || !model.isBridgeOpSupported("friends"))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if !model.isBridgeOpSupported("friends") {
                Text("Friends are unsupported by this bridge.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(18)
            } else if model.friends.isEmpty {
                Text("No friends available.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(18)
            } else {
                List(model.friends, id: \.id) { friend in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(friend.name.isEmpty ? "Friend \(friend.id)" : friend.name)
                                .font(.headline)
                            Spacer()
                            Text("\(friend.ip):\(friend.port)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Toggle("Friend Slot", isOn: Binding(
                                get: { friend.friendSlot },
                                set: { enabled in model.setFriendSlot(id: friend.id, enabled: enabled) }
                            ))
                            .toggleStyle(.switch)
                            .disabled(model.isBusy || !model.isBridgeOpSupported("friend-slot"))

                            Spacer()
                            Button("Remove") {
                                model.removeFriend(id: friend.id)
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.isBusy || !model.isBridgeOpSupported("friend-remove"))
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 760, minHeight: 500)
        .background(GlassEffectBackground(material: .underWindowBackground).ignoresSafeArea())
        .background(
            WindowAppearanceConfigurator(
                windowTitle: "Friends",
                hideTitle: false,
                transparentTitlebar: true,
                fullSizeContentView: true,
                toolbarStyle: .automatic,
                makeWindowTransparent: true,
                ensureToolbarWhenTransparentTitlebar: false
            )
        )
        .task { model.refreshFriends() }
    }
}

struct StatsWindowView: View {
    @EnvironmentObject private var model: AppModel
    @State private var widthInput = "480"
    @State private var scaleInput = "1"

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    model.refreshStatsTree()
                } label: {
                    Label("Refresh Tree", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy || !model.isBridgeOpSupported("stats-tree"))

                TextField("Width", text: $widthInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                TextField("Scale", text: $scaleInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)

                Button("Refresh Graphs") {
                    let width = Int(widthInput) ?? 480
                    let scale = Int(scaleInput) ?? 1
                    model.refreshStatsGraphs(width: max(1, width), scale: max(1, scale))
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy || !model.isBridgeOpSupported("stats-graphs"))

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let tree = model.statsTree {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Stats Tree")
                                .font(.headline)
                            ForEach(flatten(tree: tree), id: \.self) { line in
                                Text(line)
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }
                    }

                    if let graphs = model.statsGraphs {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Stats Graphs (\(graphs.samples.count) samples)")
                                .font(.headline)
                            Text("Last: \(graphs.last)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(Array(graphs.samples.enumerated()), id: \.offset) { _, sample in
                                Text("dl=\(sample.dl) ul=\(sample.ul) conn=\(sample.connections) kad=\(sample.kad)")
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
        }
        .frame(minWidth: 780, minHeight: 520)
        .background(GlassEffectBackground(material: .underWindowBackground).ignoresSafeArea())
        .background(
            WindowAppearanceConfigurator(
                windowTitle: "Statistics",
                hideTitle: false,
                transparentTitlebar: true,
                fullSizeContentView: true,
                toolbarStyle: .automatic,
                makeWindowTransparent: true,
                ensureToolbarWhenTransparentTitlebar: false
            )
        )
        .task {
            model.refreshStatsTree()
            model.refreshStatsGraphs()
        }
    }

    private func flatten(tree: BridgeStatsTreeNodePayload, depth: Int = 0) -> [String] {
        let indent = String(repeating: "  ", count: depth)
        var lines = ["\(indent)- \(tree.label): \(tree.value)"]
        for child in tree.children {
            lines.append(contentsOf: flatten(tree: child, depth: depth + 1))
        }
        return lines
    }
}

struct PreferencesWindowView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    model.refreshConnectionPrefs()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy || !model.isBridgeOpSupported("prefs-connection-get"))

                Spacer()
                if model.isBusy {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            Form {
                Section("Connection Speed Limits") {
                    VStack(alignment: .leading, spacing: 14) {
                        limitField(
                            title: "Download",
                            text: $model.connectionMaxDownloadInput,
                            value: model.connectionMaxDownloadKBps,
                            placeholder: "0"
                        )
                        limitField(
                            title: "Upload",
                            text: $model.connectionMaxUploadInput,
                            value: model.connectionMaxUploadKBps,
                            placeholder: "0"
                        )
                        Text("Values are in KiB/s. Use 0 for unlimited speed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                Section("IP Filter") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("https://example.com/ipfilter.dat", text: $model.ipFilterURLInput)
                            .textFieldStyle(.roundedBorder)
                            .disabled(model.isBusy || !model.isBridgeOpSupported("ipfilter-update"))

                        HStack(spacing: 10) {
                            Button("Update") {
                                model.updateIpFilterFromURL(model.ipFilterURLInput)
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.isBusy || !model.isBridgeOpSupported("ipfilter-update"))

                            Button("Reload") {
                                model.reloadIpFilter()
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.isBusy || !model.isBridgeOpSupported("ipfilter-reload"))
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Apply") {
                    model.setConnectionSpeedLimits(
                        maxDL: model.connectionMaxDownloadInput,
                        maxUL: model.connectionMaxUploadInput
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy || !model.isBridgeOpSupported("prefs-connection-set"))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(minWidth: 640, minHeight: 420)
        .background(GlassEffectBackground(material: .underWindowBackground).ignoresSafeArea())
        .background(
            WindowAppearanceConfigurator(
                windowTitle: "Preferences",
                hideTitle: false,
                transparentTitlebar: true,
                fullSizeContentView: true,
                toolbarStyle: .automatic,
                makeWindowTransparent: true,
                ensureToolbarWhenTransparentTitlebar: false
            )
        )
        .task {
            if model.isBridgeOpSupported("prefs-connection-get") {
                model.refreshConnectionPrefs()
            }
        }
    }

    private func limitField(title: String, text: Binding<String>, value: Int, placeholder: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .frame(width: 96, alignment: .leading)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 180)
            Text("KiB/s")
                .foregroundStyle(.secondary)
            Spacer()
            Text("Current: \(value)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ServersTableAutosaveConfigurator: NSViewRepresentable {
    let autosaveName: String

    final class HostView: NSView {
        var autosaveName: String = ""

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
        }

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            apply()
        }

        override func layout() {
            super.layout()
            apply()
        }

        func apply() {
            DispatchQueue.main.async { [weak self] in
                guard let self, let tableView = self.findNearestTableView() else { return }
                tableView.autosaveName = self.autosaveName
                tableView.autosaveTableColumns = true
            }
        }

        private func findNearestTableView() -> NSTableView? {
            var ancestor: NSView? = self
            while let current = ancestor {
                if let tableView = current.subviews.compactMap({ self.findTableView(in: $0) }).first {
                    return tableView
                }
                ancestor = current.superview
            }
            return nil
        }

        private func findTableView(in view: NSView) -> NSTableView? {
            if let table = view as? NSTableView {
                return table
            }
            for subview in view.subviews {
                if let table = findTableView(in: subview) {
                    return table
                }
            }
            return nil
        }
    }

    func makeNSView(context: Context) -> HostView {
        let view = HostView(frame: .zero)
        view.isHidden = true
        view.autosaveName = autosaveName
        return view
    }

    func updateNSView(_ nsView: HostView, context: Context) {
        nsView.autosaveName = autosaveName
        nsView.apply()
    }
}
