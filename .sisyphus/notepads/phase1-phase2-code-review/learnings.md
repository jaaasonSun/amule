## Task 10 - iOS download cancel

- iOS download removal must use the existing C++ bridge `cancel` operation with `--hash`; local array mutation alone is cosmetic and is reverted by refresh.
- The iOS SwiftPM tests compile the wrapper/executable target on macOS, so bridge adapter behavior can be verified through `IOSInProcessBridgeAdapterTests` even though UIKit-gated app model code is not directly test-imported by the shared test target.
