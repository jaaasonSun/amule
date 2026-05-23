# Original aMule EC Protocol Behavior And Swift Audit

This document is the protocol reference for native Apple EC work. It intentionally treats the original aMule EC protocol implementation as the source of truth, not the native `amule-ec-bridge` helper.

Primary protocol authorities:

- `src/libs/ec/cpp/ECCodes.h`: protocol version, flags, opcodes, tag names, detail levels.
- `src/libs/ec/cpp/ECSocket.cpp`, `ECSocket.h`: stream framing, negotiated flags, compression, synchronous/asynchronous request behavior.
- `src/libs/ec/cpp/ECPacket.cpp`, `ECPacket.h`: packet body structure and detail-level tag behavior.
- `src/libs/ec/cpp/ECTag.cpp`, `ECTag.h`, `ECTagTypes.h`: tag encoding, child encoding, strings, integers, hashes, IPv4.
- `src/libs/ec/cpp/RemoteConnect.cpp`, `RemoteConnect.h`: original remote-client authentication, request FIFO, async packet handling.
- `src/ExternalConn.cpp`: daemon-side authentication, per-connection state, request dispatch, mutation replies.
- `src/ECSpecialCoreTags.cpp`, `src/libs/ec/cpp/ECSpecialTags.h`: daemon-side model tags for downloads, shared files, clients, servers, search.
- `src/amule-remote-gui.cpp`, `src/amule-remote-gui.h`: original persistent remote GUI client behavior and delta merging.

Non-authority:

- `src/AMuleECBridge.cpp` is useful historical context only. Do not use it as the gold standard for Swift behavior.

## Wire Format

Each EC packet on TCP is:

```text
uint32 flags
uint32 bodyLength
body bytes
```

Header integers are network byte order. Original receive validates:

```text
(flags & 0x60) == 0x20
flags must not contain EC_FLAG_UNKNOWN_MASK
```

Known flags:

- `0x20`: required base protocol marker.
- `EC_FLAG_ZLIB = 0x00000001`: body is zlib-compressed.
- `EC_FLAG_UTF8_NUMBERS = 0x00000002`: EC structural numbers use UTF-8-number encoding.
- `EC_FLAG_UNKNOWN_MASK = 0xff7f7f08`: flags rejected by original receive.

Original send behavior:

- Start with base `0x20`.
- Use zlib only when packet length exceeds the threshold and negotiated zlib is enabled.
- Else use UTF-8-number encoding when negotiated.
- Mask final flags with negotiated `m_my_flags`.

Important Swift audit:

- `ECPacketHeader` correctly encodes/decodes big-endian header integers.
- `ECPacket.decode` rejects invalid flag combinations against `(flags & 0x60) == 0x20` and `EC_FLAG_UNKNOWN_MASK`.
- `ECSession` only enables outgoing compression when both `advertisesZlib` is true and `packetFlags` includes `EC_FLAG_ZLIB`.
- Remaining caution: `ECSession.Configuration` has separate `advertisesZlib`, `advertisesUTF8Numbers`, and `packetFlags`. Callers can still configure inconsistent advertised capabilities and send flags, even though defaults are conservative.

## Packet And Tag Encoding

Packet body:

```text
opcode: uint8/ec_opcode_t
topLevelChildCount: uint16
topLevelTag...
```

`CECPacket(opcode, detail)` represents detail level as an `EC_TAG_DETAIL_LEVEL` child tag, except `EC_DETAIL_FULL`, because full is the default and original C++ omits the tag for full.

Tag layout:

```text
uint16 encodedName = (tagName << 1) | hasChildren
uint8 type
uint32 tagLength
if hasChildren:
    uint16 childCount
    child tags...
value bytes...
```

`tagLength` includes child tag headers, child payloads, child child-count fields, and value bytes. It does not include the parent tag header or the parent child-count field.

Relevant tag types:

- `0`: empty/unknown
- `1`: custom bytes
- `2`, `3`, `4`, `5`: uint8/uint16/uint32/uint64 value bytes in network order
- `6`: UTF-8 string plus NUL
- `7`: double-as-string plus NUL
- `8`: IPv4 endpoint
- `9`: raw 16-byte hash
- `10`: raw 16-byte uint128

Swift audit:

- `ECPacket`, `ECTag`, and the golden tests largely match original fixed-width and UTF-8-number encoding.
- Swift request builders omit `EC_TAG_DETAIL_LEVEL` for `EC_DETAIL_FULL`, matching the original `CECPacket` default-detail behavior.
- Swift strings are UTF-8 plus NUL, matching original EC strings.
- Swift hash tags use raw 16 bytes, matching original EC hash API behavior.

## Authentication

Original blocking client flow:

1. TCP connect.
2. Send `EC_OP_AUTH_REQ`.
3. Receive `EC_OP_AUTH_SALT`.
4. Send `EC_OP_AUTH_PASSWD`.
5. Receive `EC_OP_AUTH_OK` or `EC_OP_AUTH_FAIL`.

`EC_OP_AUTH_REQ` contains:

- `EC_TAG_CLIENT_NAME`
- `EC_TAG_CLIENT_VERSION`
- `EC_TAG_PROTOCOL_VERSION = 0x0204`
- optional `EC_TAG_CAN_ZLIB`
- optional `EC_TAG_CAN_UTF8_NUMBERS`
- optional `EC_TAG_CAN_NOTIFY`

Daemon behavior:

- Rejects missing/wrong protocol version.
- Records zlib/UTF-8-number/notification support on the connection after auth request.
- Sends `EC_OP_AUTH_SALT` with `EC_TAG_PASSWD_SALT`.
- Verifies password as `MD5(lowercaseStoredPasswordMD5 + MD5(hexSaltUppercase))`.
- On success sends `EC_OP_AUTH_OK` with `EC_TAG_SERVER_VERSION`.
- If `EC_TAG_CAN_NOTIFY` was advertised, registers the client for push notifications after auth success.

Swift audit:

- `ECLegacyAuth` correctly normalizes plaintext or prehashed passwords and computes the salted response.
- `ECAuthPacket` can advertise zlib/UTF-8/notify, but default `ECSession.Configuration` advertises none.
- Swift does not currently support notification dispatch, so it should not advertise notify until an async receiver/demux exists.
- Swift should couple advertised zlib/UTF-8 capabilities to actual packet flags; today they are independent configuration fields.

## Request/Reply, FIFO, And Push Behavior

Original client has two request styles:

- `SendRecvPacket`: synchronous send, read one reply.
- `SendPacket` / `SendRequest`: asynchronous send with request FIFO. Replies are later matched to request handlers. Push packets can also arrive when notification support is enabled.

Original remote GUI is a persistent event-driven client. It does not assume each logical model can be rebuilt from one packet. It keeps local objects and applies packet deltas.

Daemon mutation convention:

- Success usually returns `EC_OP_NOOP`.
- Failure returns `EC_OP_FAILED` plus `EC_TAG_STRING`.
- Some successful operations intentionally return other opcodes: `EC_OP_SEARCH_START` returns `EC_OP_STRINGS`, `EC_OP_SEARCH_STOP` returns `EC_OP_MISC_DATA`, `EC_OP_DOWNLOAD_SEARCH_RESULT` returns `EC_OP_STRINGS`, and core connect/disconnect can return `EC_OP_STRINGS`.
- Some calls are queued by the original GUI with `SendPacket`; they still normally produce replies, but the GUI does not block UI state on a one-shot socket lifetime.

Swift audit:

- `ECRequestPipeline` serializes one send/read at a time and assumes the next packet is the reply.
- With notify disabled, that is acceptable for request/reply operations.
- Swift has no packet demux for push or unsolicited packets.
- `ECResponseParser` validates expected response opcodes for read operations and mutation success replies. This prevents wrong/out-of-order packets from being silently interpreted as empty lists or default values.
- `ECSession.send` reconnects after an error and then throws the original error. For mutations this can create ambiguous "did it apply?" behavior. Rename has a special connection-closed fallback, but this should not be generalized blindly.

Current Swift response opcode matrix:

| Request | Expected success response |
| --- | --- |
| `EC_OP_STAT_REQ` | `EC_OP_STATS` |
| `EC_OP_GET_DLOAD_QUEUE` | `EC_OP_DLOAD_QUEUE` |
| `EC_OP_GET_UPDATE + EC_DETAIL_INC_UPDATE` | `EC_OP_SHARED_FILES` |
| `EC_OP_GET_SERVER_LIST` | `EC_OP_SERVER_LIST` |
| `EC_OP_SEARCH_PROGRESS` | `EC_OP_SEARCH_PROGRESS` |
| `EC_OP_SEARCH_RESULTS` | `EC_OP_SEARCH_RESULTS` |
| `EC_OP_GET_PREFERENCES` | `EC_OP_SET_PREFERENCES` |
| pause/resume/cancel/rename/server/prefs-set/add-link | `EC_OP_NOOP` |
| `EC_OP_SEARCH_START` | `EC_OP_STRINGS` |
| `EC_OP_SEARCH_STOP` | `EC_OP_MISC_DATA` |
| `EC_OP_DOWNLOAD_SEARCH_RESULT` | `EC_OP_STRINGS` |

## Detail Levels

Original detail levels:

```text
EC_DETAIL_CMD        = 0x00
EC_DETAIL_WEB        = 0x01
EC_DETAIL_FULL       = 0x02
EC_DETAIL_UPDATE     = 0x03
EC_DETAIL_INC_UPDATE = 0x04
```

Behavior is model-specific:

- `FULL`: stable fields plus heavier fields.
- `CMD`: often a compact command/list view; for download queue it still includes enough identity to look up ECID/hash.
- `UPDATE`: omit stable fields such as names/hashes/sizes in many tags.
- `INC_UPDATE`: connection-local incremental update stream with value maps and RLE/delta encoders.

Swift audit:

- Swift only models `command`, `full`, and `incrementalUpdate`.
- This is enough for current calls, but parsers must understand that update packets can omit fields previously sent.

## Daemon Connection-Local State

`CECServerSocket` owns state that affects later packets on the same EC connection:

- `CFileEncoderMap m_FileEncoder`: per-known-file/part-file encoders.
- `CObjTagMap m_obj_tagmap`: per-ECID value maps for tags.
- `CPartFile_Encoder`: RLE state for part/gap/request status and a source-name ID map.

Consequences:

- The same request on the same connection may produce fewer tags later.
- `EC_OP_GET_UPDATE + EC_DETAIL_INC_UPDATE` is a delta feed, not a snapshot.
- Source-name alternatives are sent as changes against a per-connection source-name map.
- `CPartFile_Encoder::ResetEncoder()` resets part/gap/request RLE state but does not reset the source-name ID map.

Swift audit:

- Stateless parsers still decode a single packet, by design.
- `ECDownloadStateStore` merges full snapshots with incremental source-name deltas, including count-only updates and count-zero deletions.
- `ECSourceStateStore` merges sparse client/source deltas so fields such as `EC_TAG_CLIENT_REQUEST_FILE` can be preserved when omitted later.
- UI-facing adapter methods should use these state stores rather than parsing `GET_UPDATE` directly into UI arrays.

## Download List Semantics

There are three related mechanisms:

- `EC_OP_GET_DLOAD_QUEUE`: direct download queue request. Daemon replies `EC_OP_DLOAD_QUEUE`.
- `EC_OP_GET_UPDATE + EC_DETAIL_INC_UPDATE`: update-all request. Daemon replies `EC_OP_SHARED_FILES` containing part files, shared known files, clients, servers, and friends.
- Push notifications: daemon may send packets when dirty-status sources fire, if the client advertised notify.

Original remote GUI:

- Starts a persistent connection.
- Calls `knownfiles->DoRequery(EC_OP_GET_UPDATE, EC_TAG_KNOWNFILE)` after connect and on poll.
- Maintains local `CKnownFile`/`CPartFile` objects keyed by ECID.
- Applies incremental part-file tags to existing objects.
- Maintains source-name alternatives through `SourcenameItemMap` keyed by IDs sent in `EC_TAG_PARTFILE_SOURCE_NAMES`.

Practical rules for Swift:

- A UI list snapshot can use `EC_OP_GET_DLOAD_QUEUE` full detail to avoid replacing the list with a sparse delta.
- Any data that is only available through incremental state, especially alternative names and some source/client details, requires a persistent merge cache.
- Do not replace an entire visible list with a single `EC_OP_GET_UPDATE` packet.
- Do not expect `GET_DLOAD_QUEUE` to rebuild the source-name map after it has already been populated on the daemon connection.

Swift audit:

- Current `downloads()` uses `GET_DLOAD_QUEUE` full detail. This fixed the "downloads disappeared" regression.
- Current `downloads()` returns a merged model: full snapshot fields from `GET_DLOAD_QUEUE`, plus cached incremental fields from `GET_UPDATE`.
- Reliability still depends on a persistent EC session for connection-local daemon source-name IDs. Ephemeral per-operation sessions can only use source-name data present on that new connection.

## Source Names / Alternative Names

Daemon encoding:

1. Count remote filenames from sources whose request file is this part file.
2. Compare counts against `m_sourcenameItemMap`.
3. For removed names, send an `EC_TAG_PARTFILE_SOURCE_NAMES` child with the old ID and count `0`.
4. For changed counts, send old ID plus new count; the name may be omitted.
5. For new names, allocate a new ID and send ID, name, and count.

Original remote GUI decoding:

- Looks up `EC_TAG_PARTFILE_SOURCE_NAMES`.
- For each child, key is child integer value.
- Count `0` deletes that key.
- Nonzero count updates or creates that key.
- Name is only updated if a name child is present.

Swift audit:

- Public `ECDownload.AlternativeName` intentionally does not expose protocol IDs.
- `ECDownloadStateStore` keeps internal per-download source-name IDs and exposes sorted public alternative names.
- `parseAlternativeNames` remains a stateless snapshot helper; stateful adapter paths should prefer `ECDownloadStateStore`.

Required design:

- Add an internal protocol state object keyed by download ECID and/or hash.
- Store alternative names as `id -> (name, count)`.
- Apply source-name deltas from every incremental part-file tag.
- Expose sorted `[AlternativeName]` without leaking protocol IDs to UI.
- Reset this cache only when the EC session changes or when the file disappears from the queue.

## Sources / Client Details

Daemon `GET_UPDATE` includes a top-level `EC_TAG_CLIENT` container whose children are client tags. Client tags also use `CObjTagMap`, so unchanged fields may be omitted.

Original remote GUI keeps client objects and applies deltas. It does not expect every client packet to contain every field.

Swift audit:

- `sources(hash:)` first maps hash to part-file ECID via `GET_DLOAD_QUEUE`.
- Then it sends `GET_UPDATE` and filters client tags whose `EC_TAG_CLIENT_REQUEST_FILE` equals that ECID.
- `ECSourceStateStore` preserves `EC_TAG_CLIENT_REQUEST_FILE` and other previously seen fields when later incremental packets omit unchanged tags.

## Rename Protocol

Request:

```text
EC_OP_RENAME_FILE
    EC_TAG_KNOWNFILE      HASH16(fileHash)
    EC_TAG_PARTFILE_NAME  STRING(newName)
```

Daemon behavior:

- Look in download queue by MD4 hash.
- If not found, look in known files by MD4 hash.
- Missing file: `EC_OP_FAILED + "File not found."`
- Empty name: `EC_OP_FAILED + "Invalid file name."`
- Part file: fail only if status is `PS_COMPLETING`; otherwise set filename, save part.met, notify download/shared file UI.
- Completed known file: attempts filesystem rename; filesystem/path/locale failures can matter.
- Success: `EC_OP_NOOP`.
- Failure: `EC_OP_FAILED + "Unable to rename file."`

Original remote GUI sends:

```text
EC_TAG_KNOWNFILE = file->GetFileHash()
EC_TAG_PARTFILE_NAME = newName.GetPrintable()
SendPacket(&request)
```

Swift audit:

- `ECOperations.rename` uses the correct opcode and tags.
- Swift sends UTF-8 EC strings; EC itself supports non-ASCII.
- If non-ASCII rename still fails, likely causes are daemon-side `CPath(newName)` conversion, completed-file filesystem rename, invalid filename characters, or wrong object identity, not EC string encoding.
- Current Swift rename waits for a reply and surfaces `EC_OP_FAILED`. That is more diagnosable than fire-and-forget.
- The iOS wrapper now uses a persistent session. That aligns better with original remote GUI but exposed missing stateful-merge logic elsewhere.

## Search Semantics

Current Swift flow:

- `EC_OP_SEARCH_START`
- Poll `EC_OP_SEARCH_PROGRESS`
- Poll `EC_OP_SEARCH_RESULTS` full detail

This is mostly stateless because search results are requested with full detail and are independently identifiable by search result ECID.

Risk:

- If future code switches search to update detail, it must merge by result ECID like the original search list.

## Server Semantics

`EC_OP_GET_SERVER_LIST` with full detail returns `EC_OP_SERVER_LIST` and is suitable as a snapshot.

`GET_UPDATE` also includes servers inside a top-level `EC_TAG_SERVER` container, but those are delta/value-map driven and require merge semantics.

Swift audit:

- Current `servers()` uses full server list snapshot. Good.
- `parseServers` handles top-level server tags, not the nested update container shape. That is fine for current snapshot use.

## Preferences And Mutations

Preference get/set and most mutations use request/reply:

- Success: `EC_OP_NOOP` or a model packet.
- Failure: `EC_OP_FAILED + EC_TAG_STRING`.
- `EC_OP_GET_PREFERENCES` is a special case: the daemon replies with `EC_OP_SET_PREFERENCES` because `CEC_Prefs_Packet` is constructed with that opcode.

Swift audit:

- `parseMutationResponse` surfaces `EC_OP_FAILED` and validates the operation-specific success opcode set.
- Mutating operations should not be followed by assumptions that one sparse `GET_UPDATE` packet is a full refresh.

## Current Swift Implementation Sweep

Low-level protocol:

- OK: big-endian header encoding.
- OK: packet body structure.
- OK: tag child length behavior.
- OK: UTF-8 string + NUL.
- OK: legacy auth hash computation.
- OK: incoming flag validation rejects missing base protocol flags and unknown flags.
- OK: zlib send is tied to configured advertised capability and zlib packet flag.
- Risk: advertised capability flags and packet flags can still disagree if a caller overrides defaults inconsistently.

Session/request layer:

- OK: serial request pipeline for non-notify request/reply usage.
- OK: persistent session is available via injected `ECSession`.
- Gap: no demux for notifications or unsolicited packets.
- Gap: no FIFO handler model for async fire-and-forget operations.
- Risk: automatic reconnect after write/read failure can make mutation outcomes ambiguous.

Operation builders:

- OK: rename wire format.
- OK: pause/resume/cancel part-file hash tag shape.
- OK: server snapshot operation.
- OK: full-detail requests omit explicit `EC_TAG_DETAIL_LEVEL`, matching original C++.
- OK: `sourcesUpdate()` represents `GET_UPDATE + EC_DETAIL_INC_UPDATE` for merge-only incremental state.
- Gap: no full first-class typed parser for every `GET_UPDATE` container; current state stores only cover downloads/source names and client/source details needed by the native apps.

Response parsers:

- OK: can parse full part-file tags.
- OK: can parse source-name entries when name and count are present in the same packet.
- OK: read operations validate expected response opcodes.
- OK: mutation parser validates operation-specific success opcodes.
- OK: stateful merge exists for download snapshots, source-name IDs/counts/deletions, and client/source deltas.
- Risk: using stateless parsers directly on update packets can still turn omitted fields into default values. Adapter/UI paths should go through the state stores.

Bridge adapter:

- OK: injected persistent `ECSession` can model original remote GUI session lifetime.
- OK: adapter owns an EC model state cache for downloads/source names/sources.
- Gap: default adapter still creates ephemeral sessions per operation; that loses connection-local daemon state. Native app code should inject or reuse a persistent session when it needs incremental-only fields.
- Risk: `capabilities()` returns local synthetic capabilities, not daemon-supported-op negotiation.

Tests:

- Good: packet/tag golden tests exist.
- Good: rename wire-format tests exist.
- Good: parser tests cover static alternative-name entries.
- Good: tests cover source-name delta merge: new, count-only update, deletion.
- Good: tests cover sparse `GET_UPDATE` packets preserving previous source/client values.
- Good: tests prove zlib is not sent unless configured/advertised.
- Good: tests reject invalid incoming flags.
- Good: tests cover persistent-session downloads plus alternatives.
- Good: tests reject unexpected response opcodes and lock `GET_PREFERENCES -> EC_OP_SET_PREFERENCES`.

## Current Recommended Architecture

Keep the EC model state layer below `SwiftECBridgeAdapter`:

- `ECBridgeModelState`: actor owned by the adapter.
- `ECDownloadStateStore`: keyed by ECID, stores latest full download fields plus source-name protocol IDs.
- `ECSourceStateStore`: keyed by client ECID, stores latest client/source fields for source detail views.

Read methods should be explicit:

- `loadDownloadSnapshot()`: send `GET_DLOAD_QUEUE` full, parse full rows, merge cached incremental-only fields, remove vanished files.
- `applyUpdatePacket()`: send `GET_UPDATE` inc, merge part-file, known-file, client, server, friend deltas into state.
- `downloads()`: for UI, return state after snapshot plus optional update merge.
- `sources(hash:)`: return client state filtered by cached request-file ECID, after applying update.

Do not parse `GET_UPDATE` directly into UI arrays without a merge state.

## Completed Guardrails

- Added protocol-state tests for source-name deltas before changing merge code.
- Added `ECDownloadStateStore` and `ECSourceStateStore` for stateful update merging.
- Taught `SwiftECBridgeAdapter.downloads()` to return full download snapshots plus optional incremental dynamic fields.
- Taught `SwiftECBridgeAdapter.sources(hash:)` to use client-state merge instead of filtering a single sparse update packet.
- Fixed zlib negotiation so Swift never sends compressed packets unless configured as advertised and flagged.
- Added invalid-flag tests and rejected invalid incoming flags.
- Added response-opcode validation tests for read parsers and operation-specific mutation replies.

## Remaining Protocol Improvements

- Add a demux/dispatcher before enabling `EC_TAG_CAN_NOTIFY`; notification packets can otherwise be mistaken for request replies.
- Decide whether the default adapter should create a persistent session instead of ephemeral per-operation sessions, or clearly restrict it to snapshot-only use.
- Add first-class typed parsers/stores for more `GET_UPDATE` containers if the native apps expose shared files, uploads, server deltas, friends, logs, or stats trees.
- Add live-daemon integration tests or a simulator harness for rename, search, preferences, and source-name updates against original `ExternalConn.cpp` behavior.
- Consider normalizing `ECSession.Configuration` so advertised zlib/UTF-8 capabilities cannot drift from packet flags.

## Manual QA Checklist After State Fix

- Connect on iPhone and iPad.
- Confirm download list stays populated across auto-refresh.
- Open a download with known remote alternative names; confirm names persist after refresh.
- Wait for a source-name count change; confirm count updates without losing names.
- Rename ASCII part file; confirm list refresh shows new name.
- Rename non-ASCII part file; if failure persists, record daemon `EC_OP_FAILED` message.
- Open sources for a file repeatedly; confirm sources do not disappear on later refreshes.
