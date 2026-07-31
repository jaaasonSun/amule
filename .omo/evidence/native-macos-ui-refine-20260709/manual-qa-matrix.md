# Manual QA Matrix: native-macos-ui-refine-20260709

Scope: native macOS aMule Remote UI refinements requested on 2026-07-09.

## Evidence Reviewed

- `statistics-refined.png`
- `search-advanced-collapsed.png`
- `search-advanced-expanded.png`
- `settings-interface-refined.png`
- `sidebar-uploads-hidden.png`
- `mac-ui-refinement-tests.txt`
- `swift-test.txt`
- `swift-build-warnings-as-errors.txt`
- `build-app.txt`

## Scenarios

| Priority | Scenario | Expected | Evidence | Result |
| --- | --- | --- | --- | --- |
| P0 | Statistics overview no longer duplicates server status | No eD2k or Kad status tile appears on Statistics. | `statistics-refined.png`; `testStatisticsPageRemovesConfusingToolbarAndNetworkStatus` | PASS |
| P0 | Statistics toolbar no longer exposes Tree/Graphs controls | No separate Tree button and no graph width/scale/Graphs control remains. | `testStatisticsPageRemovesConfusingToolbarAndNetworkStatus`; source grep in static checks | PASS |
| P0 | Statistics still shows useful transfer stats and charts | Download, Upload, Queue, Samples, charts, and stats tree remain visible. | `statistics-refined.png`; `testRefinedMacSurfacesRender` | PASS |
| P0 | Settings exposes Uploads page visibility | Interface settings shows Show Uploads page, Show Categories page, and Show Friends page. | `settings-interface-refined.png`; `testUploadsPageCanBeHiddenFromInterfaceSettings` | PASS |
| P0 | Hiding Uploads removes the sidebar row | Uploads row is absent from Remote sidebar when disabled. | `sidebar-uploads-hidden.png`; `testRefinedMacSurfacesRender` | PASS |
| P0 | Hiding selected Uploads falls back to Downloads | Normalization returns `.downloads(.all)` when `.uploads` is selected and Uploads is hidden. | `testHiddenUploadsSelectionFallsBackToDownloads` | PASS |
| P0 | Search advanced collapsed and expanded states fit the same window content size | Both states lay out in a 920 x 560 content view. | `testAdvancedSearchStatesUseSameWindowContentSize`; `search-advanced-collapsed.png`; `search-advanced-expanded.png` | PASS |
| P1 | Search advanced no longer uses native inspector resizing | No `.inspector` or `.inspectorColumnWidth` remains for the advanced options path. | `testAdvancedSearchDoesNotUseResizableInspector` | PASS |
| P1 | Settings is narrower but toolbar remains readable | Window is 700 pt wide, below previous 760 pt, with readable icon+label toolbar tabs. | `settings-interface-refined.png`; `MacSettingsToolbarStyleTests` | PASS |
| P1 | Touched macOS surfaces have Chinese localization entries | `L`/`LF` keys in touched surfaces exist in `zh-Hans` and `zh_CN`; strings files parse. | `testTouchedMacSurfacesUseLocalizedVisibleStrings`; `plutil -lint` | PASS |
| P1 | Existing macOS UI contracts still pass | Prior redesign and settings toolbar tests remain green. | `mac-ui-redesign-tests.txt`; `mac-settings-toolbar-style-tests.txt` | PASS |
| P1 | Full native Swift package regression remains green | All package tests pass. | `swift-test.txt` | PASS |
| P1 | macOS app still builds | Release app build succeeds. | `build-app.txt` | PASS |

## Residual Notes

- Search table rendering screenshots still show the existing black backing used by the test rendering harness for the outline/table area. This predates the advanced-panel change and did not block the requested window-size behavior.
- Swift Charts emits a runtime warning about custom `UnitPoint` axis label anchors during rendering tests. It does not fail tests or builds and is outside this UI request.
