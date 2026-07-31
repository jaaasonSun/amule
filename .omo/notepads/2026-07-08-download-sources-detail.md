# Download Details Sources Parity - 2026-07-08

## Scope
- User request: full-chain investigation of amulegui download-detail source table, then align native macOS aMule client implementation.
- Tier: HEAVY. Crosses upstream C++ remote GUI behavior, Swift EC protocol parsing, app model cache/refresh, and macOS SwiftUI surface.
- Constraint: existing worktree has unrelated in-progress shared-files/statistics fixes and evidence. Do not revert or fold them into this task.

## Skills / References
- omo:ulw-loop
- omo:debugging
- omo:ulw-plan
- build-macos-apps:build-run-debug
- native macOS field guide

## Success Criteria
- C001 upstream chain documented with concrete file/line references for request, parse/cache, and table display behavior.
- C002 SwiftEC/AppModel source data is associated with the requested/current download and cannot bleed across downloads.
- C003 macOS Download Details source table shows the selected download's sources with amulegui-parity fields where the EC payload provides them, and graceful placeholders otherwise.
- C004 regression evidence includes failing-first proof, final SwiftEC/macOS tests, warning-as-error build, and a real rendered macOS surface or documented closest equivalent.

## Initial Hypotheses
- H1: source responses are parsed without preserving the owning download hash/ECID, so a global source list can be stale or mismatched when the selected download changes.
- H2: the native parser only extracts a subset of EC_TAG_CLIENT children and drops nested fields amulegui uses for table columns.
- H3: the details view refresh path opens with stale cached sources and does not clear or key them while the requested download's source response is pending.

## Artifacts
- Evidence directory: .omo/evidence/download-sources-detail-20260708/
- ULW session: .omo/ulw-loop/download-sources-detail-20260708/

## Findings
- Upstream request/display chain:
  - `src/DownloadListCtrl.cpp:612` collects selected part files and calls `ShowSources`.
  - `src/GenericClientListCtrl.cpp:351` removes rows whose owner is not selected, then rebuilds visible rows from each selected `CPartFile` source set.
  - `src/amule-remote-gui.cpp:1439` only changes a client's request file when `EC_TAG_CLIENT_REQUEST_FILE` is present.
  - `src/ECSpecialCoreTags.cpp:264` emits client fields through an incremental value map, so unchanged request-file/display tags can be omitted.
  - `src/ExternalConn.cpp:662` shows `GET_UPDATE` is a global incremental update, not a selected-download-scoped source query.
- Native root cause confirmed:
  - `ECSourceStateStore.applyClientDelta` previously resolved a missing request-file as `contextRequestFileID` before `existing.requestFileID`.
  - `SwiftECBridgeAdapter.applySourceUpdate` also fell back to direct parser output when no stored sources existed for the selected file, which could fabricate current-download ownership for unknown sparse clients.
- Red phase:
  - Command: `swift test --filter AMuleECBridgeAdapterTests/testAdapterSourcesDoesNotMoveSparseExistingClientToNewSelectedDownload`
  - Result: failed with client 99 returned for requestFileID 77 after sparse delta omitted `EC_TAG_CLIENT_REQUEST_FILE`.
- Green phase:
  - Changed merge precedence to explicit request-file, then existing owner, then guarded context.
  - Guarded parser context so packets with no explicit matching request-file do not invent ownership.
  - Removed bridge adapter fallback parsing; sources now come from the state store.
