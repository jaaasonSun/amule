# Code Review: shared-stats-crash-20260708

codeQualityStatus: CLEAR
recommendation: APPROVE
reportPath: .omo/evidence/shared-stats-crash-20260708-code-review.md

## Scope

Re-reviewed only the changes made after the prior BLOCK:

- Removed source-scanning shared-files row-identity test.
- Added behavior-level shared-files row-identifier coverage.
- Updated `SharedFilesWindowView` to use `sharedFileRowIdentifier(file:offset:)`.
- Removed source-scanning stats formatting test.
- Strengthened daemon printf placeholder formatter cases.
- Updated focused evidence wording.

## Skill-Perspective Check

Required review perspectives were loaded and consulted:

- `omo:remove-ai-slops`: `/Users/jason/.codex/plugins/cache/sisyphuslabs/omo/4.15.1/skills/remove-ai-slops/SKILL.md`
- `omo:programming`: `/Users/jason/.codex/plugins/cache/sisyphuslabs/omo/4.15.1/skills/programming/SKILL.md`

Result: the changed areas no longer violate either perspective. The deletion-only/source-scanning tests identified in the previous review are gone, and the replacement tests exercise behavior through a row-identity helper plus rendered SwiftUI/AppKit surfaces.

## Findings

### CRITICAL

None.

### HIGH

None.

### MEDIUM

None.

### LOW

None blocking. `SharedFilesParityTests.swift:54` through `:56` assert the exact row-id string as well as uniqueness. This is acceptable here because the helper is now the row identity contract under test, and the user-visible surface test remains present at `SharedFilesParityTests.swift:20`.

## Verification

- `rg` found no remaining `testSharedFilesListDoesNotUseHashAsSoleRowIdentity`, `testStatsTreeLabelsDoNotUseDaemonTextAsRawStringFormat`, `List(model.sharedFiles, id: \.hash)`, or `String(format: label` in `native-macos/AMuleNativeRemote`.
- `cd native-macos/AMuleNativeRemote && swift test --filter SharedFilesParityTests --filter StatsKadParityTests`: passed, 7 tests, 0 failures.
- `cd native-macos/AMuleNativeRemote/SwiftEC && swift test --filter ECOperationsTests/testSharedFilesParserAndEnvelopeMatchBridgeShape --filter ECOperationsTests/testSharedFilesParserUsesKnownFileChildHashAndPartFileDisplayName --filter ECOperationsTests/testSharedFilesParserMapsKnownFileMetricTagsWithCppConstants`: passed, 3 tests, 0 failures.
- `git diff --check`: passed.

## Reviewed Line References

- `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/SharedFilesWindowView.swift:73`
- `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/SharedFilesWindowView.swift:187`
- `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/SharedFilesWindowView.swift:196`
- `native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/SharedFilesParityTests.swift:20`
- `native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/SharedFilesParityTests.swift:42`
- `native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/StatsKadParityTests.swift:26`
- `native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/StatsKadParityTests.swift:40`

## Blockers

None.
