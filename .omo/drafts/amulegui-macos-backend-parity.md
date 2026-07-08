---
slug: amulegui-macos-backend-parity
status: awaiting-approval
intent: clear
pending-action: user approval to execute .omo/plans/amulegui-macos-backend-parity.md
approach: preserve SwiftEC's existing mixed-update architecture, fix the one confirmed advertised protocol bug first, then lock amulegui/daemon semantics with tests and refreshed docs
---

# Draft: amulegui-macos-backend-parity

## Components (topology ledger)
<!-- Lock the SHAPE before depth. One row per top-level component that can succeed or fail independently. -->
<!-- id | outcome (one line) | status: active|deferred | evidence path -->
- C1 | Original amulegui/daemon EC backend behavior is line-cited and treated as protocol truth | active | `.omo/evidence/amulegui-macos-backend-parity.md`
- C2 | SwiftEC operation builders and supported-op advertisement match `src/libs/ec/cpp/ECCodes.h` and daemon dispatch | active | `.omo/evidence/amulegui-macos-backend-parity.md`
- C3 | SwiftEC parser/state-store behavior preserves mixed `GET_UPDATE` incremental semantics | active | `.omo/evidence/amulegui-macos-backend-parity.md`
- C4 | Native macOS AppModel backend calls stay consistent with SwiftEC contract without adopting mobile-only behavior | active | `.omo/evidence/amulegui-macos-backend-parity.md`
- C5 | Stale parity docs are rewritten after tests capture the new source of truth | active | `.omo/evidence/amulegui-macos-backend-parity.md`

## Open assumptions (announced defaults)
<!-- Record any default you adopt instead of asking, so the user can veto it at the gate. -->
<!-- assumption | adopted default | rationale | reversible? -->
- Target | native macOS + shared SwiftEC only; iOS touched only if shared protocol tests require fixture updates | User asked for macOS client comparison | yes
- Friend shared files | keep unadvertised and disabled | daemon code currently returns failure / not implemented for shared friend list | yes, if product decides to build UX around daemon limitation
- Notify support | keep disabled | SwiftEC has no unsolicited packet demux; original remote GUI also disables notify capability in normal config | yes
- Multi-select commands | acceptable to fan out one request per selected item unless daemon batch behavior is explicitly needed for performance | AppModel already loops for pause/resume/cancel/search downloads | yes

## Findings (cited - path:lines)
- Original remote GUI uses a staged 1s poll loop: status every tick, mixed update/search/stats only when relevant windows are visible (`src/amule-remote-gui.cpp:148-203`).
- Original startup constructs remote containers for servers, stats, clients, search, friends, shared files, known files, downloads, IP filter, then starts poll timers (`src/amule-remote-gui.cpp:359-399`).
- Original `CRemoteContainer` tracks idle/status/full request state and removes local items omitted by core updates (`src/amule-remote-gui.h:116-388`).
- Daemon `GET_UPDATE + EC_DETAIL_INC_UPDATE` returns `EC_OP_SHARED_FILES`, containing part files, known files, clients, servers, and friends (`src/ExternalConn.cpp:662-725`).
- Swift parsers/state stores intentionally accept `EC_OP_SHARED_FILES` for incremental download/source/friend handling (`native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECResponseParser.swift:393-733`, `ECDownloadStateStore.swift:40-148`, `ECSourceStateStore.swift:13-131`).
- SwiftEC advertises `client-swap-to-another-file`, but `ECOperations` incorrectly aliases it to opcode `0x2A` and sends only a hash-like `EC_TAG_CLIENT` (`native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECProtocol/ECSupportedOps.swift:95-168`, `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECOperations.swift:66-67`, `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECOperations.swift:452-457`).
- Upstream says `EC_OP_DOWNLOAD_SEARCH_RESULT = 0x2A` and `EC_OP_CLIENT_SWAP_TO_ANOTHER_FILE = 0x54`; client swap dispatch expects a client ECID and partfile hash (`src/libs/ec/cpp/ECCodes.h:80-121`, `src/ExternalConn.cpp:1483-1493`).
- Old parity docs contain stale/wrong claims such as "friends opcode mismatch"; current code's `friends()` via `GET_UPDATE` matches daemon mixed-update behavior (`docs/superpowers/evidence/2026-07-07-feature-parity-report.md:191-200`, `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECOperations.swift:393-396`).
- Native auto-refresh is simpler than amulegui's visibility-aware polling (`native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Connection.swift:76-94`).

## Decisions (with rationale)
- Do not rewrite the backend around direct per-list full fetches. SwiftEC already models daemon connection-local deltas through state stores; the plan strengthens tests around that model instead.
- Treat advertised capabilities as a user-facing contract: any op in `ECSupportedOps.allOperations` must have a correct builder, adapter surface, parser/response expectation if needed, and at least one test tied to C++ semantics.
- Fix or unadvertise `client-swap-to-another-file` before broader parity polishing because it is the only confirmed advertised operation with the wrong opcode and packet shape.
- Refresh docs only after tests change, so documentation follows executable contract rather than becoming another stale report.

## Scope IN
- SwiftEC operation builder/capability contract tests.
- SwiftEC mixed update parser/state-store tests for downloads, sources, friends, servers/knownfile coexistence.
- macOS `AppModel` backend-call tests around polling/search/download command behavior where fake bridge coverage is sufficient.
- Documentation updates for operation opcode table and parity report.

## Scope OUT (Must NOT have)
- No C++ daemon behavior changes.
- No mobile navigation/chrome changes.
- No push notification support unless a future plan designs async demux.
- No broad UI redesign.
- No generated build artifacts committed.

## Open questions
- Should `client-swap-to-another-file` become a real user-visible macOS action, or should it be removed from advertised capabilities until a source/client selection UX exists?
- Should native macOS keep fixed polling, or should it adopt amulegui-style visibility-aware refresh scheduling for high-load daemons?

## Approval gate
status: awaiting-approval
<!-- When exploration is exhausted and unknowns are answered, set status: awaiting-approval. -->
<!-- That durable record is the loop guard: on a later turn read it and resume at the gate instead of re-running exploration. -->
