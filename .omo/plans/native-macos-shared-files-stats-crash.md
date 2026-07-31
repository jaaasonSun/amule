# Native macOS Shared Files And Statistics Investigation

## TL;DR
> Summary:      Investigate and fix two macOS native-client regressions with failing-first Swift tests: shared file rows repeating as `34.partfile`, and Statistics crashing on open. Current evidence points to SwiftEC shared-file parsing using the wrong tags for hash/name, plus unsafe stats label formatting in the macOS statistics view.
> Deliverables:
> - SwiftEC parser regressions for shared-file hash/name/tag mapping.
> - macOS model/view regressions proving distinct shared-file rows render distinctly.
> - SwiftEC/macOS stats-tree regressions proving statistics labels render without printf crashes.
> - Real-surface macOS view rendering evidence for Shared Files and Statistics.
> Effort:       Medium
> Risk:         Medium - likely root causes are concrete, but final behavior depends on daemon-shaped EC packets and macOS view rendering.

## Scope
### Must have
- Preserve macOS/iOS separation; do not change iOS navigation, tab structure, or mobile-only chrome.
- Prefer fixes in `native-macos/AMuleNativeRemote/SwiftEC/` when the defect is EC parsing/contract behavior.
- Keep macOS view fixes in `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/`.
- Add failing-first proof before production changes for each bug.
- Capture evidence under `.omo/evidence/`.
- Do not commit; every task has `Commit: NO`.

### Must NOT have (guardrails, anti-slop, scope boundaries)
- Do not modify upstream C++ daemon behavior under `src/`; use it only as protocol reference.
- Do not change iOS app files unless a shared SwiftEC model change forces test-only compatibility updates.
- Do not paper over repeated rows by sorting/filtering out shared files.
- Do not use `String(format:)` on daemon-supplied statistics labels in SwiftUI rendering.
- Do not remove generated build products or unrelated local files. Current dirty-worktree risk: untracked `.omo/ulw-loop/`.

## Verification strategy
> Zero human intervention - all verification is agent-executed.
- Test decision: TDD + XCTest via SwiftPM; focused RED logs first, focused GREEN logs after fixes, then package/build sweeps.
- QA policy: every task has agent-executed scenarios.
- Evidence: `.omo/evidence/task-<N>-<slug>.<ext>`

## Execution strategy
### Parallel execution waves
> Target 5-8 tasks per wave. <3 per wave (except final) = under-splitting.
> Extract shared dependencies as Wave-1 tasks to maximize parallelism.

Wave 1 (no dependencies):
- Task 1: Capture baseline and daemon-contract evidence.
- Task 2: Add shared-files parser RED proof and fix SwiftEC tag mapping.
- Task 4: Add statistics RED proof and fix stats-tree display formatting contract.

Wave 2 (after Wave 1):
- Task 3: Harden macOS Shared Files model/view row identity and rendering evidence, depends [1, 2].
- Task 5: Harden macOS Statistics view against label/graph edge cases, depends [1, 4].
- Task 6: Run macOS real-surface rendering QA for both reported pages, depends [3, 5].

Wave 3 (after Wave 2):
- Task 7: Regression sweep and evidence collation, depends [2, 3, 4, 5, 6].

Critical path: Task 1 -> Task 2 -> Task 3 -> Task 6 -> Task 7

### Dependency matrix
| Task | Depends on | Blocks | Can parallelize with |
|------|------------|--------|----------------------|
| 1    | none       | 3, 5, 6, 7 | 2, 4 |
| 2    | none       | 3, 6, 7 | 1, 4 |
| 3    | 1, 2       | 6, 7 | 5 |
| 4    | none       | 5, 6, 7 | 1, 2 |
| 5    | 1, 4       | 6, 7 | 3 |
| 6    | 3, 5       | 7 | none |
| 7    | 2, 3, 4, 5, 6 | Final verification | none |

## Todos
> Implementation + Test = ONE task. Never separate.
> Every task MUST have: References + Acceptance Criteria + QA Scenarios + Commit.

- [x] 1. Capture baseline and daemon-contract evidence

  What to do: Record the current failing/unknown baseline before changing code. Capture the focused existing tests, relevant raw protocol contract, and package layout in evidence files. Do not modify source files in this task.
  Must NOT do: Do not fix code, update tests, or run full UI builds yet.

  Parallelization: Can parallel: YES | Wave 1 | Blocks: [3, 5, 6, 7] | Blocked by: []

  References (executor has NO interview context - be exhaustive):
  - Pattern:  `native-macos/AMuleNativeRemote/docs/coding-agent-field-guide.md:1` - native Apple architecture and verification commands.
  - Pattern:  `native-macos/AMuleNativeRemote/Package.swift:28` - macOS SwiftPM test target.
  - Pattern:  `native-macos/AMuleNativeRemote/SwiftEC/Package.swift:47` - SwiftEC client test target.
  - Pattern:  `src/ECSpecialCoreTags.cpp:221` - upstream `CEC_SharedFile_Tag` root value is ECID, not the MD4 hash.
  - Pattern:  `src/ECSpecialCoreTags.cpp:248` - upstream shared-file child tags include display name, hash, internal path, and size.
  - Pattern:  `src/libs/ec/cpp/ECSpecialTags.cpp:141` - upstream stats tree display-string formatting is value-type aware.
  - External: `https://developer.apple.com/documentation/swiftui/list/init%28_%3Aid%3Arowcontent%3A%29` - SwiftUI `List(_:id:rowContent:)` row identity contract.
  - External: `https://developer.apple.com/documentation/foundation/nsstring/init%28format%3Alocale%3Aarguments%3A%29` - Foundation format strings substitute values by format specifiers.

  Acceptance criteria (agent-executable only):
  - [ ] Run `(cd native-macos/AMuleNativeRemote/SwiftEC && swift test --filter ECOperationsTests/testSharedFilesParserAndEnvelopeMatchBridgeShape) 2>&1 | tee .omo/evidence/task-1-existing-shared-parser.log` and record pass/fail.
  - [ ] Run `(cd native-macos/AMuleNativeRemote && swift test --filter StatsKadParityTests) 2>&1 | tee .omo/evidence/task-1-existing-stats-tests.log` and record pass/fail.
  - [ ] Save a short evidence note at `.omo/evidence/task-1-contract-notes.md` summarizing the line-backed contract facts above.

  QA scenarios (MANDATORY - task incomplete without these):
  ```
  Scenario: Existing focused tests execute
    Tool:     bash
    Steps:    (cd native-macos/AMuleNativeRemote/SwiftEC && swift test --filter ECOperationsTests/testSharedFilesParserAndEnvelopeMatchBridgeShape) 2>&1 | tee .omo/evidence/task-1-existing-shared-parser.log
    Expected: Command completes; log exists and states the baseline result.
    Evidence: .omo/evidence/task-1-existing-shared-parser.log

  Scenario: Stats baseline executes
    Tool:     bash
    Steps:    (cd native-macos/AMuleNativeRemote && swift test --filter StatsKadParityTests) 2>&1 | tee .omo/evidence/task-1-existing-stats-tests.log
    Expected: Command completes; log exists and states the baseline result.
    Evidence: .omo/evidence/task-1-existing-stats-tests.log
  ```

  Commit: NO | Message: `test(native-macos): capture baseline for shared files and stats investigation` | Files: [.omo/evidence/task-1-existing-shared-parser.log, .omo/evidence/task-1-existing-stats-tests.log, .omo/evidence/task-1-contract-notes.md]

- [x] 2. Fix SwiftEC shared-files parser tag mapping with RED->GREEN proof

  What to do: Add a failing SwiftEC test using upstream-shaped `EC_TAG_KNOWNFILE` packets where the root tag value is ECID, the hash is child `EC_TAG_PARTFILE_HASH`, the display name is child `EC_TAG_PARTFILE_NAME`, and `EC_TAG_KNOWNFILE_FILENAME` may be an internal part-met/temp identifier such as `34.partfile`. Then update `ECResponseParser.parseSharedFiles` to populate `ECSharedFile.hash` from child part-file hash, `name` from child part-file name, `path` from known-file filename, and shared-file metrics from the C++ constants.
  Must NOT do: Do not derive display names from `knownFileFilename` when `partFileName` exists. Do not use the root known-file tag as the MD4 hash.

  Parallelization: Can parallel: YES | Wave 1 | Blocks: [3, 6, 7] | Blocked by: []

  References (executor has NO interview context - be exhaustive):
  - API/Type: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECResponseParser.swift:573` - current shared-files parser to fix.
  - API/Type: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECResponseParser.swift:88` - current known-file tag constants; note 0x0409/0x040A/0x040C/0x040D mismatch with C++.
  - API/Type: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECModels.swift:1215` - `ECSharedFile` payload contract.
  - Pattern:  `src/libs/ec/cpp/ECCodes.h:211` - authoritative known-file tag constants.
  - Pattern:  `src/ECSpecialCoreTags.cpp:221` - root known-file tag is ECID.
  - Pattern:  `src/ECSpecialCoreTags.cpp:248` - child name/hash/path/size tags.
  - Test:     `native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECClientTests/ECOperationsTests.swift:1024` - existing parser/envelope test pattern.

  Acceptance criteria (agent-executable only):
  - [ ] Before production fix, add `testSharedFilesParserUsesKnownFileChildHashAndPartFileDisplayName` and capture a failing log with `(cd native-macos/AMuleNativeRemote/SwiftEC && swift test --filter ECOperationsTests/testSharedFilesParserUsesKnownFileChildHashAndPartFileDisplayName) 2>&1 | tee .omo/evidence/task-2-sharedfiles-parser-red.log`.
  - [ ] After production fix, the same command exits 0 and log is saved to `.omo/evidence/task-2-sharedfiles-parser-green.log`.
  - [ ] Add/adjust a metric-mapping assertion proving 0x0409=completeSourcesLow, 0x040A=completeSourcesHigh, 0x040C=onQueue, 0x040D=completeSources.
  - [ ] `ed2kLink` uses the display name and uppercase hash, not `34.partfile` or an empty hash.

  QA scenarios (MANDATORY - task incomplete without these):
  ```
  Scenario: Shared parser preserves user-visible file names
    Tool:     bash
    Steps:    (cd native-macos/AMuleNativeRemote/SwiftEC && swift test --filter ECOperationsTests/testSharedFilesParserUsesKnownFileChildHashAndPartFileDisplayName) 2>&1 | tee .omo/evidence/task-2-sharedfiles-parser-green.log
    Expected: Exit 0; assertions show names ["Ubuntu.iso", "Movie.mkv"], hashes from child 0x031E, paths/internal IDs may include "34.partfile" but do not become display names.
    Evidence: .omo/evidence/task-2-sharedfiles-parser-green.log

  Scenario: Shared parser rejects repeated empty identity baseline
    Tool:     bash
    Steps:    (cd native-macos/AMuleNativeRemote/SwiftEC && swift test --filter ECOperationsTests/testSharedFilesParserMapsKnownFileMetricTagsWithCppConstants) 2>&1 | tee .omo/evidence/task-2-sharedfiles-metrics-green.log
    Expected: Exit 0; no parsed shared file has an empty hash when child 0x031E exists; metric constants match `src/libs/ec/cpp/ECCodes.h`.
    Evidence: .omo/evidence/task-2-sharedfiles-metrics-green.log
  ```

  Commit: NO | Message: `fix(swiftec): parse shared file names and hashes from child tags` | Files: [native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECResponseParser.swift, native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECClientTests/ECOperationsTests.swift]

- [x] 3. Prove macOS Shared Files rows stay distinct in model and view

  What to do: Add macOS package tests proving `AppModel.refreshSharedFilesNow` preserves distinct payload names and that `SharedFilesWindowView` has stable row identity even if an older bridge payload contains empty/duplicate hashes. If production hardening is needed, introduce a small macOS-only row identity helper used by `List(model.sharedFiles, id:)`.
  Must NOT do: Do not filter duplicate names, hide rows, or change iOS shared code for row identity unless a shared model addition from Task 2 requires it.

  Parallelization: Can parallel: YES | Wave 2 | Blocks: [6, 7] | Blocked by: [1, 2]

  References (executor has NO interview context - be exhaustive):
  - Pattern:  `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/SharedFilesWindowView.swift:73` - current list identity uses `\.hash`.
  - Pattern:  `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/SharedFilesWindowView.swift:95` - row displays `file.name` and `file.path`.
  - Pattern:  `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Bridge.swift:20` - refresh entry point.
  - Pattern:  `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Bridge.swift:258` - model assignment from bridge payload.
  - Test:     `native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/FakeBridgeAdapter.swift:178` - fake bridge shared-files hook to extend.
  - Test:     `native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/SharedFilesParityTests.swift:5` - shared-files parity test home.
  - External: `https://developer.apple.com/documentation/swiftui/list/init%28_%3Aid%3Arowcontent%3A%29` - list row identity reference.

  Acceptance criteria (agent-executable only):
  - [ ] Before production fix, add `testSharedFilesRefreshPreservesDistinctNamesAndStableRowIDs` and capture failing or currently passing baseline at `.omo/evidence/task-3-sharedfiles-model-red.log`.
  - [ ] After fix/hardening, `(cd native-macos/AMuleNativeRemote && swift test --filter SharedFilesParityTests/testSharedFilesRefreshPreservesDistinctNamesAndStableRowIDs) 2>&1 | tee .omo/evidence/task-3-sharedfiles-model-green.log` exits 0.
  - [ ] Add a macOS view rendering test that hosts `SharedFilesWindowView` with three fixture files and writes `.omo/evidence/task-3-sharedfiles-view.png`.
  - [ ] Screenshot/text extraction evidence confirms the row names are distinct and none display `34.partfile` when display names are present.

  QA scenarios (MANDATORY - task incomplete without these):
  ```
  Scenario: Model preserves distinct shared file rows
    Tool:     bash
    Steps:    (cd native-macos/AMuleNativeRemote && swift test --filter SharedFilesParityTests/testSharedFilesRefreshPreservesDistinctNamesAndStableRowIDs) 2>&1 | tee .omo/evidence/task-3-sharedfiles-model-green.log
    Expected: Exit 0; model.sharedFiles.map(\.name) equals the fixture display names in order; row IDs are unique or deterministically disambiguated.
    Evidence: .omo/evidence/task-3-sharedfiles-model-green.log

  Scenario: Shared Files surface renders distinct rows
    Tool:     bash
    Steps:    (cd native-macos/AMuleNativeRemote && swift test --filter SharedFilesSurfaceRenderingTests/testSharedFilesSurfaceRendersDistinctRows) 2>&1 | tee .omo/evidence/task-3-sharedfiles-view-green.log
    Expected: Exit 0; test writes `.omo/evidence/task-3-sharedfiles-view.png`; assertions find "Ubuntu.iso", "Movie.mkv", and "Archive.zip" exactly once each.
    Evidence: .omo/evidence/task-3-sharedfiles-view.png
  ```

  Commit: NO | Message: `fix(native-macos): keep shared file rows distinct` | Files: [native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/SharedFilesWindowView.swift, native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/SharedFilesParityTests.swift, native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/FakeBridgeAdapter.swift]

- [x] 4. Fix statistics tree formatting contract with RED->GREEN proof

  What to do: Add failing SwiftEC stats-tree parser tests that model upstream `EC_TAG_STATTREE_NODE` packets with `EC_TAG_STAT_NODE_VALUE` and `EC_TAG_STAT_VALUE_TYPE`, especially `EC_VALUE_ISTRING`/`EC_VALUE_STRING` cases that make labels contain `%s`. Then move value-aware display formatting into SwiftEC or a pure shared helper so macOS SwiftUI does not call printf formatting on daemon labels.
  Must NOT do: Do not keep `String(format:)` as the primary renderer for daemon-provided labels. Do not discard child nodes.

  Parallelization: Can parallel: YES | Wave 1 | Blocks: [5, 6, 7] | Blocked by: []

  References (executor has NO interview context - be exhaustive):
  - API/Type: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECResponseParser.swift:671` - stats-tree parser entry point.
  - API/Type: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECResponseParser.swift:1146` - current node parser only keeps label and numeric value.
  - API/Type: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECModels.swift:1325` - current `ECStatsTreeNode` shape.
  - API/Type: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECJSONEnvelope.swift:119` - bridge envelope shape for stats tree.
  - Pattern:  `src/libs/ec/cpp/ECSpecialTags.cpp:84` - upstream value-type formatting.
  - Pattern:  `src/libs/ec/cpp/ECSpecialTags.cpp:141` - upstream display string composition.
  - Pattern:  `src/StatTree.cpp:188` - daemon EC tag contains raw label plus value children.
  - Pattern:  `src/libs/ec/cpp/ECCodes.h:430` - stats value-type enum.
  - Test:     `native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECClientTests/ECResponseParserTests.swift:1` - parser-focused test location.

  Acceptance criteria (agent-executable only):
  - [ ] Before production fix, add `testStatsTreeParserFormatsStringTypedValueWithoutPrintfPlaceholders` and capture failing log at `.omo/evidence/task-4-stats-tree-parser-red.log`.
  - [ ] After production fix, `(cd native-macos/AMuleNativeRemote/SwiftEC && swift test --filter ECResponseParserTests/testStatsTreeParserFormatsStringTypedValueWithoutPrintfPlaceholders) 2>&1 | tee .omo/evidence/task-4-stats-tree-parser-green.log` exits 0.
  - [ ] Add an edge test `testStatsTreeParserKeepsInvalidPercentLabelsLiteral` proving labels with stray `%` do not crash or throw.
  - [ ] Encoded stats JSON remains decodable by `BridgeEnvelope`.

  QA scenarios (MANDATORY - task incomplete without these):
  ```
  Scenario: Typed stats labels render safely
    Tool:     bash
    Steps:    (cd native-macos/AMuleNativeRemote/SwiftEC && swift test --filter ECResponseParserTests/testStatsTreeParserFormatsStringTypedValueWithoutPrintfPlaceholders) 2>&1 | tee .omo/evidence/task-4-stats-tree-parser-green.log
    Expected: Exit 0; parsed display text has no raw "%s" for typed string/integer-string values and no unsafe formatter is involved.
    Evidence: .omo/evidence/task-4-stats-tree-parser-green.log

  Scenario: Bad percent labels are non-fatal
    Tool:     bash
    Steps:    (cd native-macos/AMuleNativeRemote/SwiftEC && swift test --filter ECResponseParserTests/testStatsTreeParserKeepsInvalidPercentLabelsLiteral) 2>&1 | tee .omo/evidence/task-4-stats-tree-edge-green.log
    Expected: Exit 0; malformed labels are displayed literally or sanitized, not formatted through printf.
    Evidence: .omo/evidence/task-4-stats-tree-edge-green.log
  ```

  Commit: NO | Message: `fix(swiftec): format stats tree values without unsafe printf labels` | Files: [native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECResponseParser.swift, native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECModels.swift, native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECJSONEnvelope.swift, native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECClientTests/ECResponseParserTests.swift]

- [x] 5. Harden macOS Statistics view against crash and graph edge cases

  What to do: Update `StatsWindowView` to consume safe stats display text from Task 4, remove unsafe format calls, and add macOS package tests for the stats tree row helper and graph-empty/error behavior. Keep Charts usage unchanged unless a focused test proves it is part of the crash.
  Must NOT do: Do not remove the Statistics page or hide the tree/graphs sections. Do not make opening Statistics depend on graph samples being present.

  Parallelization: Can parallel: YES | Wave 2 | Blocks: [6, 7] | Blocked by: [1, 4]

  References (executor has NO interview context - be exhaustive):
  - Pattern:  `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/StatsWindowView.swift:35` - opening the view triggers stats tree and graph refresh.
  - Pattern:  `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/StatsWindowView.swift:335` - current unsafe label formatting hotspot.
  - Pattern:  `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/StatsWindowView.swift:151` - throughput chart construction.
  - Pattern:  `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Bridge.swift:204` - stats refresh entry points.
  - Pattern:  `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Bridge.swift:377` - stats tree model update.
  - Pattern:  `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Bridge.swift:397` - stats graphs model update.
  - Test:     `native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/StatsKadParityTests.swift:4` - stats-related macOS test home.
  - Test:     `native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/FakeBridgeAdapter.swift:241` - fake stats tree/graphs hooks to extend.
  - External: `https://developer.apple.com/documentation/charts/linemark` - line chart rendering reference.

  Acceptance criteria (agent-executable only):
  - [ ] Before production fix, add `testStatsTreeDisplayDoesNotCrashOnPercentSLabels` and capture failing log at `.omo/evidence/task-5-stats-view-red.log`.
  - [ ] After fix, `(cd native-macos/AMuleNativeRemote && swift test --filter StatsKadParityTests/testStatsTreeDisplayDoesNotCrashOnPercentSLabels) 2>&1 | tee .omo/evidence/task-5-stats-view-green.log` exits 0.
  - [ ] Add `testStatsGraphsFailureLeavesStatisticsPageRenderable` proving no-points/errors leave a non-crashing empty/error state.
  - [ ] `rg -n "String\\(format: label|label.contains\\(\"%s\"\\)" native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/StatsWindowView.swift` produces no unsafe daemon-label formatting usage.

  QA scenarios (MANDATORY - task incomplete without these):
  ```
  Scenario: Statistics row helper handles percent labels
    Tool:     bash
    Steps:    (cd native-macos/AMuleNativeRemote && swift test --filter StatsKadParityTests/testStatsTreeDisplayDoesNotCrashOnPercentSLabels) 2>&1 | tee .omo/evidence/task-5-stats-view-green.log
    Expected: Exit 0; fixture labels containing "%s", "%llu", and stray "%" render as safe text without crashing.
    Evidence: .omo/evidence/task-5-stats-view-green.log

  Scenario: Empty graph response is non-fatal
    Tool:     bash
    Steps:    (cd native-macos/AMuleNativeRemote && swift test --filter StatsKadParityTests/testStatsGraphsFailureLeavesStatisticsPageRenderable) 2>&1 | tee .omo/evidence/task-5-stats-graphs-edge-green.log
    Expected: Exit 0; model/view remains renderable and `lastError` is populated or empty-state text remains visible.
    Evidence: .omo/evidence/task-5-stats-graphs-edge-green.log
  ```

  Commit: NO | Message: `fix(native-macos): render statistics labels safely` | Files: [native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/StatsWindowView.swift, native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/StatsKadParityTests.swift, native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/FakeBridgeAdapter.swift]

- [x] 6. Run real-surface macOS rendering QA for both pages

  What to do: Add or use macOS XCTest surface tests that host `SharedFilesWindowView` and `StatsWindowView` in `NSHostingView` with fixture `AppModel` instances, render the views, assert visible text, and write PNG evidence. Then run a macOS Release build to ensure the app surface compiles with Charts/AppKit imports.
  Must NOT do: Do not require manual clicking or a live daemon for pass/fail. Do not use iOS simulator commands.

  Parallelization: Can parallel: NO | Wave 2 | Blocks: [7] | Blocked by: [3, 5]

  References (executor has NO interview context - be exhaustive):
  - Pattern:  `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AMuleNativeRemoteApp.swift:11` - macOS scene structure.
  - Pattern:  `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/ContentView.swift:126` - Shared Files sidebar title.
  - Pattern:  `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/ContentView.swift:199` - embedded Shared Files view route.
  - Pattern:  `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/ContentView.swift:208` - embedded Statistics view route.
  - Pattern:  `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/SharedFilesWindowView.swift:18` - shared-files surface root.
  - Pattern:  `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/StatsWindowView.swift:19` - statistics surface root.
  - Test:     `native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/MacNativeNavigationTests.swift` - macOS-only UI/navigation test patterns.
  - Test:     `native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/MacHIGConformanceTests.swift` - macOS conformance test location.

  Acceptance criteria (agent-executable only):
  - [ ] `(cd native-macos/AMuleNativeRemote && swift test --filter SharedFilesSurfaceRenderingTests) 2>&1 | tee .omo/evidence/task-6-sharedfiles-surface.log` exits 0 and writes `.omo/evidence/task-6-sharedfiles-surface.png`.
  - [ ] `(cd native-macos/AMuleNativeRemote && swift test --filter StatsSurfaceRenderingTests) 2>&1 | tee .omo/evidence/task-6-stats-surface.log` exits 0 and writes `.omo/evidence/task-6-stats-surface.png`.
  - [ ] `(cd native-macos/AMuleNativeRemote && xcodebuild -project AMuleNativeRemote.xcodeproj -scheme AMuleNativeRemote -configuration Release -destination "platform=macOS" build) 2>&1 | tee .omo/evidence/task-6-macos-release-build.log` exits 0.

  QA scenarios (MANDATORY - task incomplete without these):
  ```
  Scenario: Shared Files real surface
    Tool:     bash
    Steps:    (cd native-macos/AMuleNativeRemote && swift test --filter SharedFilesSurfaceRenderingTests) 2>&1 | tee .omo/evidence/task-6-sharedfiles-surface.log
    Expected: Exit 0; PNG exists; assertions show three distinct shared-file names and no repeated `34.partfile` display.
    Evidence: .omo/evidence/task-6-sharedfiles-surface.png

  Scenario: Statistics real surface
    Tool:     bash
    Steps:    (cd native-macos/AMuleNativeRemote && swift test --filter StatsSurfaceRenderingTests) 2>&1 | tee .omo/evidence/task-6-stats-surface.log
    Expected: Exit 0; PNG exists; assertions show "Statistics", "Stats Tree", and graph empty/sample state without crash.
    Evidence: .omo/evidence/task-6-stats-surface.png
  ```

  Commit: NO | Message: `test(native-macos): cover shared files and statistics surfaces` | Files: [native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/SharedFilesSurfaceRenderingTests.swift, native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/StatsSurfaceRenderingTests.swift, .omo/evidence/task-6-sharedfiles-surface.png, .omo/evidence/task-6-stats-surface.png]

- [x] 7. Run final regression sweep and collate evidence

  What to do: Run focused and package-level checks after fixes. Collate evidence into `.omo/evidence/task-7-summary.md` with command, result, and artifact paths. Keep commits disabled.
  Must NOT do: Do not claim completion if a focused RED->GREEN test is missing, if any surface screenshot is absent, or if final verification has not run.

  Parallelization: Can parallel: NO | Wave 3 | Blocks: [Final verification] | Blocked by: [2, 3, 4, 5, 6]

  References (executor has NO interview context - be exhaustive):
  - Pattern:  `native-macos/AMuleNativeRemote/docs/coding-agent-field-guide.md:84` - native package verification checklist.
  - Pattern:  `native-macos/AMuleNativeRemote/SwiftEC/Scripts/check-forbidden-deps.sh` - SwiftEC layering guard.
  - Pattern:  `native-macos/AMuleNativeRemote/Package.swift:1` - Swift tools version and macOS platform.
  - Pattern:  `native-macos/AMuleNativeRemote/SwiftEC/Package.swift:1` - SwiftEC tools version and platforms.

  Acceptance criteria (agent-executable only):
  - [ ] `(cd native-macos/AMuleNativeRemote/SwiftEC && swift test) 2>&1 | tee .omo/evidence/task-7-swiftec-tests.log` exits 0.
  - [ ] `(cd native-macos/AMuleNativeRemote/SwiftEC && ./Scripts/check-forbidden-deps.sh) 2>&1 | tee .omo/evidence/task-7-swiftec-forbidden-deps.log` exits 0.
  - [ ] `(cd native-macos/AMuleNativeRemote && swift test) 2>&1 | tee .omo/evidence/task-7-native-tests.log` exits 0.
  - [ ] `(cd native-macos/AMuleNativeRemote && swift build -Xswiftc -warnings-as-errors) 2>&1 | tee .omo/evidence/task-7-native-warnings-as-errors.log` exits 0.
  - [ ] `.omo/evidence/task-7-summary.md` lists every RED log, GREEN log, screenshot, and final command result.

  QA scenarios (MANDATORY - task incomplete without these):
  ```
  Scenario: Native package regression sweep
    Tool:     bash
    Steps:    (cd native-macos/AMuleNativeRemote && swift test && swift build -Xswiftc -warnings-as-errors) 2>&1 | tee .omo/evidence/task-7-native-regression.log
    Expected: Exit 0; no warnings-as-errors failure; Shared Files and Stats focused tests included in suite output.
    Evidence: .omo/evidence/task-7-native-regression.log

  Scenario: SwiftEC regression sweep
    Tool:     bash
    Steps:    (cd native-macos/AMuleNativeRemote/SwiftEC && swift test && ./Scripts/check-forbidden-deps.sh) 2>&1 | tee .omo/evidence/task-7-swiftec-regression.log
    Expected: Exit 0; shared-files parser and stats-tree parser focused tests included in suite output; forbidden dependencies check passes.
    Evidence: .omo/evidence/task-7-swiftec-regression.log
  ```

  Commit: NO | Message: `test(native-macos): verify shared files and statistics regressions` | Files: [.omo/evidence/task-7-summary.md, .omo/evidence/task-7-native-regression.log, .omo/evidence/task-7-swiftec-regression.log]

## Final verification wave (MANDATORY - after all implementation tasks)
> Runs in PARALLEL. ALL must APPROVE. Surface results to the caller and wait for an explicit "okay" before declaring complete.
- [x] F1. Plan compliance audit - every task done, every acceptance criterion met.
- [x] F2. Code quality review - diagnostics clean, idioms match, no dead code, macOS/iOS separation preserved.
- [x] F3. Real manual QA - every QA scenario executed by agents with evidence captured; screenshots exist for both reported pages.
- [x] F4. Scope fidelity - no C++ daemon changes, no iOS navigation changes, no commits, no unrelated file cleanup.

## Commit strategy
- No commits unless the user explicitly asks after final verification.
- If the user later asks for commits: one logical change per commit, Conventional Commits (`<type>(<scope>): <subject>` body + footer), every commit builds and passes focused tests on its own.
- No "WIP" / "fix typo squash later" commits on the final branch.
- Reference the plan file path in any final commit footer: `Plan: .omo/plans/native-macos-shared-files-stats-crash.md`.

## Success criteria
- Shared Files no longer shows repeated `34.partfile` rows when EC packets contain distinct display names.
- Statistics opens and renders tree/graph sections without crashing on typed `%s`/percent labels or empty graph data.
- All Must-Have shipped; all QA scenarios pass with captured evidence; F1-F4 approved; no commits created unless the user asks.
