## Task 10 - iOS download cancel

- iOS download removal must use the existing C++ bridge `cancel` operation with `--hash`; local array mutation alone is cosmetic and is reverted by refresh.
- The iOS SwiftPM tests compile the wrapper/executable target on macOS, so bridge adapter behavior can be verified through `IOSInProcessBridgeAdapterTests` even though UIKit-gated app model code is not directly test-imported by the shared test target.
- Task 12 iOS server parity: iOS SwiftPM test target depends only on `AMuleRemoteIOSShared`, so adapter/wrapper/server decode tests live in `IOSInProcessBridgeAdapterTests`; UIKit-gated app model/fake code is verified by package build during `swift test --package-path native-macos/AMuleNativeRemote/iOS`.

## Task 16 - Review Evidence Cleanup

- Review artifacts must have consistent file/line citations for all findings. Original reports may cite general areas; cleanup must add specific paths and line numbers.
- Task status must be consistent across all review files. A task marked as a blocker in bridge review cannot be marked PASS in feature review without explanation.
- Path typos (like AMuleRemoteRemote) must be corrected when discovered during quality gates.
- Short artifacts (<100 lines) need expansion with cross-references to fix evidence to provide full context.
- All RESOLVED findings must reference the fix evidence file that resolved them (fix-09 through fix-15).
- Final recommendation must be updated from REJECT to APPROVED when all blockers are resolved.
- Historical evidence must be preserved - add RESOLVED status and fix references, do not delete original findings.
- Severity levels must not be changed to hide issues - a blocker stays a blocker, just marked resolved.
- Evidence cleanup is documentation-only - no source code changes should be made during this phase.

## Task 17 final verification - 2026-05-15

- Final gate rejected: SwiftPM macOS/iOS and CMake bridge passed, iOS forbidden API scan was clean, and iOS SwiftPM tests executed expected 15 tests.
- Simulator runtime exists (iOS 26.5), but xcodebuild simulator build fails with unresolved AMuleRemoteIOSShared and SharedUI module dependencies; scheme is also not configured for test action.
- Evidence written to .sisyphus/evidence/fix-17-final-verification.txt.

## 2026-05-15 - Task 17 final verification gate

- Task 9-16 evidence files were present and non-empty during final gate verification.
- `swift test`/`swift build` passed for both `native-macos/AMuleNativeRemote` and `native-macos/AMuleNativeRemote/iOS`; CMake bridge build also passed.
- Forbidden iOS API scan over Swift/C++/header production sources returned zero matches for AppKit/NSPasteboard/NSWindow/NSApplication/Carbon.HIToolbox/Process(.
- iOS simulator runtime was available, so xcodebuild was run; it failed with exit code 65 due to unresolved `AMuleRemoteIOSShared` and `SharedUI` module dependencies in the Xcode project target.
