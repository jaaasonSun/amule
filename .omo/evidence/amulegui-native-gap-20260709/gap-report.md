# amulegui vs native macOS aMule client gap report

Date: 2026-07-09

Scope: upstream wxWidgets `amulegui`/remote GUI behavior under `src/`, native macOS SwiftUI app under `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote`, and SwiftEC backend under `native-macos/AMuleNativeRemote/SwiftEC/Sources`.

## Executive summary

The native client is no longer a small remote: it now covers the major daemon surfaces: downloads, download sources, search, servers/Kad, shared files, uploads, stats, preferences, categories, friends, logs/diagnostics, and link intake. The biggest remaining parity gaps are not broad navigation gaps; they are depth gaps:

1. **Transfer/source parity is still the highest-risk backend area.** Native source loading depends on queue lookup plus `EC_OP_GET_UPDATE` incremental merge and request-file filtering, while amulegui presents source lists directly from the current `CPartFile`/client-list model. This is conceptually aligned, but fragile around missing `EC_TAG_CLIENT_REQUEST_FILE`, sparse deltas, and client deletion semantics.
2. **Search is single-session in native vs multi-tab/multi-result-set in amulegui.** Native has a modern toolbar search and inspector, but lacks amulegui's per-search tabs, close-tab behavior, and persistent simultaneous result sets.
3. **Shared files, uploads, friends, and messages are shallow.** Native has base list/actions, but amulegui has richer client-mode views, many link variants, peer/source lists, friend shared-file requests, chat, and client-detail actions.
4. **Preferences are much improved but not complete.** Native covers core remote preference groups, but misses several amulegui panes or only partially maps them.
5. **Backend op coverage is broad, with two explicit disabled capabilities.** `friend-shared` and `client-swap-to-another-file` are implemented as names/builders but intentionally absent from advertised capabilities.

## Upstream amulegui baseline

### EC operation surface

Upstream EC defines the canonical remote operation set: auth, status, shutdown, add-link, stats, connection state, downloads/uploads/shared files, A4AF, partfile pause/resume/stop/prio/delete/category, rename, search start/stop/results/progress/download, IP filter, servers, logs, preferences, categories, stats graphs/tree, Kad, connect/disconnect, update, clear completed, client swap, shared comment, server static/priority, and friend operations. Evidence: `src/libs/ec/cpp/ECCodes.h:46-124`.

The tags also expose rich download/source/client/preference data: part-file source counts, ed2k link, category, timestamps, progress/gap/request state, source names, A4AF sources; known-file stats/comment/rating; client software/hash/score/friend slot/wait/xfer/upload/download state/speeds/IP/server/queue/file names/A4AF/parts/mod/os; and many preference groups. Evidence: `src/libs/ec/cpp/ECCodes.h:176-226`, `src/libs/ec/cpp/ECCodes.h:241-300`, `src/libs/ec/cpp/ECCodes.h:320-360`, `src/libs/ec/cpp/ECCodes.h:744-850`.

### Downloads and source list

amulegui download list columns include part, file name, size, transferred, completed, speed, progress, sources, priority, status, time remaining, last seen complete, and last reception. Evidence: `src/DownloadListCtrl.cpp:81-95`.

Download actions include pause/resume/stop/cancel, priority low/normal/high/auto, A4AF swap this/auto/others, assign category, clear completed, copy magnet/eD2k/feedback, details, preview, comments, and rename via F2. Evidence: `src/DownloadListCtrl.cpp:98-135`, `src/DownloadListCtrl.cpp:500-543`, `src/DownloadListCtrl.cpp:642-821`.

The downloads page also has category tabs and a bottom client/source list. Selection updates call `clientlistctrl->ShowSources(filesVector)`. Evidence: `src/TransferWnd.cpp:80-116`, `src/TransferWnd.cpp:141-232`, `src/DownloadListCtrl.cpp:612-630`.

The bottom sources table columns are user name, downloaded, speed, uploaded, available parts, version, download status, origin, local file name, remote file name, and shares-file-list. Evidence: `src/SourceListCtrl.cpp:27-39`.

### File details

amulegui's file detail dialog shows name, `.part.met`, hash, size, status, part counts, transferred, corruption/compression/ICH, completion, rate, source counts, available parts, active time, last seen complete, comments, and source filenames. It also supports source filename takeover, filename strip cleanup, comments, previous/next, and applying rename. Evidence: `src/FileDetailDialog.cpp:90-141`, `src/FileDetailDialog.cpp:145-223`, `src/FileDetailDialog.cpp:274-307`, `src/FileDetailDialog.cpp:363-467`.

### Search

amulegui supports local/global/Kad scope, advanced criteria, result filters, multiple search result tabs, tab close/stop behavior, and category-aware downloads. Evidence: `src/SearchDlg.cpp:49-78`, `src/SearchDlg.cpp:105-154`, `src/SearchDlg.cpp:205-246`, `src/SearchDlg.cpp:271-339`, `src/SearchDlg.cpp:357-420`, `src/SearchDlg.cpp:436-596`.

Search result columns include file name, size, sources, type, file ID, status, and directories, with grouped/child result handling and status coloring. Evidence: `src/SearchListCtrl.cpp:59-93`, `src/SearchListCtrl.cpp:137-251`.

### Servers, Kad, logs

amulegui supports server add/update/remove/connect/disconnect, server.met URL update, log resets, eD2K status, and Kad status/controls/bootstrap/nodes.dat update. Evidence: `src/ServerWnd.cpp:89-194`, `src/KadDlg.cpp:157-219`, `src/libs/ec/cpp/RemoteConnect.cpp:291-319`.

### Shared files, uploads, friends, chat, stats, prefs

Shared files expose rich columns and context actions: priority including PowerShare/release-ish levels, comments/rating, rename, collection, magnet/eD2k/source/hostname/crypt/AICH links, and feedback. Evidence: `src/SharedFilesCtrl.cpp:75-87`, `src/SharedFilesCtrl.cpp:130-193`, `src/SharedFilesCtrl.cpp:270-359`.

Shared Files window has request/accepted/transferred summary bars and can toggle peer/client list modes including downloading/uploading clients. Evidence: `src/SharedFilesWnd.cpp:40-63`, `src/SharedFilesWnd.cpp:106-218`, `src/SharedFilesWnd.cpp:269-350`.

Friend list supports add/remove/details/send message/view files/friend slot. Evidence: `src/FriendListCtrl.cpp:42-54`, `src/FriendListCtrl.cpp:116-230`. Chat supports sessions, tab context menu, add friend, send message, and incoming-message processing. Evidence: `src/ChatWnd.cpp:43-55`, `src/ChatWnd.cpp:72-119`, `src/ChatWnd.cpp:146-207`.

Stats builds download/upload/connection graph scopes plus a stat tree and updates graph datasets periodically. Evidence: `src/StatisticsDlg.cpp:62-107`, `src/StatisticsDlg.cpp:158-216`.

Preferences include General, Connection, Directories, Servers, Files, Security, Interface, Statistics, Proxy, Filters, Remote Controls, Online Signature, Advanced, Events, and Debugging. Evidence: `src/PrefsUnifiedDlg.cpp:56-135`, `src/PrefsUnifiedDlg.cpp:174-189`.

## Native implementation baseline

### Feature surface

Native navigation covers Downloads, Search, Servers, Shared Files, Uploads, optional Categories, optional Friends, and Statistics. Evidence: `native-macos/AMuleNativeRemote/Sources/AMuleNativeRemote/ContentView.swift:142-218`. Preferences can hide Uploads/Categories/Friends. Evidence: `ContentView.swift:12-15`, `PreferencesWindowView.swift:348-359`.

Downloads have a native `Table` with name/progress/speed/source columns and toolbar search filtering. Context actions cover details, suggested rename, copy eD2k, pause/resume/stop/remove, priority, and category assignment. Evidence: `DownloadsPanel.swift:55-167`, `DownloadsPanel.swift:169-215`.

Details window now includes a source table with many important amulegui columns: client, endpoint, software/version, state, speed, available parts, queue, origin, server, remote filename, totals, and shares-file-list. Evidence: `DownloadDetailsWindowView.swift:185-310`, `DownloadDetailsWindowView.swift:372-492`.

Search is a native toolbar search field plus Download/Stop/Advanced buttons and an inspector separating criteria from result filters. Evidence: `SearchWindowView.swift:64-132`, `SearchWindowView.swift:245-369`.

Servers/Kad coverage is strong: add/refresh/remove/import server.met, Kad start/stop/bootstrap/nodes.dat, connect/disconnect, daemon shutdown, static flag, priority. Evidence: `ServersWindowView.swift:60-174`, `ServersWindowView.swift:361-452`, `AppModel+Servers.swift:6-249`.

Shared Files, Uploads, Friends, and Messages are the thinnest native pages. Shared Files is a simple list with priority/comment/rating/copy eD2k. Uploads lists active clients. Friends supports add/remove/friend-slot. Messages is explicitly unavailable. Evidence: `SharedFilesWindowView.swift:18-177`, `UploadsWindowView.swift:17-72`, `FriendsWindowView.swift:17-143`, `MessagesWindowView.swift:3-15`.

Stats has stats tree and graphs via Swift Charts. Evidence: `StatsWindowView.swift:81-136`, `StatsWindowView.swift:138-270`. Preferences use macOS preference-style toolbar tabs and expose Connection, Files, Servers, Security, Remote, Interface, Maintenance. Evidence: `PreferencesWindowView.swift:7-81`, `PreferencesWindowView.swift:490-593`.

### Backend surface

SwiftEC advertises a broad operation set matching most upstream EC operations: downloads/sources/search/download/add-link/rename, transfer actions, A4AF, servers, Kad, prefs, uploads/shared/logs/categories/IP filter/friends/stats. Evidence: `native-macos/AMuleNativeRemote/SwiftEC/Sources/AMuleECProtocol/ECSupportedOps.swift:4-168`.

Two known ops are explicitly disabled from capability advertisement: `friend-shared` and `client-swap-to-another-file`. Evidence: `ECSupportedOps.swift:97-103`.

Downloads use an initial full download queue baseline followed by `EC_OP_GET_UPDATE` incremental updates and a state store. Evidence: `SwiftECBridgeAdapter.swift:61-97`, `ECOperations.swift:333-341`, `ECDownloadStateStore.swift:40-128`.

Sources use full queue lookup for the selected file ECID, then `EC_OP_GET_UPDATE`, then source state merge and `requestFileID` filtering. Evidence: `SwiftECBridgeAdapter.swift:246-266`, `ECOperations.swift:383-390`, `ECSourceStateStore.swift:13-38`.

Source parser and state store parse most upstream client tags, including client name, endpoint, server, software/version/mod, totals, queue rank, origin, remote filename, file-list-share flag, hash, score, timing, part status, A4AF files, and OS info. Evidence: `ECResponseParser.swift:411-530`, `ECSourceStateStore.swift:40-118`.

Preferences read all remote preference groups, but write only selected groups. Evidence: `ECOperations.swift:300-320`, `ECOperations.swift:650-776`, `AppModel+Preferences.swift:200-320`.

## Prioritized gaps

### P0: Download source chain correctness and parity

**Gap:** native source table has strong column parity, but its data path is still the most fragile. It depends on mapping selected download hash to queue ECID, then applying an incremental update to a global source store and filtering by `requestFileID`. amulegui displays sources from the selected part-file/client model and refreshes the bottom list on selection. Evidence: native `SwiftECBridgeAdapter.swift:246-266`, `ECSourceStateStore.swift:13-38`; upstream `DownloadListCtrl.cpp:612-630`, `SourceListCtrl.cpp:27-39`.

**Backend risk:** if daemon deltas omit `EC_TAG_CLIENT_REQUEST_FILE`, include mixed clients, or send removal/empty child tags that differ from fixture assumptions, native can show empty sources or stale/cross-file sources. The source store has safeguards, but they are heuristic: it only uses request context when explicit request-file tags are all matching. Evidence: `ECSourceStateStore.swift:17-27`, `ECSourceStateStore.swift:47-55`, `ECSourceStateStore.swift:129-140`.

**Recommended work:** add live-capture or recorded-real-daemon fixtures for the exact amulegui bottom source table packets; verify full queue response, first update, subsequent update, source removal, and A4AF moves. Then adjust state store semantics to match actual daemon packets. Confidence: high.

### P0: Shared files repeated/identity robustness

**Gap:** native shared files page already experienced duplicate/identity bugs in prior work. Current page still uses a simple list with `offset|hash|path|name` identity and minimal columns. Evidence: `SharedFilesWindowView.swift:70-77`, `SharedFilesWindowView.swift:184-195`.

**Upstream parity:** amulegui shared files table uses many stable file properties and exposes size/type/priority/hash/request stats/share ratio/parts/complete sources/path. Evidence: `SharedFilesCtrl.cpp:75-87`.

**Recommended work:** switch native shared files to a native `Table` keyed by hash plus disambiguating path only when needed; expose request/accepted/transferred/share ratio/complete sources/path columns; keep duplicate detection tests. Confidence: high.

### P1: Search multi-session parity

**Gap:** native search keeps one `searchResults` array and prevents starting a second search while one is active. Evidence: `AppModel.swift:35-41`, `AppModel+Search.swift:7-64`. amulegui creates a tab per search and has tab close/stop behavior, filters per all pages, and tab result counts. Evidence: `SearchDlg.cpp:229-246`, `SearchDlg.cpp:357-420`, `SearchDlg.cpp:543-565`.

**Backend status:** SwiftEC can start/poll/stop search and parse grouped result IDs. Evidence: `SwiftECBridgeAdapter.swift:108-146`, `SearchWindowView.swift:144-243`. The gap is mostly app model/UI state, not opcode availability.

**Recommended work:** introduce `SearchSession` model with query/scope/options/results/progress/createdAt/state, render sessions in a native segmented/tab or sidebar affordance, and preserve current toolbar search/Advanced inspector. Confidence: high.

### P1: Friend shared files, client swap, and client actions

**Gap:** upstream friend/client workflows include details, add/remove, messages, view files, friend slot, and source/client context actions. Evidence: `FriendListCtrl.cpp:42-54`, `FriendListCtrl.cpp:116-230`, `ChatWnd.cpp:43-55`, `ChatWnd.cpp:146-207`.

Native friends only lists/adds/removes/toggles friend slot. `friend-shared` is both present in code and disabled in advertised capabilities; messages are always unsupported. Evidence: `FriendsWindowView.swift:17-143`, `AppModel+FriendsMessages.swift:103-115`, `ECSupportedOps.swift:97-103`.

**Backend gap:** `client-swap-to-another-file` builder exists but is disabled, so per-source "swap this client to another file" parity is incomplete. Evidence: `ECOperations.swift:452-458`, `ECSupportedOps.swift:97-103`.

**Recommended work:** implement capability-complete `friend-shared` result handling through search/shared-files response path; add client detail sheet from source/friend/upload rows; only then enable `client-swap-to-another-file`. Chat likely needs separate feasibility research because native explicitly marks remote messages unsupported. Confidence: high for friend-shared/client-swap, medium for chat.

### P1: Shared files and uploads depth

**Gap:** native Shared Files is a list with priority/comment/rating/copy eD2k only. Evidence: `SharedFilesWindowView.swift:18-177`. amulegui has stats bars, toggleable client/peer list, many link variants, collection, rename, feedback, and multiple priority modes. Evidence: `SharedFilesWnd.cpp:106-218`, `SharedFilesCtrl.cpp:130-193`, `SharedFilesCtrl.cpp:311-345`.

Native Uploads only shows client name, speed, endpoint. Evidence: `UploadsWindowView.swift:45-72`. Upstream source/client list infrastructure exposes much richer client columns/actions. Evidence: `SourceListCtrl.cpp:27-39`, `FriendListCtrl.cpp:116-230`.

**Recommended work:** promote Shared Files/Uploads to native tables with column customization and context actions; reuse `DownloadSourceItem`/client detail models where possible. Confidence: high.

### P2: File details advanced metadata and actions

**Gap:** native details shows many core fields, but not all amulegui detail/actions: `.part.met` is shown, but corruption/compression/ICH comments are not prominently grouped; no previous/next file navigation; no amulegui-style Strip button; no comment dialog parity; no source filename takeover as a first-class action, though alternative names can be used for rename. Evidence: native `DownloadDetailsWindowView.swift:185-310`; upstream `FileDetailDialog.cpp:90-141`, `FileDetailDialog.cpp:145-223`, `FileDetailDialog.cpp:274-307`, `FileDetailDialog.cpp:363-467`.

**Recommended work:** add a native details layout with sections/tabs: Overview, Sources, Names, Integrity, Comments. Add previous/next only if the details window remains selection-coupled. Confidence: medium-high.

### P2: Preferences breadth

**Gap:** native preferences expose seven panes. Evidence: `PreferencesWindowView.swift:7-81`, `PreferencesWindowView.swift:137-434`. amulegui exposes many more panes: General, Proxy, Filters, Online Signature, Advanced, Events, Debugging, plus richer Interface/Statistics options. Evidence: `PrefsUnifiedDlg.cpp:174-189`.

**Backend split:** SwiftEC declares masks for General, MessageFilter, OnlineSignature, CoreTweaks, Kademlia, Statistics, etc., but write builders are not complete for all groups. Evidence: `ECOperations.swift:300-320`, `ECOperations.swift:679-776`.

**Recommended work:** classify prefs into remote daemon prefs vs local native app prefs vs amulegui-only/wx-only prefs. Add Proxy/Filters/Advanced/Kademlia/Statistics only after confirming amuled accepts and returns the relevant tags. Confidence: high.

### P2: Statistics UX parity

**Gap:** native stats has tree and graph charts, but lacks amulegui's explicit download/upload/connection graph scopes/ranges and preference-driven graph tuning. Evidence: native `StatsWindowView.swift:81-270`; upstream `StatisticsDlg.cpp:62-107`, `StatisticsDlg.cpp:158-216`.

**Recommended work:** keep native simplified stats, but add graph range/scale controls only if real users need them; otherwise this can stay intentionally non-parity. Confidence: medium.

### P3: Link/copy/feedback parity

**Gap:** native supports copy eD2k in downloads/shared files and add-link intake, but lacks upstream's link variants: magnet/source/hostname/crypt/AICH and feedback copying. Evidence: native `DownloadsPanel.swift:180-182`, `SharedFilesWindowView.swift:119-121`; upstream `DownloadListCtrl.cpp:519-563`, `SharedFilesCtrl.cpp:311-345`.

**Recommended work:** expose only high-value variants in Share menu; avoid cluttering context menus. Confidence: high.

## Backend implementation gap matrix

| Area | Upstream EC/op behavior | Native SwiftEC status | Gap |
| --- | --- | --- | --- |
| Downloads | `GET_DLOAD_QUEUE`, `GET_UPDATE`, partfile actions, A4AF, categories, rename | Implemented, stateful baseline+incremental | Need more real-daemon update fixtures |
| Sources | Client tags under update; displayed through selected file source list | Implemented through queue lookup + update + `ECSourceStateStore` | Fragile `requestFileID`/delta semantics |
| Search | start/stop/progress/results, multi-tabs in GUI | Implemented backend, single-session UI/model | UI/model gap |
| Servers/Kad | connect/disconnect/add/remove/update/static/priority, Kad start/stop/bootstrap/update | Broadly implemented | Minor UX polish only |
| Shared files | list/reload/priority/comment/rating/link variants/stats/client modes | Basic list/reload/priority/comment/rating/eD2k | UI depth and link/client-mode gaps |
| Uploads | upload queue/client data | Basic list | UI/client detail/action gap |
| Friends | friend list/add/remove/slot/view shared/files/chat | list/add/remove/slot; `friend-shared` disabled | Backend capability + UI flow gap |
| Messages | chat sessions | explicitly unsupported | Feasibility gap |
| Stats | stats graph/tree | implemented | UX/preferences gap |
| Preferences | broad remote and GUI prefs | broad read, partial write/UI | group coverage/classification gap |
| Logs/server info | get/reset log/debug/server info | backend/app model exist; not part of main nav | discoverability/UI gap |

## Suggested implementation order

1. **Lock the download/source chain against real daemon packets.** This directly addresses correctness and user trust; it also underpins future client details, A4AF, and friend/share actions.
2. **Upgrade Shared Files and Uploads to table-based parity.** These are shallow UI surfaces with backend already mostly available.
3. **Add multi-session search state.** Backend is already sufficient; the work is contained in app model/view state.
4. **Complete friend-shared/client detail before chat.** It uses existing friend/source/client models and unlocks several amulegui actions.
5. **Classify and fill preferences gaps.** Avoid blindly porting wx-only preferences; map only daemon-relevant groups first.
6. **Polish statistics and link variants selectively.** These are lower risk and should remain native rather than verbatim wxWidgets parity.

## Confidence and caveats

- High confidence for UI gap findings: they are based on direct source scans of both upstream and native views.
- High confidence for operation availability: `ECSupportedOps` and `ECOperations` directly define advertised and buildable SwiftEC operations.
- Medium confidence for live source-update behavior: local code and tests are clear, but the real daemon's incremental packet shapes need captured evidence before declaring full parity with amulegui.
- This report intentionally did not modify product code or run builds; it is a source-level gap scan.
