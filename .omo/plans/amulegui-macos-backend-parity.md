# amulegui-macos-backend-parity - Work Plan

## TL;DR (For humans)
<!-- Fill this LAST, after the detailed plan below is written, so it summarizes the REAL plan. -->
<!-- Plain English for a non-engineer: NO file paths, NO todo numbers, NO wave/agent/tool names. -->

**What you'll get:** A backend-parity pass that makes the native macOS client's advertised capabilities line up with the real aMule daemon protocol, then locks the important amulegui behaviors with tests and refreshed documentation.

**Why this approach:** The Swift backend is already mostly shaped correctly around the daemon's mixed incremental updates, so the work should protect that design instead of replacing it. The one confirmed advertised protocol bug must be fixed first because clients can already discover and call it.

**What it will NOT do:** It will not change the C++ daemon, redesign the UI, add push notifications, or make the macOS app adopt iPhone navigation.

**Effort:** Medium
**Risk:** Medium - protocol changes are narrow, but incorrect EC packet shape can silently break real daemon workflows.
**Decisions to sanity-check:** whether `client-swap-to-another-file` should be implemented as a real source/client action now or hidden until the UI needs it; whether macOS should keep fixed polling or move toward visibility-aware polling.

Your next move: approve execution, or ask for the plan to bias toward hiding unfinished capability instead of implementing it. Full execution detail follows below.

---

> TL;DR (machine): Medium-risk SwiftEC/macOS parity plan: fix advertised client-swap opcode/shape or unadvertise it, lock daemon mixed-update semantics with tests, refresh stale docs, verify Swift packages and macOS build.

## Scope
### Must have
- Correct advertised SwiftEC operations against upstream `src/libs/ec/cpp/ECCodes.h` and daemon dispatch.
- Tests that prove `GET_UPDATE + EC_DETAIL_INC_UPDATE` returns/uses `EC_OP_SHARED_FILES` as a mixed update for downloads, sources, friends, and related removals.
- Tests that keep `friend-shared` unadvertised while documenting daemon failure semantics.
- Tests or documented product decision for fixed vs visibility-aware refresh scheduling.
- Updated SwiftEC and parity documentation with stale claims removed.

### Must NOT have (guardrails, anti-slop, scope boundaries)
- No edits under `src/` unless a test fixture absolutely needs a copied constant reference; C++ is source of truth, not target of this plan.
- No mobile-only navigation or iOS chrome changes.
- No push notification support without a separate demux design.
- No broad AppModel/UI refactor beyond backend-call seams required for tests.
- No generated build products or `.build` artifacts.

## Verification strategy
> Zero human intervention - all verification is agent-executed.
- Test decision: TDD for protocol bugs and parser semantics; tests-after only for documentation-only tasks.
- Framework: SwiftPM `swift test` under `native-macos/AMuleNativeRemote` and `native-macos/AMuleNativeRemote/SwiftEC`; macOS app smoke build with `./scripts/build-app.sh`.
- Evidence: `.omo/evidence/task-<N>-amulegui-macos-backend-parity.md` for each task, containing command output summaries and the exact C++/Swift line refs used.

## Execution strategy
### Parallel execution waves
> Target 5-8 todos per wave. Fewer than 3 (except the final) means you under-split.
- Wave 1: protocol contract and high-confidence bug fix tasks that do not require UI decisions.
- Wave 2: parser/state-store/macOS behavior tests that depend on Wave 1's corrected operation surface.
- Wave 3: docs/evidence refresh and final verification.

### Dependency matrix
| Todo | Depends on | Blocks | Can parallelize with |
| --- | --- | --- | --- |
| 1 | none | 2, 7 | 3, 4 |
| 2 | 1 | 7 | 3, 4, 5 |
| 3 | none | 7 | 1, 2, 4, 5 |
| 4 | none | 7 | 1, 2, 3, 5 |
| 5 | none | 7 | 2, 3, 4 |
| 6 | 1, 3, 4, 5 | 7 | none |
| 7 | 1-6 | final verification | none |

## Todos
> Implementation + Test = ONE todo. Never separate.
<!-- APPEND TASK BATCHES BELOW THIS LINE WITH edit/apply_patch - never rewrite the headers above. -->
- [x] 1. Lock SwiftEC opcode/capability truth against upstream ECCodes
  What to do / Must NOT do: Add a focused test that asserts every advertised mutation opcode that SwiftEC builds matches upstream constants used by daemon dispatch. Fix `ECOperations.OpCode.clientSwapToAnotherFile` from `0x2A` to `0x54`, and change `swapClientToAnotherFile` to either accept `clientID + targetHash` and emit `EC_TAG_CLIENT` + `EC_TAG_PARTFILE`, or remove `client-swap-to-another-file` from `ECSupportedOps.allOperations` until there is a real adapter/UI contract. Do not leave a builder advertised if it cannot form the daemon request.
  Parallelization: Wave 1 | Blocked by: none | Blocks: 2, 7
  References (executor has NO interview context - be exhaustive): `src/libs/ec/cpp/ECCodes.h:80-121`; `src/ExternalConn.cpp:1483-1493`; `src/amule-remote-gui.cpp:2121-2132`; `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECOperations.swift:66-67`; `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECOperations.swift:452-457`; `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECProtocol/ECSupportedOps.swift:95-168`; `native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECClientTests/ECOperationsTests.swift:43-50`.
  Acceptance criteria (agent-executable): from `native-macos/AMuleNativeRemote/SwiftEC`, `swift test --filter ECOperationsTests` passes and asserts `downloadSearchResult == 0x2A`, `clientSwapToAnotherFile == 0x54`, and the client-swap packet includes both client id and partfile hash if still advertised.
  QA scenarios (name the exact tool + invocation): `swift test --filter ECOperationsTests/testMutatingOperationBuildersUseBridgeOpcodesAndTags`; add a negative capability-gate case showing unadvertised/unsupported path if the op is hidden. Evidence `.omo/evidence/task-1-amulegui-macos-backend-parity.md`.
  Commit: Y | `fix(swiftec): align advertised client-swap operation with daemon opcode`

- [x] 2. Add operation-surface parity tests for adapter and capabilities
  What to do / Must NOT do: Add a test that every operation in `ECSupportedOps.allOperations` has either a BridgeProtocol method or an explicitly documented lower-level builder-only rationale. Confirm `friend-shared` remains in `unsupportedDisabledOperations` and absent from advertised capabilities because daemon shared-list handling is disabled. Do not re-advertise `friend-shared`.
  Parallelization: Wave 1 | Blocked by: 1 | Blocks: 7
  References (executor has NO interview context - be exhaustive): `src/ExternalConn.cpp:946-1014`; `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECProtocol/ECSupportedOps.swift:97-168`; `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECBridgeAdapter/SwiftECBridgeAdapter.swift:601-664`; `native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECProtocolTests/ECSupportedOpsTests.swift:149`; `native-macos/AMuleNativeRemote/SwiftEC/Tests/AMuleECClientTests/ECOperationsTests.swift:398-412`.
  Acceptance criteria (agent-executable): from `native-macos/AMuleNativeRemote/SwiftEC`, `swift test --filter ECSupportedOpsTests` and `swift test --filter AMuleECBridgeAdapterTests` pass; tests fail if an advertised op lacks adapter coverage or an explicit exception.
  QA scenarios (name the exact tool + invocation): run `swift test --filter ECSupportedOpsTests/testSupportedOperationsStayInSyncWithBridgeProtocol` after adding it; verify `friend-shared` rejected by `ECCapabilityGate(capabilities: ECOperations.capabilities())`. Evidence `.omo/evidence/task-2-amulegui-macos-backend-parity.md`.
  Commit: Y | `test(swiftec): guard advertised operation surface`

- [x] 3. Preserve mixed `GET_UPDATE` incremental semantics with fixture tests
  What to do / Must NOT do: Build SwiftEC fixtures for daemon mixed update packets containing partfile, knownfile, client, server, and friend tags under `EC_OP_SHARED_FILES`, including sparse delta/removal cases. Assert `ECDownloadStateStore`, `ECSourceStateStore`, `parseFriends`, and `parseDownloads` keep existing data, tombstone removals, and request full resync only when daemon sends unknown sparse partfiles. Do not replace this with direct full-list parsing.
  Parallelization: Wave 1 | Blocked by: none | Blocks: 6, 7
  References (executor has NO interview context - be exhaustive): `src/ExternalConn.cpp:662-725`; `src/amule-remote-gui.h:116-388`; `src/amule-remote-gui.cpp:1103-1167`; `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECResponseParser.swift:393-436`; `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECResponseParser.swift:649-668`; `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECDownloadStateStore.swift:40-148`; `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECSourceStateStore.swift:13-131`.
  Acceptance criteria (agent-executable): from `native-macos/AMuleNativeRemote/SwiftEC`, `swift test --filter ECOperationsTests` passes with new fixtures for mixed update merge, empty child tag removals, source request-file context, and malformed sparse update resync.
  QA scenarios (name the exact tool + invocation): `swift test --filter ECOperationsTests/testMixedGetUpdatePacketMergesDownloadsSourcesAndFriends`; `swift test --filter ECOperationsTests/testSparseUnknownPartFileTriggersFullResync`. Evidence `.omo/evidence/task-3-amulegui-macos-backend-parity.md`.
  Commit: Y | `test(swiftec): lock mixed update merge semantics`

- [x] 4. Lock original search lifecycle and mutation response opcodes
  What to do / Must NOT do: Add/extend tests for search start returning `EC_OP_STRINGS`, stop returning `EC_OP_MISC_DATA`, progress/results as separate requests, search-result download returning `EC_OP_STRINGS`, and duplicate result replacement by ECID. Do not assume all mutations return `NOOP`.
  Parallelization: Wave 1 | Blocked by: none | Blocks: 6, 7
  References (executor has NO interview context - be exhaustive): `src/amule-remote-gui.cpp:1936-2075`; `src/amule-remote-gui.cpp:1769-1777`; `src/ExternalConn.cpp:1017-1129`; `src/ExternalConn.cpp:1589-1612`; `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECBridgeAdapter/SwiftECBridgeAdapter.swift:108-155`; `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECResponseParser.swift:693-730`; `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Search.swift:1-120`.
  Acceptance criteria (agent-executable): from `native-macos/AMuleNativeRemote/SwiftEC`, `swift test --filter AMuleECBridgeAdapterTests` passes with search start/stop/download expected-opcode tests; from `native-macos/AMuleNativeRemote`, app tests cover `AppModel.performSearch`, stop cancellation, and multi-result download fan-out with fake bridge.
  QA scenarios (name the exact tool + invocation): `swift test --filter AMuleECBridgeAdapterTests/testSearchLifecycleAcceptsOriginalSuccessOpcodes`; `swift test --filter AMuleNativeRemoteTests/SearchTests`. Evidence `.omo/evidence/task-4-amulegui-macos-backend-parity.md`.
  Commit: Y | `test(native): verify original search lifecycle semantics`

- [x] 5. Decide and test macOS refresh scheduling divergence from amulegui
  What to do / Must NOT do: Add tests around `startAutoRefresh` cadence using an injectable clock/scheduler if available, or introduce a narrow test seam in `AppModel+Connection.swift`. Verify status refresh every tick, downloads gated by `shouldAutoRefreshDownloads`, servers every five ticks, and no uncontrolled overlapping bridge calls. Document the divergence from amulegui's visibility-aware poll loop as an intentional native behavior, or implement visibility-aware gating only if existing app state already exposes it cleanly. Do not add broad UI state plumbing just for parity.
  Parallelization: Wave 2 | Blocked by: none | Blocks: 6, 7
  References (executor has NO interview context - be exhaustive): `src/amule-remote-gui.cpp:148-203`; `src/amule-remote-gui.cpp:359-399`; `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Connection.swift:76-94`; `native-macos/AMuleNativeRemote/Tests/AMuleNativeRemoteTests/FakeBridgeAdapter.swift:1-220`.
  Acceptance criteria (agent-executable): from `native-macos/AMuleNativeRemote`, `swift test --filter AMuleNativeRemoteTests` passes with deterministic refresh cadence assertions and no sleep-based flaky tests.
  QA scenarios (name the exact tool + invocation): `swift test --filter AMuleNativeRemoteTests/AutoRefreshTests`; record whether final behavior is fixed-cadence documented or visibility-gated implemented. Evidence `.omo/evidence/task-5-amulegui-macos-backend-parity.md`.
  Commit: Y | `test(mac): cover native refresh scheduler parity`

- [x] 6. Refresh parity documentation after executable contract is true
  What to do / Must NOT do: Update `native-macos/AMuleNativeRemote/SwiftEC/Docs/Operations.md`, `native-macos/AMuleNativeRemote/SwiftEC/Docs/SwiftECV1Contract.md`, `native-macos/AMuleNativeRemote/docs/original-amule-ec-protocol-notes.md`, and replace or amend `docs/superpowers/evidence/2026-07-07-feature-parity-report.md`. Remove stale claims such as the old friends opcode bug. Correct opcode tables for `GET_CONNSTATE`, `GET_LAST_LOG_ENTRY`, `DOWNLOAD_SEARCH_RESULT`, and `CLIENT_SWAP_TO_ANOTHER_FILE`. Do not mark implementation "complete" for any operation hidden or intentionally unsupported.
  Parallelization: Wave 3 | Blocked by: 1, 3, 4, 5 | Blocks: 7
  References (executor has NO interview context - be exhaustive): `native-macos/AMuleNativeRemote/SwiftEC/Docs/Operations.md:766-839`; `native-macos/AMuleNativeRemote/SwiftEC/Docs/SwiftECV1Contract.md:7-20`; `native-macos/AMuleNativeRemote/docs/original-amule-ec-protocol-notes.md:133-172`; `docs/superpowers/evidence/2026-07-07-feature-parity-report.md:9-112`; `.omo/evidence/amulegui-macos-backend-parity.md`.
  Acceptance criteria (agent-executable): `rg -n "friends opcode|clientSwapToAnotherFile / downloadSearchResult|0x2A.*clientSwap|Implementation Status: COMPLETE" native-macos/AMuleNativeRemote/SwiftEC/Docs native-macos/AMuleNativeRemote/docs docs/superpowers/evidence/2026-07-07-feature-parity-report.md` returns no stale claims unless explicitly framed as historical.
  QA scenarios (name the exact tool + invocation): run the `rg` command above plus `git diff --check`. Evidence `.omo/evidence/task-6-amulegui-macos-backend-parity.md`.
  Commit: Y | `docs(native): refresh amulegui backend parity evidence`

- [x] 7. Full Swift/macOS verification and clean worktree audit
  What to do / Must NOT do: Run the required Swift package and macOS app verification from AGENTS. Capture failures with exact commands and fix only failures caused by this plan. Do not delete generated artifacts without approval; ignore unrelated dirty files not produced by the task.
  Parallelization: Wave 3 | Blocked by: 1-6 | Blocks: final verification
  References (executor has NO interview context - be exhaustive): `AGENTS.md` build commands; `native-macos/AMuleNativeRemote/docs/coding-agent-field-guide.md`; `.omo/evidence/amulegui-macos-backend-parity.md`.
  Acceptance criteria (agent-executable): from `native-macos/AMuleNativeRemote`, `swift test`, `swift build -Xswiftc -warnings-as-errors`, and `./scripts/build-app.sh` pass; from `native-macos/AMuleNativeRemote/SwiftEC`, `swift test` and `./Scripts/check-forbidden-deps.sh` pass; `git status --short` contains only intended source/docs/evidence changes.
  QA scenarios (name the exact tool + invocation): exact commands listed in acceptance criteria; save summarized logs to `.omo/evidence/task-7-amulegui-macos-backend-parity.md`. Evidence `.omo/evidence/task-7-amulegui-macos-backend-parity.md`.
  Commit: Y | `test(native): verify macos backend parity`

## Final verification wave
> Runs in parallel after ALL todos. ALL must APPROVE. Surface results and wait for the user's explicit okay before declaring complete.
- [x] F1. Plan compliance audit
- [x] F2. Code quality review
- [x] F3. Real manual QA
- [x] F4. Scope fidelity

## Commit strategy
- Prefer three atomic commits if executing manually:
- Commit 1: protocol/capability bug fix and tests.
- Commit 2: parser/AppModel parity tests and any narrow test seams.
- Commit 3: documentation/evidence refresh and final verification notes.
- If the executor chooses to hide `client-swap-to-another-file` instead of implementing it, keep that in the first commit and mention the product decision in the commit body.

## Success criteria
- No advertised SwiftEC operation is known to have a wrong opcode or packet shape against upstream C++.
- Mixed `GET_UPDATE` semantics are protected by tests and docs.
- Friend shared-list behavior is intentionally hidden, not accidentally half-supported.
- Search and mutation response opcode expectations match daemon behavior.
- Native macOS refresh behavior is either tested as intentional divergence or made visibility-aware with tests.
- SwiftEC docs and parity reports no longer contain stale contradictions.
- Required Swift/macOS verification commands pass or have source-backed failure notes.
