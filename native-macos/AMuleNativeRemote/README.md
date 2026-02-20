# aMule Native Remote (macOS)

A new native macOS remote GUI for aMule, implemented with SwiftUI.

Current feature set:
- Remote login settings (`amule-ec-bridge` path, host, port, password)
- Connect/disconnect and status display (eD2k, Kad, up/down speed, queue, sources)
- Search (Kad/Global/Local)
- Search result listing with one-click download
- Download queue display
- Command log for troubleshooting
- App bundle ships with a bundled `amule-ec-bridge` binary

## Prerequisites
- macOS 13+
- Xcode command line tools (`swift`)
- a working `amule-ec-bridge` binary for packaging (from this repo build or custom path)
- a running aMule/amuled core with External Connection enabled

## Run from source
```bash
cd /path/to/amule/native-macos/AMuleNativeRemote
swift run
```

## Build app bundle
```bash
cd /path/to/amule/native-macos/AMuleNativeRemote
./scripts/build-app.sh
open "dist/aMule Native Remote.app"
```

To use a custom bridge binary during packaging:
```bash
AMULE_EC_BRIDGE_PATH=/path/to/amule-ec-bridge ./scripts/build-app.sh
```

## Notes
- This app uses the aMule External Connections protocol directly via `amule-ec-bridge`.
- When launched from the packaged `.app`, it automatically prefers the bundled `Contents/Resources/amule-ec-bridge`.
