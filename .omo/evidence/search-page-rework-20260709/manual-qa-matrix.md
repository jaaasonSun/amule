# Manual QA Matrix: Search Page Rework

## Surface

- Native macOS SwiftUI Search page.
- Evidence screenshots:
  - `.omo/evidence/search-page-rework-20260709/search-inspector-collapsed.png`
  - `.omo/evidence/search-page-rework-20260709/search-inspector-expanded.png`

## Scenarios

### C001: Lifecycle organization

- Invocation: `swift test --filter MacSearchPageReworkTests/testSearchInspectorSeparatesCriteriaFromResultFilters`
- Render evidence: `search-inspector-expanded.png`
- Result: PASS.
- Observation: the side panel is now a Search Inspector with `Criteria` and `Results` sections. Scope, type, extension, availability, and size inputs are pre-search criteria. Visible-results filtering, invert/hide-known toggles, and result counts are post-search result controls.

### C002: Window stability and native controls

- Invocation: `swift test --filter MacSearchPageReworkTests/testSearchInspectorToggleKeepsStandaloneWindowSizeStable`
- Render evidence: `search-inspector-collapsed.png`, `search-inspector-expanded.png`
- Result: PASS.
- Observation: collapsed and expanded standalone content sizes are equal in the test harness. The inspector uses SwiftUI `Form`, `Section`, `Picker`, `LabeledContent`, `TextField`, and `Toggle` controls. Field labels no longer duplicate as trailing prompt text.

### C003: Regression and localization

- Invocations:
  - `swift test --filter MacSearchPageReworkTests`
  - `swift test --filter MacUIRefinementTests`
  - `swift test --filter MacUIRedesignTests`
  - `swift test`
  - `swift build -Xswiftc -warnings-as-errors`
  - `./scripts/build-app.sh`
  - `plutil -lint native-macos/AMuleNativeRemote/Resources/zh-Hans.lproj/Localizable.strings native-macos/AMuleNativeRemote/Resources/zh_CN.lproj/Localizable.strings`
- Result: PASS.
- Observation: touched visible strings are present in both Simplified Chinese localization tables. The full native package suite executed 137 XCTest tests with 0 failures, and the macOS app bundle build succeeded.

## Notes

- The black table background in screenshots is the existing NSOutlineView render-harness artifact previously seen on Search screenshots; the changed inspector surface renders correctly.
- Swift Charts still emits its pre-existing non-fatal AxisValueLabel warning in unrelated statistics render tests.

