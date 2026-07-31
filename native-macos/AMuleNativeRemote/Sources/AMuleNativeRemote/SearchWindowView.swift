import SwiftUI
import AppKit
import SharedViews
import SharedModels
import SharedServices

struct SearchWindowView: View {
    @EnvironmentObject private var model: AppModel

    let embeddedInMainWindow: Bool
    private let searchInspectorColumnWidth: CGFloat = 320

    init(embeddedInMainWindow: Bool = false, showsAdvancedSearchOptions: Bool = false) {
        self.embeddedInMainWindow = embeddedInMainWindow
        _showsAdvancedSearchOptions = State(initialValue: showsAdvancedSearchOptions)
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
                .frame(minWidth: 920, minHeight: 560)
        }
    }

    private var baseSearchContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                SearchResultsOutlineView(
                    nodes: searchTree,
                    selection: $selectedSearchResultIDs,
                    sortDescriptors: $searchSortDescriptors,
                    autosaveName: searchOutlineAutosaveName
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)

                if showsAdvancedSearchOptions {
                    Divider()
                    SearchInspectorPanel(
                        options: $model.searchOptions,
                        activeScopeValue: activeSearchScopeValue,
                        setSearchScope: setSearchScope,
                        visibleResultCount: displayedSearchResults.count,
                        totalResultCount: model.searchResults.count,
                        selectedResultCount: selectedSearchResultIDs.count,
                        isSearchSupported: isSearchSupported
                    )
                    .frame(width: searchInspectorColumnWidth)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    model.downloadResults(selectedSearchResults)
                } label: {
                    Label(L("Download"), systemImage: "arrow.down.circle")
                }
                .help(L("Download Selected"))
                .disabled(!canDownloadSelectedSearchResults || !model.isBridgeOpSupported("download"))

                Button {
                    model.stopSearch()
                } label: {
                    Label(L("Stop"), systemImage: "stop.fill")
                }
                .help(L("Stop Search"))
                .disabled(!isSearchInProgressForUI || !isSearchSupported)

                Button {
                    showsAdvancedSearchOptions.toggle()
                } label: {
                    Label(L("Advanced"), systemImage: "slider.horizontal.3")
                }
                .help(L("Advanced Search"))
                .disabled(!isSearchSupported)
            }
        }
        .searchable(text: $model.searchQuery, placement: .toolbar, prompt: L("File name or keywords"))
        .onSubmit(of: .search) {
            guard isSearchSupported else { return }
            model.performSearch()
        }
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

private struct SearchInspectorPanel: View {
    @Binding var options: SearchOptions
    let activeScopeValue: String
    let setSearchScope: (String) -> Void
    let visibleResultCount: Int
    let totalResultCount: Int
    let selectedResultCount: Int
    let isSearchSupported: Bool

    var body: some View {
        Form {
            SearchCriteriaSection(
                options: $options,
                activeScopeValue: activeScopeValue,
                setSearchScope: setSearchScope,
                isSearchSupported: isSearchSupported
            )

            SearchResultsFilterSection(
                options: $options,
                visibleResultCount: visibleResultCount,
                totalResultCount: totalResultCount,
                selectedResultCount: selectedResultCount
            )
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct SearchCriteriaSection: View {
    @Binding var options: SearchOptions
    let activeScopeValue: String
    let setSearchScope: (String) -> Void
    let isSearchSupported: Bool

    private var scopeBinding: Binding<String> {
        Binding(
            get: { activeScopeValue },
            set: { setSearchScope($0) }
        )
    }

    var body: some View {
        Section {
            Picker(L("Search Scope"), selection: scopeBinding) {
                Text(L("Global")).tag("global")
                Text(L("Kad")).tag("kad")
                Text(L("Local")).tag("local")
            }
            .pickerStyle(.menu)
            .disabled(!isSearchSupported)

            LabeledContent(L("Type")) {
                TextField(L("Any"), text: $options.fileType)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(maxWidth: 140)
            }

            LabeledContent(L("Extension")) {
                TextField(L("Any"), text: $options.fileExtension)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(maxWidth: 140)
            }

            LabeledContent(L("Availability")) {
                TextField("0", text: $options.availabilityText)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(maxWidth: 140)
            }

            LabeledContent(L("Min Size")) {
                TextField("0", text: $options.minSizeText)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(maxWidth: 140)
            }

            LabeledContent(L("Max Size")) {
                TextField("0", text: $options.maxSizeText)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(maxWidth: 140)
            }
        } header: {
            Text(L("Criteria"))
        } footer: {
            Text(L("Size values are bytes. Leave empty for no limit."))
        }
    }
}

private struct SearchResultsFilterSection: View {
    @Binding var options: SearchOptions
    let visibleResultCount: Int
    let totalResultCount: Int
    let selectedResultCount: Int

    var body: some View {
        Section {
            SearchInspectorSummary(
                visibleResultCount: visibleResultCount,
                totalResultCount: totalResultCount,
                selectedResultCount: selectedResultCount
            )

            LabeledContent(L("Visible Results")) {
                TextField(L("Visible Results"), text: $options.filterText)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
            }

            Toggle(L("Invert"), isOn: $options.invertFilter)
            Toggle(L("Hide Known"), isOn: $options.hideKnownResults)
        } header: {
            Text(L("Results"))
        } footer: {
            Text(L("Result filters apply only to the results already returned by the daemon."))
        }
    }
}

private struct SearchInspectorSummary: View {
    let visibleResultCount: Int
    let totalResultCount: Int
    let selectedResultCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent(L("Visible")) {
                Text("\(visibleResultCount)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            LabeledContent(L("Total")) {
                Text("\(totalResultCount)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            LabeledContent(L("Selected")) {
                Text("\(selectedResultCount)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
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
