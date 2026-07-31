# Code Review: download sources unchanged delta

Recommendation: APPROVE

Reviewed scope:
- `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECSourceStateStore.swift`
- `native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECClientTests/ECSourceStateStoreTests.swift`
- `native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECBridgeAdapterTests/AMuleECBridgeAdapterTests.swift`
- `native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/DownloadSourcesDetailParityTests.swift`

Findings:
- No blockers found.
- The core fix aligns with upstream amulegui semantics: a client tag with no child tags is an unchanged client delta, not a source deletion.
- Source pruning is now limited to full client-container updates, matching the daemon update shape where absent clients are removed from the visible client list.
- The previous sparse-delta wrong-owner regression remains covered: missing `EC_TAG_CLIENT_REQUEST_FILE` no longer invents ownership for the newly selected download.

Risk notes:
- Direct client tags outside a full container do not prune stale sources. This is intentional because they represent sparse updates in the native store tests and bridge adapter path.
- Live daemon smoke tests remain skipped unless `AMULE_EC_HOST`, `AMULE_EC_PORT`, and `AMULE_EC_PASSWORD` are set.

Evidence:
- `.omo/evidence/download-sources-empty-20260708/c001-swiftec-red-green.txt`
- `.omo/evidence/download-sources-empty-20260708/c002-wrong-download-regression.txt`
- `.omo/evidence/download-sources-empty-20260708/source-store-final.txt`
- `.omo/evidence/download-sources-empty-20260708/parser-final.txt`
- `.omo/evidence/download-sources-empty-20260708/swiftec-full-test.txt`
- `.omo/evidence/download-sources-empty-20260708/native-full-test.txt`
