# Code Review: native-macos-ui-refine-20260709

Verdict: PASS

## Reviewed Files

- `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/StatsWindowView.swift`
- `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/SearchWindowView.swift`
- `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/ContentView.swift`
- `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/PreferencesWindowView.swift`
- `native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/MacUIRefinementTests.swift`
- `native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/MacUIRedesignTests.swift`
- `native-macos/AMuleNativeRemote/Resources/zh-Hans.lproj/Localizable.strings`
- `native-macos/AMuleNativeRemote/Resources/zh_CN.lproj/Localizable.strings`
- `native-macos/AMuleNativeRemote/DESIGN.md`

## Findings

No blocking findings.

## Checks

- Statistics: removed the ambiguous secondary Tree refresh and raw graph width/scale controls while preserving a single capability-gated refresh path for tree and graphs.
- Statistics: removed eD2k/Kad overview tiles from the Statistics page, leaving transfer and sample information that belongs to this surface.
- Search: removed SwiftUI `.inspector` and `.inspectorColumnWidth`; advanced options now render in an in-window fixed-width panel.
- Sidebar: Uploads visibility uses the same persisted local preference pattern as Categories and Friends.
- Sidebar: hidden-selection fallback is now factored into `ContentView.normalizedSidebarSelectionForVisibility`, making the behavior directly testable.
- Settings: 700 pt fixed width remains narrower than the prior 760 pt window while preserving readable preference-toolbar tabs.
- Localization: both Simplified Chinese resource directories contain the touched visible keys and parse with `plutil -lint`.
- Tests: source-string guardrails remain only for structural regressions; runtime evidence was added for hidden Uploads normalization and Search same-size window content.

## Non-Blocking Risks

- `ContentView.SidebarSelection` and `DownloadSidebarFilter` are now internal rather than private so the fallback behavior can be tested without UI automation hooks. This is acceptable inside the app target but should not be treated as a public API.
- `PreferencesWindowView.swift` remains a large view file from prior work. This task narrowed and adjusted it without attempting a broader refactor.
