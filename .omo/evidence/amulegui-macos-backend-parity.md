# amulegui vs native macOS backend parity evidence

Generated: 2026-07-08

## Sources read

- `src/amule-remote-gui.cpp:148-203`: original GUI poll loop sends status, mixed update, search results, stats tree, and link checks on staged one-second ticks.
- `src/amule-remote-gui.cpp:359-399`: startup wires remote containers for servers, stats, clients, search, friends, shared files, known files, downloads, and IP filter before starting poll timers.
- `src/amule-remote-gui.h:116-388`: `CRemoteContainer` state machine performs status/full reload phases and removal semantics for missing core items.
- `src/amule-remote-gui.cpp:1534-1788`: original download commands cover add link, priority, auto priority, category, search-result download, clear completed.
- `src/amule-remote-gui.cpp:1794-1917`: original friend list supports add/remove/friend slot and sends friend-shared requests.
- `src/amule-remote-gui.cpp:1936-2075`: original search lifecycle uses start, stop, progress, results, and incremental result merging.
- `src/amule-remote-gui.cpp:2104-2111`: status updater also feeds connection-state handling.
- `src/libs/ec/cpp/RemoteConnect.cpp:37-68`: original auth request/password packet shape and advertised capabilities.
- `src/libs/ec/cpp/RemoteConnect.cpp:107-159`: original connect/auth flow, MD5 empty-password guard, and sync auth handshake.
- `src/libs/ec/cpp/RemoteConnect.cpp:226-240`: original async request FIFO assumption.
- `src/ExternalConn.cpp:567-725`: daemon status, shared files, and mixed `GET_UPDATE` responses.
- `src/ExternalConn.cpp:795-943`: daemon part-file, server, and friend command semantics.
- `src/ExternalConn.cpp:1017-1129`: daemon search result, search download, stop, and start semantics.
- `src/ExternalConn.cpp:1338-1505`: daemon dispatch for shutdown, add link, status, queue/update, shared, rename, clear-completed, client swap, shared comments.
- `src/ExternalConn.cpp:1510-1800`: daemon server list/update, search dispatch, prefs/categories, logs/stats, Kad operations.
- `src/libs/ec/cpp/ECCodes.h:60-124`: canonical opcode values, including `DOWNLOAD_SEARCH_RESULT = 0x2A` and `CLIENT_SWAP_TO_ANOTHER_FILE = 0x54`.
- `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECOperations.swift:328-905`: SwiftEC packet builders and capability gating.
- `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECProtocol/ECSupportedOps.swift:97-168`: advertised operation list and intentionally disabled operation list.
- `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECBridgeAdapter/SwiftECBridgeAdapter.swift:61-97`: download baseline/update flow and source-update merge usage.
- `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECBridgeAdapter/SwiftECBridgeAdapter.swift:393-449`: friends and shared-file mutation adapter coverage.
- `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECBridgeAdapter/SwiftECBridgeAdapter.swift:601-664`: BridgeProtocol advertised methods.
- `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECResponseParser.swift:393-733`: parsers for downloads, sources, servers, uploads, shared files, categories, friends, stats, mutation replies, search.
- `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECDownloadStateStore.swift:40-148`: incremental download merge, tombstone, clear-completed, and full-resync detection.
- `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECSourceStateStore.swift:13-131`: sparse source delta merge and request-file context rules.
- `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Connection.swift:76-94`: native auto-refresh cadence.
- `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Search.swift:1-120`: native search start/stop/download-result path.
- `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Downloads.swift:60-165`: native download command fan-out and rename verification path.

## Comparison summary

| Area | amulegui / daemon behavior | Native macOS / SwiftEC state | Plan consequence |
| --- | --- | --- | --- |
| Transport/auth | RemoteConnect authenticates once, advertises zlib/UTF8/notify capabilities, uses FIFO request matching. | SwiftEC authenticates through `ECSession`; notify is not used; request pipeline serializes one request/reply. | Keep notify off unless demux exists; add contract tests for capability flags and request/reply assumptions. |
| Refresh model | amulegui runs staged one-second polling and only refreshes heavier views when visible. | Native polls status/downloads every second and servers every five ticks; other windows refresh on demand. | Add scheduler/request-pressure tests or document intentional divergence. |
| Mixed update | Daemon `GET_UPDATE + INC_UPDATE` replies `EC_OP_SHARED_FILES` with part files, known files, clients, servers, friends. | Parser/store accepts `sharedFiles` for downloads, sources, friends and merges sparse deltas. | Preserve this design; test with fixtures for every mixed top-level tag. |
| Downloads | Original `CRemoteContainer` removes missing incremental items; C++ commands operate on hash tags and support repeated tags. | Swift supports main actions but single-item mutations are looped at AppModel for multi-select; clear-completed batches ECIDs. | Add batch-builder decision tests: either support repeated tags in SwiftEC builders or document single-send fan-out. |
| Search | Start returns `STRINGS`, stop returns `MISC_DATA`, results/progress are separate polls; search download returns `STRINGS`. | Adapter handles these expected success opcodes and polls fixed count/interval. | Add lifecycle tests around progress/result dedupe and stop cancellation. |
| Friends | Daemon `FRIEND_SHARED` is compiled out and returns failure; friend list data arrives through mixed update. | `friend-shared` is intentionally unadvertised, but callable builder exists behind capability gate; friend list uses mixed update. | Keep hidden; add explicit failed-response/UI-disabled documentation. |
| Client swap | Daemon opcode is `0x54`, request requires `EC_TAG_CLIENT` id and `EC_TAG_PARTFILE` hash. | Swift opcode is incorrectly `0x2A`, aliased with search-result download, with only hash-like client tag; capability is advertised and tests assert the wrong shape. | First implementation task must fix or unadvertise this operation. |
| Docs/evidence | Upstream C++ line refs are source of truth. | Existing parity report and `Operations.md` opcode table contain stale or wrong conclusions. | Rewrite docs as part of plan, after tests lock behavior. |
