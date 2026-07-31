# RED Evidence: Shared Files Identity and Statistics Format Crash

Date: 2026-07-08

## Command

```bash
cd native-macos/AMuleNativeRemote
swift test --filter SharedFilesParityTests/testSharedFilesListDoesNotUseHashAsSoleRowIdentity --filter StatsKadParityTests/testStatsTreeLabelsDoNotUseDaemonTextAsRawStringFormat
```

## Result

RED. Both focused tests failed against the pre-fix implementation:

- `SharedFilesParityTests/testSharedFilesListDoesNotUseHashAsSoleRowIdentity`
  - Failure: `Shared files can arrive with empty or duplicate hashes during daemon updates; using hash as the sole SwiftUI identity can visually repeat one row for many files.`
- `StatsKadParityTests/testStatsTreeLabelsDoNotUseDaemonTextAsRawStringFormat`
  - Failure: `Daemon stats labels may contain printf placeholders such as %s; passing them directly to String(format:) can crash the statistics page.`

## Runtime Crash Mechanism

```bash
swift -e 'import Foundation; print(String(format: "%s", "abc"))'
```

The command exited with status `137`, confirming that the statistics view's current `%s` formatting path can terminate the process.

## Shared Files Protocol RED

```bash
cd native-macos/AMuleNativeRemote/SwiftEC
swift test --filter ECOperationsTests/testSharedFilesParserUsesKnownFileChildHashAndPartFileDisplayName --filter ECOperationsTests/testSharedFilesParserMapsKnownFileMetricTagsWithCppConstants
```

RED. The focused daemon-shaped tests failed because:

- parsed display names were `["34.partfile", "35.partfile"]` instead of `["Ubuntu.iso", "Movie.mkv"]`;
- parsed hashes were empty instead of child `EC_TAG_PARTFILE_HASH`;
- generated eD2k links were empty;
- metric fields were transposed: low/high/onQueue/completeSources used stale Swift constants rather than the C++ `ECCodes.h` mapping.
