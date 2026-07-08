# ULW Notepad: amulegui vs native macOS backend parity

- Tier: HEAVY - user requested systematic detailed code review and backend implementation comparison across C++ amulegui, Swift macOS client, and SwiftEC.
- Skills: omo:ulw-plan, superpowers:writing-plans; AGENTS.md and native Apple field guide read before planning.
- Request: systematically inspect amulegui and native macOS aMule client, compare backend implementations in detail by reading code, then generate a development plan.
- Skills selected:
  - omo:ulw-plan - user explicitly asked for ULW systematic inspection and a development plan.
  - superpowers:writing-plans - used as format guidance for executable implementation tasks.
  - superpowers:brainstorming - considered because plan creation is design work, but not used as controlling flow because it requires stopping for a separate design approval and the explicit ULW plan skill is more specific.
- Intent: clear; outcome is a detailed code-backed comparison of amulegui backend behavior vs native macOS/SwiftEC and a development plan.
- review_required: true by ULW HEAVY tier, but subagent tools prohibit spawn without explicit subagent request; record local self-review and concrete evidence instead.
- Components ledger:
  - C1 original amulegui/remote GUI backend EC operations and state semantics.
  - C2 native macOS AppModel/UI bridge backend calls.
  - C3 SwiftEC protocol/client/parser/adapter coverage.
  - C4 tests/docs/evidence mapping and implementation plan.
- Key finding: upstream `EC_OP_CLIENT_SWAP_TO_ANOTHER_FILE` is opcode `0x54` and needs `EC_TAG_CLIENT` + `EC_TAG_PARTFILE`; SwiftEC currently aliases it to `0x2A` and accepts only a hash-like client tag while advertising the operation.
- Key finding: current `friends()` using `GET_UPDATE` with `EC_DETAIL_INC_UPDATE` matches daemon mixed update behavior; older parity report's "friends opcode bug" is stale and should be rewritten.
- Key finding: native auto-refresh is fixed interval status/download/server polling, not amulegui's visibility-aware staged poll loop; acceptable as product choice only if request pressure and stale-window behavior are tested/documented.

## Execution bootstrap 2026-07-08

- Tier: HEAVY - implementation touches SwiftEC protocol/client, macOS bridge-facing behavior, tests, docs, and daemon parity semantics.
- User intent: implement the prior ULW findings, not just update the plan.
- Skills used:
  - omo:start-work read for plan execution conventions; full delegation mode is not usable as implementation authority because the available multi-agent tool disallows spawning without explicit subagent authorization, so root will implement and use a HEAVY review gate.
  - build-macos-apps:swiftpm-macos for SwiftPM package build/test workflow.
  - build-macos-apps:test-triage for focused failing-first and failure classification.
- Success criteria:
  - RED proof for wrong advertised client-swap opcode/packet shape, then GREEN with implementation.
  - Mixed `GET_UPDATE` semantics remain tested and green.
  - Search mutation response opcode semantics remain tested and green.
  - Docs no longer contain known stale opcode/friends claims.
  - SwiftEC focused tests pass; broader Swift package/macOS verification attempted and recorded.
- Manual-QA surface:
  - Data/protocol-shaped work: SwiftPM test stdout is the faithful auxiliary surface.
  - Scenario 1: `cd native-macos/AMuleNativeRemote/SwiftEC && swift test --filter ECOperationsTests/testMutatingOperationBuildersUseBridgeOpcodesAndTags`; PASS when `clientSwapToAnotherFile` asserts `0x54` with `EC_TAG_CLIENT` and `EC_TAG_PARTFILE`.
  - Scenario 2: `cd native-macos/AMuleNativeRemote/SwiftEC && swift test --filter ECOperationsTests/testMixedGetUpdatePacketMergesDownloadsSourcesAndFriends`; PASS when mixed `EC_OP_SHARED_FILES` fixture merges downloads/sources/friends.
  - Scenario 3: `cd native-macos/AMuleNativeRemote/SwiftEC && swift test --filter AMuleECBridgeAdapterTests`; PASS when search/mutation response semantics stay green.

## Execution results 2026-07-08

- Implemented client-swap correction:
  - `ECOperations.OpCode.clientSwapToAnotherFile` now uses daemon opcode `0x54`.
  - `swapClientToAnotherFile(clientID:hash:gate:)` now emits `EC_TAG_CLIENT` integer and `EC_TAG_PARTFILE` hash.
  - `client-swap-to-another-file` is removed from `ECSupportedOps.allOperations` and added to `unsupportedDisabledOperations` until Bridge/UI source-client selection exists.
- Added regression coverage:
  - client-swap opcode/tag shape and capability gate behavior.
  - mixed update packet merging downloads, known files, sources, servers, and nested friends.
  - search lifecycle accepting original success opcodes and preserving request order.
- Updated docs:
  - `SwiftEC/Docs/Operations.md` opcode table corrected for shutdown, connstate, last log entry, reset debug log, download search, and client swap.
  - `SwiftEC/Docs/SwiftECV1Contract.md` no longer claims blanket COMPLETE for hidden operations.
  - `docs/superpowers/evidence/2026-07-07-feature-parity-report.md` corrected stale friends/client-swap findings.
- Verification:
  - SwiftEC `swift test`: PASS, 34 protocol + 126 client + 32 bridge tests, 0 failures; 3 live-daemon smoke tests skipped due missing env.
  - SwiftEC forbidden dependency scan: PASS.
  - macOS package `swift test`: PASS, 114 tests, 0 failures.
  - macOS package `swift build -Xswiftc -warnings-as-errors`: PASS.
  - macOS app `./scripts/build-app.sh`: PASS, `** BUILD SUCCEEDED **`, generated `dist/aMule Remote.app`.
  - `git diff --check`: PASS.
- Review notes:
  - No subagent reviewer spawned because available multi-agent tool explicitly forbids spawning without explicit user request for subagents/delegation.
  - Local self-review found no stale documentation claim matches for friends/client-swap/blanket COMPLETE patterns.
  - Remaining parity gaps are broader parser depth and UI contracts, not this protocol/capability fix.
