# aMuleGUI Parity QA

Daemon/core endpoint:
- Host: unavailable; no daemon endpoint was provided for this QA pass.
- Port: unavailable; no daemon endpoint was provided for this QA pass.
- Version: unavailable; no daemon endpoint was provided for this QA pass.

Upstream remote GUI build/run evidence:
- No existing executable named `amulegui` was present in this worktree before building. The checked-in `aMuleGUI.app` contains only bundle metadata and no executable.
- Configure command run from the repository root:
  `cmake -S . -B /tmp/amule-amulegui-parity-build -DBUILD_REMOTEGUI=ON -DBUILD_MONOLITHIC=OFF -DBUILD_DAEMON=OFF -DBUILD_WEB=OFF -DBUILD_AMULECMD=OFF -DBUILD_ED2K=OFF -DBUILD_ALCC=OFF -DBUILD_FILEVIEW=OFF -DBUILD_CAS=OFF -DBUILD_WXCAS=OFF -DBUILD_ALC=OFF -DBUILD_PLASMAMULE=OFF`
- Configure completed and reported `Should aMule remote gui be built? ON`.
- Build command run:
  `cmake --build /tmp/amule-amulegui-parity-build --target amulegui -j2`
- Build completed with target `amulegui` and produced `/tmp/amule-amulegui-parity-build/src/aMuleGUI.app/Contents/MacOS/aMuleGUI`.
- Noninteractive run command:
  `/tmp/amule-amulegui-parity-build/src/aMuleGUI.app/Contents/MacOS/aMuleGUI --help`
- `--help` printed aMuleGUI usage and options including `--version`, `--config-dir`, `--skip`, `--enable-stdin`, and category assignment for passed ED2K links, then exited 255 after showing help. No daemon-backed GUI session was run.

Source-level comparison evidence:
- `src/CMakeLists.txt` builds the upstream remote GUI target with `CLIENT_GUI` and `amule-remote-gui.cpp`.
- `src/DownloadListCtrl.cpp` upstream context menus include priority, cancel, stop, pause, resume, clear completed, A4AF swap modes, details/comments, link copy, and category assignment.
- `src/SearchDlg.cpp` upstream search supports local/global/Kad selection, extended search fields, stop, and result download.
- `src/SharedFilesCtrl.cpp` upstream shared-file menus include upload priority, comment/rating, rename, collection import, and multiple link variants.
- `src/FriendListCtrl.cpp` upstream menus include add/remove/details, send message, view files, and friend slot; `src/ExternalConn.cpp` reports friend shared-file list as not implemented by the daemon, and chat send has no verified EC operation in this branch.
- `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECBridgeAdapter/SwiftECBridgeAdapter.swift` exposes SwiftEC bridge methods for downloads, search, servers, Kad, uploads, shared files, logs, friends, preferences, categories, and statistics.
- Native macOS source surfaces include dedicated windows for Search, eD2k, Server Logs, Uploads, Shared Files, Friends, Statistics, and Preferences in `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AMuleNativeRemoteApp.swift`.

Checks:
- [ ] Connect/disconnect behaves like upstream remote GUI. Source-level EC operations exist, but this requires a real daemon endpoint/manual session.
- [x] Downloads list columns and context actions cover pause, resume, stop, cancel, priority, clear completed, category assignment, copy links, details, and A4AF. Source evidence: upstream `DownloadListCtrl.cpp`; native bridge/actions in `AppModel+Downloads.swift` and `SwiftECBridgeAdapter.swift`.
- [x] Search supports local/global/Kad, extended fields, filtering, stop, clear, and download. Source evidence: upstream `SearchDlg.cpp`; native `AppModel+Search.swift`, `SearchWindowView`, and SwiftEC search request/options.
- [x] eD2k server list supports add, remove, connect, disconnect, server.met URL, static flag, priority, and server log. Source evidence: upstream remote GUI/server files; native `AppModel+Servers.swift`, eD2k window, and Server Logs window.
- [x] Kad controls support start, stop, bootstrap IP/port, and nodes.dat URL update. Source evidence: native `AppModel+Servers.swift` calls `kad-start`, `kad-stop`, `kad-bootstrap`, and `kad-update-from-url`.
- [x] Shared files support reload, priority, comments/ratings, link copy, and visible transfer stats. Source evidence: upstream `SharedFilesCtrl.cpp`; native Shared Files window plus `shared-files`, `shared-files-reload`, `shared-file-priority`, and `shared-file-comment-rating`.
- [x] Uploads show current upload clients and totals. Source evidence: native Uploads window and `uploads` bridge/parser path.
- [ ] Friends support list refresh, remove, friend slot, and all supported add/message actions. Add/remove/friend-slot source paths exist, but daemon-backed manual QA is still needed; remote shared-list and chat message send are unsupported by daemon EC in this branch.
- [ ] Statistics tree and graphs load and refresh. Source paths exist, but loading/refreshing requires daemon data.
- [ ] Preferences reload/apply supported remote groups without corrupting unrelated settings. Source paths exist for selected preference groups, but corruption safety requires daemon-backed mutation QA.
