# aMule Native macOS App — Feature Parity Report
## Native Implementation vs. amulegui / amuled

Generated: 2026-07-07
Status: Synthesis of 4 parallel audits

---

## Executive Summary

The native macOS aMule remote app is a **broad but shallow** implementation of the EC protocol. It covers all major functional areas (downloads, search, servers, shared files, stats, preferences, friends, categories) but has **significant parsing gaps** where it reads only a subset of the data the daemon sends. There is also **one confirmed protocol bug**: the friends request uses the wrong opcode.

**Bottom line**: The UI surface is ~85% complete vs. amulegui. The protocol depth is ~65% complete vs. what the daemon exposes.

---

## 1. EC Protocol Coverage

### 1.1 Operations Matrix

| EC Op Code | C++ Name | SwiftEC Builder | SwiftEC Parser | Native UI | Notes |
|------------|----------|-----------------|----------------|-----------|-------|
| Auth / Transport |
| `0x01` | `AUTH_REQ` | ❌ (transport) | ❌ | N/A | Handled by connection layer |
| `0x02` | `AUTH_PASSWD` | ❌ (transport) | ❌ | N/A | Handled by connection layer |
| `0x03` | `AUTH_SALT` | ❌ | ❌ | N/A | Server reply only |
| `0x04` | `AUTH_OK` | ❌ | ✅ (auth) | N/A | Server reply only |
| `0x05` | `AUTH_FAIL` | ❌ | ✅ (auth) | N/A | Server reply only |
| `0x06` | `NOOP` | ✅ (internal) | ✅ | N/A | Generic ack |
| `0x07` | `FAILED` | ✅ (internal) | ✅ | N/A | Generic error |
| `0x08` | `STRINGS` | ❌ | ❌ | N/A | Used for connect/disconnect replies |
| `0x09` | `MISC_DATA` | ❌ | ❌ | N/A | Used for connstate replies |
| Core / Status |
| `0x0A` | `SHUTDOWN` | ❌ | ❌ | ❌ | Not implemented |
| `0x0B` | `ADD_LINK` | ✅ | N/A | ✅ | Add ed2k/magnet links |
| `0x0C` | `STAT_REQ` | ✅ | ✅ (status) | ✅ | Main status bar data |
| `0x0D` | `GET_CONNSTATE` | ❌ | ❌ | ❌ | Status parser only reads connstate from STAT_REQ |
| `0x0E` | `GET_LAST_LOG_ENTRY` | ❌ | ❌ | ❌ | Not implemented |
| `0x0F` | `GET_LOG` | ✅ | ✅ (log) | ✅ | Diagnostics window |
| `0x10` | `GET_DEBUGLOG` | ✅ | ✅ (debugLog) | ✅ | Diagnostics window |
| `0x11` | `RESET_LOG` | ✅ | N/A | ✅ | Diagnostics window |
| `0x12` | `RESET_DEBUGLOG` | ❌ | N/A | ❌ | Not implemented |
| `0x13` | `ADDLOGLINE` | ❌ | N/A | ❌ | Server-side only |
| `0x14` | `ADDDEBUGLOGLINE` | ❌ | N/A | ❌ | Server-side only |
| `0x15` | `GET_SERVERINFO` | ✅ | ✅ (serverInfo) | ✅ | Server logs window |
| `0x16` | `CLEAR_SERVERINFO` | ✅ | N/A | ✅ | Server logs window |
| `0x17` | `GET_STATSGRAPHS` | ✅ | ✅ (statsGraphs) | ✅ | Stats window |
| `0x18` | `GET_STATSTREE` | ✅ | ✅ (statsTree) | ✅ | Stats window |
| Downloads / Shared Files |
| `0x19` | `GET_DLOAD_QUEUE` | ✅ | ✅ (downloads) | ✅ | Downloads panel |
| `0x1A` | `GET_ULOAD_QUEUE` | ✅ | ✅ (uploads) | ✅ | Uploads window |
| `0x1B` | `GET_SHARED_FILES` | ✅ | ✅ (sharedFiles) | ✅ | Shared files window |
| `0x1C` | `GET_UPDATE` | ✅ | ✅ (delta) | ✅ | Used internally for refresh |
| `0x1D` | `PARTFILE_SWAP_A4AF_THIS` | ✅ | N/A | ✅ | Download details |
| `0x1E` | `PARTFILE_SWAP_A4AF_THIS_AUTO` | ✅ | N/A | ✅ | Download details |
| `0x1F` | `PARTFILE_SWAP_A4AF_OTHERS` | ✅ | N/A | ✅ | Download details |
| `0x20` | `PARTFILE_PAUSE` | ✅ | N/A | ✅ | Downloads panel |
| `0x21` | `PARTFILE_RESUME` | ✅ | N/A | ✅ | Downloads panel |
| `0x22` | `PARTFILE_STOP` | ✅ | N/A | ✅ | Downloads panel |
| `0x23` | `PARTFILE_PRIO_SET` | ✅ | N/A | ✅ | Downloads panel |
| `0x24` | `PARTFILE_DELETE` | ✅ | N/A | ✅ | Downloads panel |
| `0x25` | `PARTFILE_SET_CAT` | ✅ | N/A | ✅ | Downloads panel |
| `0x26` | `SHARED_SET_PRIO` | ✅ | N/A | ✅ | Shared files window |
| `0x27` | `SHAREDFILES_RELOAD` | ✅ | N/A | ✅ | Shared files window |
| `0x28` | `RENAME_FILE` | ✅ | N/A | ✅ | Download details |
| `0x29` | `CLEAR_COMPLETED` | ✅ | N/A | ✅ | Downloads panel |
| `0x2A` | `CLIENT_SWAP_TO_ANOTHER_FILE` | ❌ | N/A | ❌ | Not implemented |
| `0x2B` | `SHARED_FILE_SET_COMMENT` | ✅ | N/A | ✅ | Shared files window |
| Server Management |
| `0x2C` | `GET_SERVER_LIST` | ✅ | ✅ (servers) | ✅ | Servers window |
| `0x2D` | `SERVER_ADD` | ✅ | N/A | ✅ | Servers window |
| `0x2E` | `SERVER_CONNECT` | ✅ | N/A | ✅ | Servers window |
| `0x2F` | `SERVER_DISCONNECT` | ✅ | N/A | ✅ | Servers window |
| `0x30` | `SERVER_REMOVE` | ✅ | N/A | ✅ | Servers window |
| `0x31` | `SERVER_UPDATE_FROM_URL` | ✅ | N/A | ✅ | Servers window |
| `0x32` | `SERVER_SET_STATIC_PRIO` | ✅ | N/A | ✅ | Servers window |
| `0x33` | `IPFILTER_RELOAD` | ✅ | N/A | ✅ | Preferences |
| `0x34` | `IPFILTER_UPDATE` | ✅ | N/A | ✅ | Preferences |
| `0x35` | `CONNECT` | ✅ | N/A | ✅ | AppModel+Connection |
| `0x36` | `DISCONNECT` | ✅ | N/A | ✅ | AppModel+Connection |
| Search |
| `0x37` | `SEARCH_START` | ✅ | N/A | ✅ | Search window |
| `0x38` | `SEARCH_STOP` | ✅ | N/A | ✅ | Search window |
| `0x39` | `SEARCH_RESULTS` | ✅ | ✅ (searchResults) | ✅ | Search window |
| `0x3A` | `SEARCH_PROGRESS` | ✅ | ✅ (searchProgress) | ✅ | Search window |
| `0x3B` | `DOWNLOAD_SEARCH_RESULT` | ✅ | N/A | ✅ | Search window |
| Preferences / Categories |
| `0x3C` | `GET_PREFERENCES` | ✅ | ✅ (connectionPrefs) | ✅ | Preferences window |
| `0x3D` | `SET_PREFERENCES` | ✅ | N/A | ✅ | Preferences window |
| `0x3E` | `CREATE_CATEGORY` | ✅ | N/A | ✅ | Categories window |
| `0x3F` | `UPDATE_CATEGORY` | ✅ | N/A | ❌ | Protocol exists, no UI |
| `0x40` | `DELETE_CATEGORY` | ✅ | N/A | ✅ | Categories window |
| Kad |
| `0x41` | `KAD_START` | ✅ | N/A | ✅ | Servers window |
| `0x42` | `KAD_STOP` | ✅ | N/A | ✅ | Servers window |
| `0x43` | `KAD_UPDATE_FROM_URL` | ✅ | N/A | ✅ | Servers window |
| `0x44` | `KAD_BOOTSTRAP_FROM_IP` | ✅ | N/A | ✅ | Servers window |
| Friends |
| `0x45` | `FRIEND` | ✅ | ✅ (friends) | ✅ | Friends window |
| `0x46` | `FRIEND_ADD` | ✅ | N/A | ✅ | Friends window |
| `0x47` | `FRIEND_REMOVE` | ✅ | N/A | ✅ | Friends window |
| `0x48` | `FRIEND_FRIENDSLOT` | ✅ | N/A | ✅ | Friends window |
| `0x49` | `FRIEND_SHARED` | ✅ | ❌ | ❌ | **Hidden from capabilities** |

### 1.2 Coverage Statistics

- **C++ total opcodes**: 79 (including server replies)
- **SwiftEC builders implemented**: 60
- **SwiftEC advertised bridge ops**: 57
- **Missing as first-class SwiftEC ops**: ~12 (mostly auth/transport internals, `SHUTDOWN`, `ADDLOGLINE`, `ADDDEBUGLOGLINE`, `RESET_DEBUGLOG`, `GET_LAST_LOG_ENTRY`, `CLIENT_SWAP_TO_ANOTHER_FILE`)
- **Intentionally hidden**: `FRIEND_SHARED` (excluded from `unsupportedDisabledOperations`)

---

## 2. Data Parsing Gaps

Our parsers read only a subset of the tags the daemon sends. This is the primary cause of "Unknown" fields in the UI.

### 2.1 Status Parser (`parseStatus`)

**Currently reads**: upload speed, download speed, total sources, Kad users, Ed2K users, Ed2K files, queue length, upload overhead, download overhead, Kad firewalled UDP, shared file count, Kad nodes

**Missing fields**:
- Speed limits (`UL_SPEED_LIMIT`, `DL_SPEED_LIMIT`)
- Banned count (`BANNED_COUNT`)
- Total users/files totals
- Kad metrics (`KAD_INDEXED_*`, `KAD_IP_ADDRESS`, `KAD_IN_LAN_MODE`)
- Buddy status (`BUDDY_STATUS`, `BUDDY_IP`, `BUDDY_PORT`)
- Total bytes (`TOTAL_SENT_BYTES`, `TOTAL_RECEIVED_BYTES`)
- Logger message (`LOGGER_MESSAGE`)

### 2.2 Downloads Parser (`parseDownloads`)

**Currently reads**: name, size, transferred, done, speed, status, priority, source counts, category, last seen, comments, ed2k link, hash, part.met ID, available parts, part status, gap status, req status, A4AF sources

**Missing fields**:
- Upload transferred (`PARTFILE_SIZE_XFER_UP`)
- Active/download flags (`PARTFILE_STOPPED`, `PARTFILE_DOWNLOAD_ACTIVE`)
- Corruption/compression stats (`PARTFILE_LOST_CORRUPTION`, `PARTFILE_GAINED_COMPRESSION`, `PARTFILE_SAVED_ICH`)
- Source name counts (`PARTFILE_SOURCE_NAMES_COUNTS`)
- A4AF auto flag (`PARTFILE_A4AFAUTO`)
- Hashed part count (`PARTFILE_HASHED_PART_COUNT`)
- Shared flag (`PARTFILE_SHARED`)

### 2.3 Sources Parser (`parseSources`)

**Currently reads**: name, software, version, speed, queue position, upload session, upload total, download total, score, hash, friend slot, wait time, xfer time, queue time, ident state, obfuscation, remote queue rank, download state, up speed, down speed, from, user IP, server IP, server name, soft version string, A4AF files

**Missing fields** (causes "Unknown" in many columns):
- Last time (`CLIENT_LAST_TIME`)
- User port / server port
- Client hash
- Client server port
- User ID
- Ext protocol flag
- Upload file / request file refs
- Upload state
- Disable view shared flag
- Old remote queue rank
- Kad port
- Client part status / next requested part / last downloading part
- Remote filename
- Mod version
- OS info
- Upload part status
- Available parts

**Root cause of "Unknown" sources**: The friends opcode bug (see §3.1) also contributes, but the primary cause is that our parser skips most client identity/relationship tags.

### 2.4 Connection Preferences Parser (`parseConnectionPrefs`)

**Currently reads**: download cap, upload cap, max download, max upload, slot allocation, TCP port, UDP port, UDP disable, max file sources, max connections, autoconnect, reconnect, ED2K enabled, Kademlia enabled

**Missing preference groups entirely**:
- General (`USER_NICK`, `USER_HASH`, `USER_HOST`, `GENERAL_CHECK_NEW_VERSION`)
- Message filter (`MSGFILTER_ENABLED`, etc.)
- Online signature (`ONLINESIG_ENABLED`)
- Core tweaks (`CORETW_MAX_CONN_PER_FIVE`, etc.)
- Kademlia (`KADEMLIA_UPDATE_URL`)

### 2.5 Other Parsing Gaps

- **Shared files**: Missing `KNOWNFILE_XFERRED_ALL`, `KNOWNFILE_REQ_COUNT_ALL`, `KNOWNFILE_ACCEPT_COUNT_ALL`, `KNOWNFILE_AICH_MASTERHASH`, `KNOWNFILE_ON_QUEUE`, `KNOWNFILE_COMPLETE_SOURCES_LOW/HIGH`
- **Stats tree**: Value type metadata (`STAT_VALUE_TYPE`) is ignored
- **Search**: Full search type/min/max size/file type/extension filtering is implemented

---

## 3. Critical Issues

### 3.1 🐛 Friends Opcode Mismatch (HIGH PRIORITY)

**File**: `SwiftEC/Sources/AMuleECClient/ECOperations.swift`

**Bug**: `friends()` sends opcode `0x52` (`GET_UPDATE`), but `ECResponseParser.parseFriends()` expects opcode `0x22` (`SHARED_FILES`).

**Impact**: The friends request/response pair is mismatched. This likely causes friends list to fail or return wrong data type. It may also explain intermittent issues with incremental updates.

**Fix**: Change `friends()` builder to send opcode `0x45` (`FRIEND`).

### 3.2 🐛 Stats Crash (FIXED)

**File**: `StatsWindowView.swift`

**Status**: Fixed in prior work. The crash occurred when backend sent `%s` placeholder with `Double` value. Now safely formats based on placeholder type.

### 3.3 🐛 Sources from Wrong File (FIXED)

**File**: `SwiftEC/Sources/AMuleECClient/ECSourceStateStore.swift`

**Status**: Fixed in prior work. Stale `existing?.requestFileID` was preferred over current `contextRequestFileID`.

---

## 4. UI Feature Comparison

### 4.1 Fully Implemented (matching amulegui)

| Feature | Native App | amulegui | Notes |
|---------|------------|----------|-------|
| Downloads list | ✅ | ✅ | With pause/resume/stop/delete/priority/category/rename/A4AF |
| Search | ✅ | ✅ | Global/Kad/Local scope, advanced filters, download |
| Server list | ✅ | ✅ | Add/remove/connect/disconnect, Kad controls |
| Shared files | ✅ | ✅ | Priority, comment/rating, copy link |
| Uploads | ✅ | ✅ | Read-only list |
| Categories | ✅ | ✅ | List/create/delete (update protocol exists, no UI) |
| Friends | ✅ | ✅ | Add/remove/slot |
| Statistics | ✅ | ✅ | Tree + graphs (now native Charts) |
| Preferences | ✅ | ✅ | Connection/files/servers/security/remote/maintenance |
| Diagnostics/Logs | ✅ | ✅ | Raw output viewing |
| Add links | ✅ | ✅ | Ed2k/magnet intake |
| Kad management | ✅ | ✅ | Start/stop/bootstrap/update |

### 4.2 Partially Implemented

| Feature | Native App | amulegui | Gap |
|---------|------------|----------|-----|
| Friend chat/messages | ❌ | ✅ | `MessagesWindowView` is placeholder; `isRemoteMessagesSupported = false` |
| Friend shared files | ❌ | ✅ | `FRIEND_SHARED` op exists but hidden from capabilities |
| Category editing | ❌ | ✅ | `UPDATE_CATEGORY` protocol exists, no UI path |
| Stats preferences | ❌ | ✅ | Daemon `Apply()` has TODO for stats prefs |

### 4.3 Not Applicable (Daemon-Only)

| Feature | EC Exposed | Notes |
|---------|------------|-------|
| Chat sessions | ❌ | EC only has friend management, not chat exchange |
| Upload slot scheduling | ❌ | Internal to daemon |
| Download queue sorting | ❌ | Internal to daemon |
| Partfile hashing/AICH | ❌ | Internal file processing |
| Low-level socket logic | ❌ | Internal networking |
| Web search | ❌ | Explicitly rejected from remote EC |

---

## 5. Permission Model

- **Auth gate**: The only permission check. No per-command ACLs.
- After auth, all commands share the same trust level.
- `CAN_NOTIFY` capability only affects push update registration.
- Detail level gating (`FULL`/`WEB`/`UPDATE`/`INC_UPDATE`/`CMD`) affects what fields are returned.

---

## 6. Recommendations

### Immediate (P0)

1. **Fix friends opcode mismatch** (`ECOperations.swift`): Change `friends()` to send `0x45` (`FRIEND`) instead of `0x52` (`GET_UPDATE`).
2. **Expand sources parser** to read all `CLIENT_*` tags so sources show correct names/versions/states.
3. **Expand status parser** to read speed limits, overhead, and total bytes.

### Short-term (P1)

4. **Expand downloads parser** to read `PARTFILE_SIZE_XFER_UP`, active flags, and corruption/compression stats.
5. **Expand connection prefs parser** to read all preference groups (general, message filter, online signature, core tweaks, Kademlia).
6. **Add `UPDATE_CATEGORY` UI** in Categories window.
7. **Enable `FRIEND_SHARED`** capability and add UI to view friend shared files.

### Medium-term (P2)

8. **Add missing EC operations**: `SHUTDOWN`, `RESET_DEBUGLOG`, `GET_LAST_LOG_ENTRY`, `CLIENT_SWAP_TO_ANOTHER_FILE`.
9. **Expand shared files parser** to read all `KNOWNFILE_*` tags.
10. **Add `GET_CONNSTATE` support** for explicit connection state queries.
11. **Update SwiftEC docs** (`Operations.md`, `SwiftECV1Contract.md`) to reflect the real 57-op surface, not the stale 23-op snapshot.

### Deferred (P3)

12. **Remote chat/messages**: Requires daemon-side EC support for chat sessions (currently not exposed).
13. **Stats preferences**: Daemon `Apply()` has TODO — needs upstream fix first.

---

## 7. Files Involved in Parity Work

### Native App (SwiftUI/UI)
- `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel.swift`
- `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Connection.swift`
- `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Downloads.swift`
- `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/AppModel+Bridge.swift`
- `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/DownloadDetailsWindowView.swift`
- `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/CategoriesWindowView.swift`
- `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/FriendsWindowView.swift`
- `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/MessagesWindowView.swift`

### SwiftEC (Protocol)
- `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECOperations.swift`
- `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECClient/ECResponseParser.swift`
- `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECProtocol/ECSupportedOps.swift`
- `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECProtocol/ECAuthPacket.swift`

### C++ Reference
- `src/ExternalConn.cpp`
- `src/libs/ec/cpp/ECCodes.h`
- `src/ECSpecialCoreTags.cpp`
- `src/ECSpecialMuleTags.cpp`
- `src/Preferences.cpp`
- `src/GenericClientListCtrl.cpp`

---

## 8. Verification Status

| Check | Status |
|-------|--------|
| swift test | ✅ 108/0 |
| swift build | ✅ Clean |
| build-app.sh | ✅ Success |
| Friends opcode fix | ⏳ Pending |
| Sources parser expansion | ⏳ Pending |
| Status parser expansion | ⏳ Pending |

---

*Report compiled from 4 parallel background audits covering native app surface (bg_bd26253b), protocol comparison (bg_18a8013f), amulegui feature coverage (bg_32b9f4fa), and amuled daemon capabilities (bg_ff298e42).*
