import SwiftUI
import AppKit

private func L2SearchRow(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

enum SearchOutlineSortKey: String {
    case index
    case name
    case sizeBytes
    case sources
    case completeSources
    case statusCode
    case alreadyHave
    case hash
}

struct SearchTreeNode: Identifiable, Hashable {
    let result: SearchResult
    var children: [SearchTreeNode]

    var id: SearchResult.ID { result.id }
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
struct SearchResultsOutlineView: NSViewRepresentable {
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
        column.title = L2SearchRow(title)
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
