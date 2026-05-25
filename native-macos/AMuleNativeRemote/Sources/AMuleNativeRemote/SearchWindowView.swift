import SwiftUI
import AppKit
import SharedUI

private func L2(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func LF2(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), locale: .current, arguments: args)
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
