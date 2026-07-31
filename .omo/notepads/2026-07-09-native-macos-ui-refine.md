# Native macOS UI Refinement

## Bootstrap

- Brief: refine Statistics toolbar/content, add hide Uploads setting, keep Search advanced toggle from resizing window, narrow Settings, and fix incomplete localization.
- Session: `.omo/ulw-loop/native-macos-ui-refine-20260709/`.
- Evidence: `.omo/evidence/native-macos-ui-refine-20260709/`.
- Tier: HEAVY. Reason: multiple macOS UI surfaces, persisted sidebar preferences, layout behavior, localization sweep, screenshots, and final review gate.
- Shape: delivery.

## Skills

- `omo:ulw-loop`: durable criteria, evidence, and checkpoint.
- `build-macos-apps:swiftui-patterns`: native macOS toolbar/settings/inspector patterns.
- `build-macos-apps:build-run-debug`: Swift and app-bundle build verification.
- `omo:frontend`: existing design system and redesign guidance.
- `omo:visual-qa`: screenshot verification for changed UI surfaces.
- `superpowers:brainstorming`: read for context-first design discipline; the approval hard gate conflicts with the explicit ULW implementation request, so no separate user approval stop.

## Findings

- `StatsWindowView` toolbar has a separate `Tree` refresh button and `StatsGraphControls` with a `Graphs` button. These are unclear because the page can refresh tree and graphs together and graph width/scale are tuning inputs, not primary page actions.
- `StatsOverviewGrid` includes `eD2k` and `Kad` status tiles, duplicating server/network status surfaces and making the statistics page read less focused.
- `ContentView` already supports hiding Categories/Friends via `@AppStorage`; Uploads should follow the same pattern and normalize selection when hidden.
- `SearchWindowView` uses `.inspector(isPresented:)`; opening the advanced panel changes the window width. The requested behavior is a stable-size search window.
- `PreferencesWindowView` is fixed at 760 wide; current form rows stretch label/value spacing too far.
- Localization is inconsistent: touched macOS surfaces still contain bare visible strings in `Text`, `Button`, `Label`, `Menu`, `Picker`, and local helper duplicates (`L2`, `LF2`, `L3`, `LF3`) remain in some files.

## Criteria

- C001 Stats cleanup: `swift test --filter MacUIRefinementTests/testStatisticsPageRemovesConfusingToolbarAndNetworkStatus` RED before implementation, GREEN after; screenshot `statistics-refined.png` shows refresh-only toolbar and no eD2k/Kad status tiles.
- C002 Sidebar/settings: `swift test --filter MacUIRefinementTests/testUploadsPageCanBeHiddenFromInterfaceSettings` RED/GREEN; screenshot `settings-interface-refined.png` shows Uploads toggle and narrower settings layout; screenshot `sidebar-uploads-hidden.png` shows Uploads absent when hidden.
- C003 Search size: `swift test --filter MacUIRefinementTests/testAdvancedSearchDoesNotUseResizableInspector` RED/GREEN; screenshots `search-advanced-collapsed.png` and `search-advanced-expanded.png` have same dimensions.
- C004 Localization: `swift test --filter MacUIRefinementTests/testTouchedMacSurfacesUseLocalizedVisibleStrings` RED/GREEN and source scan evidence for touched files.
- C005 Regression: `swift test --filter MacUIRefinementTests`, `swift test --filter MacUIRedesignTests`, `swift test --filter MacSettingsToolbarStyleTests`, `swift test`, `swift build -Xswiftc -warnings-as-errors`, `./scripts/build-app.sh`, `git diff --check`.

## Commit Policy

- No auto-commit. The worktree contains prior uncommitted changes; this run records no-commit evidence instead of mixing unrelated edits.
