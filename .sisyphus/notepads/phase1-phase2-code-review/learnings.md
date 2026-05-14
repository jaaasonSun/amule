## Task 10 - iOS download cancel

- iOS download removal must use the existing C++ bridge `cancel` operation with `--hash`; local array mutation alone is cosmetic and is reverted by refresh.
- The iOS SwiftPM tests compile the wrapper/executable target on macOS, so bridge adapter behavior can be verified through `IOSInProcessBridgeAdapterTests` even though UIKit-gated app model code is not directly test-imported by the shared test target.
- Task 12 iOS server parity: iOS SwiftPM test target depends only on `AMuleRemoteIOSShared`, so adapter/wrapper/server decode tests live in `IOSInProcessBridgeAdapterTests`; UIKit-gated app model/fake code is verified by package build during `swift test --package-path native-macos/AMuleNativeRemote/iOS`.
