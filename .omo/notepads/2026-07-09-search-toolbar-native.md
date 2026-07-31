# Search Toolbar Native

Brief: move the macOS Search page query entry from the in-content row to a native SwiftUI toolbar search field, and relabel the inspector toggle as the Advanced search option.

Session: `.omo/ulw-loop/search-toolbar-native-20260709`

Scope:
- `Sources/AMuleNativeRemote/SearchWindowView.swift`
- macOS Search/UI tests under `Tests/AMuleNativeRemoteTests`
- Search section in `DESIGN.md`
- localization only if new visible strings are introduced

Acceptance:
- Search uses `.searchable(text: $model.searchQuery, placement: .toolbar, prompt: L("File name or keywords"))`.
- Search submit still calls `model.performSearch()`.
- Old `SearchQueryBar` content row is removed.
- The toggle is labeled `Advanced` and keeps the existing in-window panel stable.
- Focused tests, adjacent Search/UI tests, screenshots, and Swift build pass or produce a captured unrelated failure.
