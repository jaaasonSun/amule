import SwiftUI
import AppKit
import SharedViews
import SharedModels
import SharedServices

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
    @State private var showsAdvancedSearchOptions = false

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

    private var isSearchSupported: Bool {
        model.isBridgeOpSupported("search")
    }

    var body: some View {
        if embeddedInMainWindow {
            baseSearchContent
        } else {
            baseSearchContent
                .frame(minWidth: 920, minHeight: 320)
        }
    }

    private var baseSearchContent: some View {
        VStack(spacing: 0) {
            advancedSearchOptions

            SearchResultsOutlineView(
                nodes: searchTree,
                selection: $selectedSearchResultIDs,
                sortDescriptors: $searchSortDescriptors,
                autosaveName: searchOutlineAutosaveName
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    model.downloadResults(selectedSearchResults)
                } label: {
                    Label(L2("Download"), systemImage: "arrow.down.circle")
                }
                .help(L2("Download Selected"))
                .disabled(!canDownloadSelectedSearchResults || !model.isBridgeOpSupported("download"))

                Button {
                    model.stopSearch()
                } label: {
                    Label(L2("Stop"), systemImage: "stop.fill")
                }
                .help(L2("Stop Search"))
                .disabled(!isSearchInProgressForUI || !isSearchSupported)

                SearchScopePicker(
                    activeScopeValue: activeSearchScopeValue,
                    label: searchScopeMenuLabel,
                    setSearchScope: setSearchScope
                )
                .help(L2("Search Scope"))
                .disabled(!isSearchSupported)
            }
        }
        .modifier(SearchCapabilityGate(
            isSearchSupported: isSearchSupported,
            query: searchQueryBinding,
            placeholder: searchToolbarPlaceholder,
            onSubmit: { model.performSearch() }
        ))
        .task {
            refreshDisplayedSearchResults()
        }
        .onChange(of: model.searchResults) {
            refreshDisplayedSearchResults()
        }
        .onChange(of: model.searchOptions) {
            refreshDisplayedSearchResults()
        }
    }

    private var advancedSearchOptions: some View {
        DisclosureGroup(isExpanded: $showsAdvancedSearchOptions) {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text(L2("Type"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(L2("Any"), text: $model.searchOptions.fileType)
                        .textFieldStyle(.roundedBorder)

                    Text(L2("Extension"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(L2("Any"), text: $model.searchOptions.fileExtension)
                        .textFieldStyle(.roundedBorder)

                    Text(L2("Availability"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("0", text: $model.searchOptions.availabilityText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 72)
                }

                GridRow {
                    Text(L2("Min Size"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("0", text: $model.searchOptions.minSizeText)
                        .textFieldStyle(.roundedBorder)

                    Text(L2("Max Size"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("0", text: $model.searchOptions.maxSizeText)
                        .textFieldStyle(.roundedBorder)

                    Text(L2("Filter"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(L2("Visible Results"), text: $model.searchOptions.filterText)
                        .textFieldStyle(.roundedBorder)
                }

                GridRow {
                    Color.clear
                        .gridCellUnsizedAxes([.horizontal, .vertical])
                    Toggle(L2("Invert"), isOn: $model.searchOptions.invertFilter)
                    Color.clear
                        .gridCellUnsizedAxes([.horizontal, .vertical])
                    Toggle(L2("Hide Known"), isOn: $model.searchOptions.hideKnownResults)
                    Color.clear
                        .gridCellUnsizedAxes([.horizontal, .vertical])
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
        } label: {
            Text(L2("Advanced Search"))
                .font(.subheadline)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func refreshDisplayedSearchResults() {
        displayedSearchResults = model.searchOptions.filteredResults(model.searchResults)
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

private struct SearchCapabilityGate: ViewModifier {
    let isSearchSupported: Bool
    let query: Binding<String>
    let placeholder: String
    let onSubmit: () -> Void

    func body(content: Content) -> some View {
        if isSearchSupported {
            content
                .searchable(text: query, placement: .toolbar, prompt: Text(placeholder))
                .onSubmit(of: .search) {
                    onSubmit()
                }
        } else {
            content
        }
    }
}

#if DEBUG
#Preview("Empty Search") {
    SearchWindowView(embeddedInMainWindow: true)
        .environmentObject(AppModel.previewConnected())
}

#Preview("Search Results") {
    SearchWindowView(embeddedInMainWindow: true)
        .environmentObject(AppModel.previewWithSearchResults())
}

#Preview("Search In Progress") {
    let model = AppModel.previewConnected()
    model.isSearchInProgress = true
    return SearchWindowView(embeddedInMainWindow: true)
        .environmentObject(model)
}
#endif
