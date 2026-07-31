# Search page rework ULW notepad

## Bootstrap

- User request: rework the macOS Search page so controls are organized by whether they apply before a search or after results exist, while keeping the side inspector concept, using native SwiftUI/macOS controls where possible, and making the page modern/native.
- Tier: HEAVY. Reason: user requested a UI interaction redesign, not a narrow bug fix; it changes toolbar/content/inspector organization and requires visual QA.
- Shape: delivery.
- Skills selected:
  - `omo:ulw-loop`: requested by `ulw`; provides evidence-bound goals and ledger.
  - `omo:frontend`: UI/UX redesign and visual QA routing; applied through existing native app `DESIGN.md`.
  - `omo:visual-qa`: required after UI changes; screenshots and reviewer-style artifacts will be captured.
  - `build-macos-apps:swiftui-patterns`: Search page uses macOS SwiftUI toolbar, inspector/split patterns, and native controls.
  - `superpowers:brainstorming`: applicable to creative UI work; superseded by explicit user instruction to implement now and ULW's no-stall delivery requirement.
- Design-system route: existing native app design system at `native-macos/AMuleNativeRemote/DESIGN.md`; follow native restraint, semantic colors, page toolbar actions, grouped inspectors, and no decorative animation.

## Initial Read

- Current Search layout has a query bar above results, toolbar actions for Download/Stop/Advanced/Scope, and an in-window `SearchAdvancedPanel` that mixes pre-search constraints and post-search result filtering in one column.
- User feedback says the side inspector idea is sound, but the controls need to be separated by lifecycle:
  - Before search: query, scope, file type/extension, availability, min/max size.
  - After search: result filtering, result summary, selected-result affordances.

## Working Design

- Keep the side panel as the Search inspector, but make it a native `Inspector` column that is always conceptually secondary and can be toggled without changing standalone window size.
- Move pre-search criteria into a "Criteria" inspector section with grouped `Form` rows and native controls.
- Move result-filtering and search state into a "Results" inspector section.
- Keep top toolbar focused on page-level commands: Start/Stop, Download selected, and inspector toggle. Scope belongs with Criteria because it affects the next search.
- Use SwiftUI-native `Form`, `Section`, `Picker`, `TextField`, `Toggle`/`Button`, `Label`, and `ControlGroup`/toolbar patterns where suitable.

## Success Criteria

1. C001 Search lifecycle organization:
   - Scenario: `swift test --filter MacSearchPageReworkTests/testSearchInspectorSeparatesCriteriaFromResultFilters` fails before production change and passes after.
   - Evidence: `.omo/evidence/search-page-rework-20260709/c001-lifecycle-red-green.txt`; screenshot `.omo/evidence/search-page-rework-20260709/search-inspector-expanded.png`.
   - PASS: criteria controls and result filter controls render in separate sections; Search Scope lives with criteria, not the toolbar.
2. C002 Window stability and native controls:
   - Scenario: `swift test --filter MacSearchPageReworkTests/testSearchInspectorToggleKeepsStandaloneWindowSizeStable` fails before production change and passes after.
   - Evidence: `.omo/evidence/search-page-rework-20260709/c002-window-stability-red-green.txt`; screenshots collapsed/expanded.
   - PASS: toggling the inspector does not resize the standalone Search window; source uses native SwiftUI `Form`/`Section`/`Picker` for side-panel controls.
3. C003 Regression and localization:
   - Scenario: `swift test --filter MacSearchPageReworkTests/testSearchReworkVisibleStringsAreLocalized` plus existing macOS UI tests and full Swift package checks.
   - Evidence: `.omo/evidence/search-page-rework-20260709/c003-regression-localization.txt`.
   - PASS: touched visible strings are localized in both Simplified Chinese tables; existing Search rendering/regression tests pass.

## Adversarial Classes

- stale selection after filtering: selected result IDs must still be intersected with visible result IDs.
- unsupported daemon search capability: controls must disable using existing `isSearchSupported`.
- dirty worktree: do not revert unrelated existing changes.
- misleading screenshot-only pass: pair screenshots with source and behavior tests.

