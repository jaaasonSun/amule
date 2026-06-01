import SwiftUI

private func L2SearchScope(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

struct SearchScopePicker: View {
    let activeScopeValue: String
    let label: String
    let setSearchScope: (String) -> Void

    var body: some View {
        Menu {
            SearchScopePickerButton(
                title: L2SearchScope("Kad"),
                scopeValue: "kad",
                activeScopeValue: activeScopeValue,
                setSearchScope: setSearchScope
            )
            SearchScopePickerButton(
                title: L2SearchScope("Global"),
                scopeValue: "global",
                activeScopeValue: activeScopeValue,
                setSearchScope: setSearchScope
            )
            SearchScopePickerButton(
                title: L2SearchScope("Local"),
                scopeValue: "local",
                activeScopeValue: activeScopeValue,
                setSearchScope: setSearchScope
            )
        } label: {
            Text(label)
        }
    }
}

private struct SearchScopePickerButton: View {
    let title: String
    let scopeValue: String
    let activeScopeValue: String
    let setSearchScope: (String) -> Void

    private var isSelected: Bool {
        activeScopeValue.lowercased() == scopeValue
    }

    var body: some View {
        Button {
            setSearchScope(scopeValue)
        } label: {
            HStack {
                Text(title)
                if isSelected {
                    Image(systemName: "checkmark")
                }
            }
        }
    }
}
