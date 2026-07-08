# Verification Evidence: SwiftEC and macOS Client

Date: 2026-07-08

## SwiftEC Package

```bash
cd native-macos/AMuleNativeRemote/SwiftEC
swift test
./Scripts/check-forbidden-deps.sh
```

PASS.

- `AMuleECProtocolTests`: 34 tests, 0 failures.
- `AMuleECClientTests`: 126 tests, 0 failures.
- `AMuleECBridgeAdapterTests`: 32 tests, 0 failures, 3 live-daemon smoke tests skipped because `AMULE_EC_HOST`, `AMULE_EC_PORT`, and `AMULE_EC_PASSWORD` were not set.
- Forbidden dependency scan passed.

## macOS SwiftPM Package

```bash
cd native-macos/AMuleNativeRemote
swift test
swift build -Xswiftc -warnings-as-errors
```

PASS.

- `AMuleNativeRemoteTests`: 114 tests, 0 failures.
- Warnings-as-errors build completed successfully.

## macOS App Build

```bash
cd native-macos/AMuleNativeRemote
./scripts/build-app.sh
```

PASS.

- Xcode Release build completed with `** BUILD SUCCEEDED **`.
- Built app: `native-macos/AMuleNativeRemote/dist/aMule Remote.app`.

## Repository Hygiene

```bash
git diff --check
```

PASS. No whitespace errors.
