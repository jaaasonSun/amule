# Native macOS Download Sources Detail Parity Plan

## Upstream Findings
- `src/DownloadListCtrl.cpp:612` gathers the selected part files and calls `clientlistctrl->ShowSources(filesVector)`.
- `src/GenericClientListCtrl.cpp:351` toggles each selected file's show-sources flag, removes visible source rows whose owner is no longer selected, then rebuilds rows from each selected `CPartFile`'s normal and A4AF source sets.
- `src/amule-remote-gui.cpp:1439` updates a client's `m_reqfile` only when `EC_TAG_CLIENT_REQUEST_FILE` is present. Sparse client deltas without this tag keep the previous owner.
- `src/ECSpecialCoreTags.cpp:264` emits client fields through an incremental `CValueMap`; unchanged fields, including request-file and display fields, can be omitted after the first update.
- `src/ExternalConn.cpp:662` returns `EC_OP_GET_UPDATE` as a global incremental packet containing changed files, clients, servers, and friends. It is not scoped to the selected download.

## Native Findings
- `SwiftECBridgeAdapter.sources(hash:)` resolves a hash to a part-file ECID, sends global `GET_UPDATE`, and asks `ECSourceStateStore` for sources for that ECID.
- The previous merge order used `contextRequestFileID` before the cached `existing.requestFileID`, so a sparse client delta could move from download A to newly selected download B.
- The adapter also fell back to `ECResponseParser.parseSources(packet, requestFileID:)` when the store had no sources for the requested ECID, allowing unknown-owner sparse clients to be fabricated as current-download sources.

## Fix Plan
1. Lock the mismatch with a bridge adapter regression test that selects download A, then download B while receiving a sparse delta for A's existing client.
2. Change source-state merging so explicit request-file wins, missing request-file preserves existing owner, and context is only a last-resort for new clients in a packet that already has at least one explicit matching request-file.
3. Apply the same guarded context rule to direct parser fallback behavior.
4. Remove adapter fallback parsing so `sources(hash:)` returns only state-store-owned sources.
5. Verify parser, store, bridge adapter, full SwiftEC tests, and native macOS build/test gates.
