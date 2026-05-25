# Native Bridge Operation Matrix

This matrix is the current contract audit for native Apple app-exposed EC operations. Source of truth for the operation universe is `ECOperationName` in `SwiftEC/Sources/AMuleECClient/ECModels.swift`; capability advertisement is `ECSupportedOps.allOperations`, not the stale SwiftEC README count.

Classification values:

- `supported`: app-visible contract is implemented end-to-end for the currently exposed platform(s), with no known protocol mismatch.
- `partial`: at least one contract axis is missing, weakly tested, platform-specific, or semantically ambiguous.
- `bug`: advertised or app-callable behavior is known to send/parse the wrong EC request/response.
- `unsupported-disabled`: name exists but is not advertised or reachable through app bridge protocols.

## Coverage notes

- macOS exposes the full `BridgeProtocol` in `Sources/AMuleNativeRemote/BridgeProtocol.swift` and calls every protocol method from `AppModel.swift` except `disconnect` is used as remote-session teardown.
- iOS exposes only the smaller v1 protocol in `iOS/Sources/AMuleRemoteIOSShared/BridgeProtocol.swift`: capabilities/status/downloads/search/download/link/rename/pause/resume/cancel/servers/server mutations/sources/preferences.
- The legacy process bridge advertises only `AMuleECBridge::SupportedOps()` from `src/AMuleECBridgeCore.cpp` (25 ops). `AMuleECBridgeClient.swift` has wrappers for more operations, but the C++ bridge returns `Unsupported --op value` for anything outside `SupportedOps()` / `ExecuteBridgeOperation()`.
- SwiftEC currently advertises `ECSupportedOps.allOperations` (43 ops). It does **not** advertise `category-update` or `download-set-category` even though those names exist in `ECOperationName`.
- Generic mutations use `parseMutationResponse` plus the `message` JSON envelope. Read/list operations need a typed parser plus a typed JSON envelope.

## Matrix

| Operation | Class | macOS UI | iOS UI | Legacy process bridge | SwiftEC builder | SwiftEC adapter endpoint | Parser / JSON envelope | Capability advertised | Fixture-backed tests | Follow-up |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `capabilities` | supported | yes | yes | yes | synthetic capabilities | yes | capabilities envelope | SwiftEC yes; legacy yes | supported-ops canonical test; envelope fixture exists but stale | — |
| `status` | supported | yes | yes | yes | `status()` | yes | `parseStatus` + status envelope | SwiftEC yes; legacy yes | parser/envelope unit coverage | — |
| `downloads` | supported | yes | yes | yes | `downloads()` plus update merge | yes | `parseDownloads` + downloads envelope | SwiftEC yes; legacy yes | parser, state-store, adapter fixture coverage | — |
| `sources` | supported | yes | yes | yes | `sourcesQueueLookup()` + `sourcesUpdate()` | yes | `parseDownloadFileID`, stateful source merge + sources envelope | SwiftEC yes; legacy yes | parser and adapter/state-store fixture coverage | — |
| `servers` | supported | yes | yes | yes | `servers()` | yes | `parseServers` + servers envelope | SwiftEC yes; legacy yes | parser/envelope unit coverage | — |
| `search` | supported | yes | yes | yes | `search()`, internal progress/results builders | yes | `parseSearchProgress`, `parseSearchResults` + search envelope | SwiftEC yes; legacy yes | parser coverage and adapter failure fixture | — |
| `search-stop` | partial | yes | protocol/adapter yes; limited UI use | yes | `searchStop()` | yes | mutation parser + message envelope | SwiftEC yes; legacy yes | adapter success-opcode fixture only | Task 4: add fixture-backed mutation coverage |
| `download` | partial | yes | yes | yes | `download(hash:)` | yes | mutation parser + message envelope | SwiftEC yes; legacy yes | builder and adapter success-opcode fixture | Task 4: expand mutation fixtures |
| `add-link` | partial | yes | yes | yes | `addLink(_:)` | yes | mutation parser + message envelope | SwiftEC yes; legacy yes | builder coverage only; URL intake tested elsewhere, not EC fixture-backed | Task 4: add mutation fixture |
| `connect` | partial | yes, as remote/session connect | yes, as remote/session connect | yes, sends `EC_OP_CONNECT` | `coreConnect()` exists | adapter `connect` only authenticates, does not use `coreConnect()` | mutation parser available, endpoint returns synthetic message | SwiftEC yes; legacy yes | no operation fixture for core connect | Task 2: resolve advertised core-connect semantics; Task 5: document platform bridge meaning |
| `disconnect` | partial | yes, as remote/session teardown | yes, as remote/session teardown | yes, sends `EC_OP_DISCONNECT` | `coreDisconnect()` exists | adapter `disconnect` only closes local session, does not use `coreDisconnect()` | mutation parser available, endpoint returns synthetic message | SwiftEC yes; legacy yes | no operation fixture for core disconnect | Task 2: resolve advertised core-disconnect semantics; Task 5: document platform bridge meaning |
| `pause` | partial | yes | yes | yes | `pause(hash:)` | yes | mutation parser + message envelope | SwiftEC yes; legacy yes | adapter mutation fixture covers pause opcode | Task 4: add daemon-sensitive mutation fixtures |
| `resume` | partial | yes | yes | yes | `resume(hash:)` | yes | mutation parser + message envelope | SwiftEC yes; legacy yes | builder coverage only | Task 4: add mutation fixture |
| `rename` | partial | yes | yes | yes | `rename(hash:name:)` | yes, with connection-closed fallback | mutation parser + message envelope | SwiftEC yes; legacy yes | wire-format and adapter failure/closed-socket fixtures | Task 4: add daemon-sensitive rename fixture coverage |
| `cancel` | partial | yes | yes | yes | `cancel(hash:)` | yes | mutation parser + message envelope | SwiftEC yes; legacy yes | builder coverage only | Task 4: add mutation fixture |
| `priority` | partial | yes | no iOS protocol/UI | yes | `priority(hash:value:)` | yes | mutation parser + message envelope | SwiftEC yes; legacy yes | builder coverage only | Task 4: add mutation fixture; Task 5: decide iOS parity |
| `clear-completed` | partial | yes | no iOS protocol/UI | yes | `clearCompleted(ecids:)` | yes | mutation parser + message envelope | SwiftEC yes; legacy yes | builder coverage only | Task 4: add mutation fixture; Task 5: decide iOS parity |
| `server-connect` | partial | yes | yes | yes | `serverConnect(ip:port:)` | yes | mutation parser + message envelope | SwiftEC yes; legacy yes | builder coverage only | Task 4: add server mutation fixtures |
| `server-disconnect` | partial | yes | yes | yes | `serverDisconnect()` | yes | mutation parser + message envelope | SwiftEC yes; legacy yes | builder coverage only | Task 4: add server mutation fixtures |
| `server-add` | partial | yes | yes | yes | `serverAdd(address:name:)` | yes | mutation parser + message envelope | SwiftEC yes; legacy yes | builder coverage only | Task 4: add server mutation fixtures |
| `server-remove` | partial | yes | yes | yes | `serverRemove(ip:port:)` | yes | mutation parser + message envelope | SwiftEC yes; legacy yes | builder coverage only | Task 4: add server mutation fixtures |
| `server-update-from-url` | partial | yes | yes | yes | `serverUpdateFromURL(url:)` | yes | mutation parser + message envelope | SwiftEC yes; legacy yes | builder coverage only | Task 4: add server mutation fixtures; Task 10: iOS server polish |
| `kad-start` | partial | yes | no iOS protocol/UI | no | `kadStart()` | yes | mutation parser + message envelope | SwiftEC yes; legacy no | no fixture-backed operation test | Task 4: add fixtures or disable; Task 5: platform parity decision |
| `kad-stop` | partial | yes | no iOS protocol/UI | no | `kadStop()` | yes | mutation parser + message envelope | SwiftEC yes; legacy no | no fixture-backed operation test | Task 4: add fixtures or disable; Task 5: platform parity decision |
| `kad-bootstrap` | partial | yes | no iOS protocol/UI | no | `kadBootstrap(ip:port:)` | yes | mutation parser + message envelope | SwiftEC yes; legacy no | no fixture-backed operation test | Task 4: add fixtures or disable; Task 5: platform parity decision |
| `kad-update-from-url` | partial | yes | no iOS protocol/UI | yes | `kadUpdateFromURL(url:)` | yes | mutation parser + message envelope | SwiftEC yes; legacy yes | builder coverage only | Task 4: add fixture; Task 5: platform parity decision |
| `prefs-connection-get` | supported | yes | yes | yes | `prefsConnectionGet()` | yes | `parseConnectionPrefs` + prefs envelope | SwiftEC yes; legacy yes | parser/envelope unit coverage | — |
| `prefs-connection-set` | partial | yes | yes | yes | `prefsConnectionSet(maxDownload:maxUpload:)` | yes | mutation parser + message envelope | SwiftEC yes; legacy yes | builder coverage only | Task 4: add prefs mutation fixture |
| `uploads` | partial | yes | no iOS protocol/UI | no | `uploads()` | yes | `parseUploads` + uploads envelope | SwiftEC yes; legacy no | no fixture-backed operation test | Task 4: add fixture or disable; Task 5: platform parity decision |
| `shared-files` | partial | yes | no iOS protocol/UI | no | `sharedFiles()` | yes | `parseSharedFiles` + shared-files envelope | SwiftEC yes; legacy no | no fixture-backed operation test | Task 4: add fixture or disable; Task 5: platform parity decision |
| `shared-files-reload` | partial | yes | no iOS protocol/UI | no | `sharedFilesReload()` | yes | mutation parser + message envelope | SwiftEC yes; legacy no | no fixture-backed operation test | Task 4: add fixture or disable; Task 5: platform parity decision |
| `log` | partial | yes | no iOS protocol/UI | no | `log(debug:false)` | adapter `coreLog` | `parseCoreLog` + log envelope | SwiftEC yes; legacy no | no fixture-backed operation test | Task 4: add fixture or disable; Task 5: platform parity decision |
| `debug-log` | partial | yes | no iOS protocol/UI | no | `log(debug:true)` | yes | `parseCoreLog` + log envelope | SwiftEC yes; legacy no | no fixture-backed operation test | Task 4: add fixture or disable; Task 5: platform parity decision |
| `categories` | partial | yes | no iOS protocol/UI | no | `categories()` | yes | `parseCategories` + categories envelope | SwiftEC yes; legacy no | no fixture-backed operation test | Task 2: validate advertised category support; Task 4: add fixture |
| `category-create` | partial | yes | no iOS protocol/UI | no | `categoryCreate(...)` | yes | mutation parser + message envelope | SwiftEC yes; legacy no | no fixture-backed operation test | Task 4: add category mutation fixture; Task 5 parity decision |
| `category-update` | unsupported-disabled | no protocol/UI call | no | no executable support | no builder | no adapter protocol endpoint | no typed parser/envelope path | not advertised by SwiftEC or legacy | no test | Task 2: either implement fully or keep disabled |
| `category-delete` | partial | yes | no iOS protocol/UI | no | `categoryDelete(categoryID:)` | yes | mutation parser + message envelope | SwiftEC yes; legacy no | no fixture-backed operation test | Task 4: add category mutation fixture; Task 5 parity decision |
| `download-set-category` | unsupported-disabled | no protocol/UI call | no | no executable support | no builder | no adapter protocol endpoint | no typed parser/envelope path | not advertised by SwiftEC or legacy | no test | Task 2: either implement fully or keep disabled |
| `ipfilter-reload` | partial | yes | no iOS protocol/UI | no | `ipfilterReload()` | yes | mutation parser + message envelope | SwiftEC yes; legacy no | no fixture-backed operation test | Task 4: add fixture or disable; Task 5 parity decision |
| `ipfilter-update` | partial | yes | no iOS protocol/UI | no | `ipfilterUpdate(url:)` | yes | mutation parser + message envelope | SwiftEC yes; legacy no | no fixture-backed operation test | Task 4: add fixture or disable; Task 5 parity decision |
| `friends` | bug | yes | no iOS protocol/UI | no | no first-class friends request builder | yes, but sends `sourcesUpdate()` | `parseFriends` expects `EC_OP_SHARED_FILES`; JSON envelope exists | SwiftEC yes; legacy no | no fixture-backed operation test | Task 2: fix friends request/parser capability; Task 4: add fixture |
| `friend-remove` | partial | yes | no iOS protocol/UI | no | `friendRemove(friendID:)` | yes | mutation parser + message envelope | SwiftEC yes; legacy no | no fixture-backed operation test | Task 4: add friend mutation fixture or disable; Task 5 parity decision |
| `friend-slot` | partial | yes | no iOS protocol/UI | no | `friendSlot(friendID:enabled:)` | yes | mutation parser + message envelope | SwiftEC yes; legacy no | no fixture-backed operation test | Task 4: add friend mutation fixture or disable; Task 5 parity decision |
| `stats-tree` | partial | yes | no iOS protocol/UI | no | `statsTree(capping:)` | yes | `parseStatsTree` + stats envelope | SwiftEC yes; legacy no | no fixture-backed operation test | Task 4: add fixture or disable; Task 5 parity decision |
| `stats-graphs` | partial | yes | no iOS protocol/UI | no | `statsGraphs(width:scale:last:)` | yes | `parseStatsGraphs` + stats envelope | SwiftEC yes; legacy no | no fixture-backed operation test | Task 4: add fixture or disable; Task 5 parity decision |

## Main follow-up risks

1. **Capability over-advertisement vs implementation confidence**: SwiftEC advertises many macOS-only operations that legacy does not support and that currently lack fixture-backed tests. Task 2 should remove or explicitly disable any operation that cannot be made correct; Task 4 should add the missing fixtures for operations kept as supported.
2. **Known bug**: `friends()` is advertised and app-callable on macOS, but SwiftEC sends `sourcesUpdate()` and parses the update packet as friends. Task 2 must correct the request path or disable the operation.
3. **Named but disabled operations**: `category-update` and `download-set-category` exist in `ECOperationName` and legacy Swift wrapper helpers, but are not in bridge protocols, SwiftEC builders, adapter endpoints, or advertised capabilities. Task 2 should either implement and test them or keep them explicitly disabled.
4. **Bridge semantic mismatch**: `connect`/`disconnect` mean daemon network connect/disconnect in legacy and SwiftEC builders, but the SwiftEC adapter endpoints currently mean EC session authenticate/local disconnect. Task 2/Task 5 should settle the contract before parity tests lock it in.
