# aMule Native Remote (macOS)

A new native macOS remote GUI for aMule, implemented with SwiftUI.

Current feature set:
- Remote login settings (`amulecmd` path, host, port, password)
- Connect/disconnect and status display (eD2k, Kad, up/down speed, queue, sources)
- Search (Kad/Global/Local)
- Search result listing with one-click download
- Download queue display
- Command log for troubleshooting

## Prerequisites
- macOS 13+
- Xcode command line tools (`swift`)
- a working `amulecmd` binary (from this repo build or installed)
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

## Notes
- This app currently uses `amulecmd` as the backend transport.
- The download action replays the active search before issuing `download <id>` so it can work with `amulecmd`'s per-session search index.
