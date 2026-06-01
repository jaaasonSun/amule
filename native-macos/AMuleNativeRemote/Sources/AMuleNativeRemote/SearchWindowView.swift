import SwiftUI
import AppKit
import SharedUI
import SharedCore

private func L2(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func LF2(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), locale: .current, arguments: args)
}

struct SearchWindowView: View {
    @EnvironmentObject private var model: AppModel

    let embeddedInMainWindow: Bool

    init(embeddedInMainWindow: Bool = false) {
        self.embeddedInMainWindow = embeddedInMainWindow
    }

    @State private var searchSortDescriptors = [
        NSSortDescriptor(key: SearchOutlineSortKey.index.rawValue, ascending: true)
    ]
    @State private var displayedSearchResults: [SearchResult] = []
    @State private var selectedSearchResultIDs: Set<SearchResult.ID> = []

    private var selectedSearchResults: [SearchResult] {
        displayedSearchResults.filter { selectedSearchResultIDs.contains($0.id) }
    }

    private var searchTree: [SearchTreeNode] {
        buildSearchTree(from: displayedSearchResults, using: searchSortDescriptors)
    }

    private var searchOutlineAutosaveName: String {
        return embeddedInMainWindow
            ? "AMuleNativeRemote.SearchOutline.Main"
            : "AMuleNativeRemote.SearchOutline.Window"
    }

    private var activeSearchScopeValue: String {
        model.searchScope
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
        return $model.searchQuery
    }

    private var isSearchInProgressForUI: Bool {
        model.isSearchInProgress
    }

    private var canDownloadSelectedSearchResults: Bool {
        !selectedSearchResults.isEmpty && !model.isBusy
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
                    model.downloadResults(selectedSearchResults)
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                }
                .help("Download Selected")
                .disabled(!canDownloadSelectedSearchResults)

                Button {
                    model.stopSearch()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .help("Stop Search")
                .disabled(!isSearchInProgressForUI)

                SearchScopePicker(
                    activeScopeValue: activeSearchScopeValue,
                    label: searchScopeMenuLabel,
                    setSearchScope: setSearchScope
                )
                .help("Search Scope")
            }
        }
        .searchable(
            text: searchQueryBinding,
            placement: .toolbar,
            prompt: Text(searchToolbarPlaceholder)
        )
        .onSubmit(of: .search) {
            model.performSearch()
        }
        .task {
            refreshDisplayedSearchResults()
        }
        .onChange(of: model.searchResults) {
            refreshDisplayedSearchResults()
        }
    }

    private func refreshDisplayedSearchResults() {
        displayedSearchResults = model.searchResults
        let validIDs = Set(displayedSearchResults.map(\.id))
        selectedSearchResultIDs = selectedSearchResultIDs.intersection(validIDs)
    }

    private func setSearchScope(_ scope: String) {
        model.searchScope = scope
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
