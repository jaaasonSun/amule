# GREEN Evidence: Focused Fixes

Date: 2026-07-08

## Shared Files SwiftEC Parser

```bash
cd native-macos/AMuleNativeRemote/SwiftEC
swift test --filter ECOperationsTests/testSharedFilesParserAndEnvelopeMatchBridgeShape --filter ECOperationsTests/testSharedFilesParserUsesKnownFileChildHashAndPartFileDisplayName --filter ECOperationsTests/testSharedFilesParserMapsKnownFileMetricTagsWithCppConstants
```

PASS.

- 3 `ECOperationsTests` executed.
- 0 failures.
- Confirms daemon-shaped shared file packets parse display names from `EC_TAG_PARTFILE_NAME`, hashes from child `EC_TAG_PARTFILE_HASH`, and metrics from C++ `ECCodes.h` constants.

## macOS Shared Files / Statistics Behavior

```bash
cd native-macos/AMuleNativeRemote
swift test --filter SharedFilesParityTests --filter StatsKadParityTests
```

PASS.

- 4 `SharedFilesParityTests` and 3 `StatsKadParityTests` executed.
- 0 failures.
- Confirms duplicate/empty-hash shared-file rows get distinct row identities, Shared Files renders distinct `34.partfile`-backed entries, and Statistics safely renders daemon printf-like labels plus literal percentages without crashing.

## macOS Surface Rendering

```bash
cd native-macos/AMuleNativeRemote
swift test --filter SharedFilesParityTests/testSharedFilesSurfaceRendersDistinctRowsForPartfileBackedEntries --filter StatsKadParityTests/testStatisticsSurfaceRendersDaemonPrintfLabelsWithoutCrashing
```

PASS.

- 2 `AMuleNativeRemoteTests` executed.
- 0 failures.
- Wrote non-empty AppKit/SwiftUI render evidence:
  - `.omo/evidence/shared-stats-crash-20260708/shared-files-surface.png`
  - `.omo/evidence/shared-stats-crash-20260708/statistics-surface.png`
- Visual QA: shared files surface shows distinct `Ubuntu.iso`, `Movie.mkv`, and `Archive.zip` rows backed by `34.partfile`, `35.partfile`, and `36.partfile`; statistics surface shows `Users: 34`, `Total users: 34`, and `Progress: 100% done` without crashing.

## Full Regression / Build Gates

```bash
cd native-macos/AMuleNativeRemote/SwiftEC && swift test
cd native-macos/AMuleNativeRemote/SwiftEC && ./Scripts/check-forbidden-deps.sh
cd native-macos/AMuleNativeRemote && swift test
cd native-macos/AMuleNativeRemote && swift build -Xswiftc -warnings-as-errors
cd native-macos/AMuleNativeRemote && ./scripts/build-app.sh
git diff --check
```

PASS.

- SwiftEC: 34 `AMuleECProtocolTests`, 128 `AMuleECClientTests`, and 32 `AMuleECBridgeAdapterTests` passed; 3 live daemon smoke tests skipped because `AMULE_EC_HOST`, `AMULE_EC_PORT`, and `AMULE_EC_PASSWORD` are unset.
- `SwiftEC forbidden dependency scan passed.`
- macOS package: 118 `AMuleNativeRemoteTests` passed.
- warnings-as-errors SwiftPM build passed.
- Release app build passed and produced `native-macos/AMuleNativeRemote/dist/aMule Remote.app`.
- `git diff --check` produced no output.

Raw logs saved under `.omo/evidence/shared-stats-crash-20260708/`:

- `green-swiftec-focused.log`
- `green-macos-focused.log`
- `full-swiftec-test.log`
- `swiftec-forbidden-deps.log`
- `full-macos-test.log`
- `macos-warnings-as-errors-build.log`
- `macos-build-app.log`
- `git-diff-check.log`
