# aMuleGUI Feature Parity Matrix

Baseline: upstream `amulegui` / `CLIENT_GUI`.

| Area | Upstream source | Upstream capability | SwiftEC op | macOS UI surface | Status |
| --- | --- | --- | --- | --- | --- |
| Downloads | `src/DownloadListCtrl.cpp` | Pause/resume/cancel/stop | pause/resume/cancel/download-stop | Downloads context menu | matched with native UI |
| Downloads | `src/DownloadListCtrl.cpp` | A4AF swap to this/auto/others | download-a4af-this/download-a4af-auto/download-a4af-others | Details sources menu | matched with native UI |
| Downloads | `src/DownloadListCtrl.cpp` | Assign category | download-set-category | Downloads context menu | matched with native UI |
| Search | `src/SearchDlg.cpp` | Extended fields and filters | search with options | Search window | matched with native UI |
| Shared Files | `src/SharedFilesCtrl.cpp` | Upload priority/comment/rating/link variants | shared-file-priority/shared-file-comment-rating | Shared Files window | matched with native UI |
| Servers | `src/amule-remote-gui.cpp` | Static server and priority | server-set-static/server-set-priority | eD2k window | matched with native UI |
| Logs | `src/amule-remote-gui.cpp` | core/server log read and reset | log/debug-log/server-info/reset-log/clear-server-info | Diagnostics/Server Logs | matched with native UI |
| Friends | `src/FriendListCtrl.cpp`, `src/amule-remote-gui.cpp` | supported list/add/remove/details/friend slot actions; daemon-backed manual QA not run | friends/friend-add/friend-remove/friend-slot | Friends window | deferred with reason |
| Friends | `src/FriendListCtrl.cpp`, `src/ExternalConn.cpp` | shared-list request returns daemon not implemented; chat message UI has no verified CLIENT_GUI EC send operation | friend-shared disabled/unadvertised; no friend-message EC op verified | message/shared-list actions not advertised | unsupported by daemon EC |
| Preferences | `src/amule-remote-gui.h` | remote preference load/apply source/UI present; daemon-backed mutation/corruption QA not run | prefs-* | Preferences window; deferred pending daemon-backed apply/reload QA | deferred with reason |

Task 2 RED evidence: the packet-builder tests were run before the builders existed and failed to compile on missing `ECOperations` builder members and missing server tag constants. This was observed during the implementation turn and was not isolated into a separate commit.

Task 9 upstream verification:
- `src/libs/ec/cpp/ECCodes.h` defines `EC_OP_FRIEND = 0x57`, `EC_TAG_CLIENT = 0x0600`, `EC_TAG_FRIEND = 0x0800`, `EC_TAG_FRIEND_NAME = 0x0801`, `EC_TAG_FRIEND_HASH = 0x0802`, `EC_TAG_FRIEND_IP = 0x0803`, `EC_TAG_FRIEND_PORT = 0x0804`, `EC_TAG_FRIEND_ADD = 0x0806`, `EC_TAG_FRIEND_REMOVE = 0x0807`, `EC_TAG_FRIEND_FRIENDSLOT = 0x0808`, and `EC_TAG_FRIEND_SHARED = 0x0809`.
- `CFriendListRem::AddFriend(const CClientRef&)` sends `EC_OP_FRIEND` with `EC_TAG_FRIEND_ADD` containing `EC_TAG_CLIENT`.
- `CFriendListRem::AddFriend(const CMD4Hash&, uint32, uint32, const wxString&)` sends `EC_OP_FRIEND` with `EC_TAG_FRIEND_ADD` containing `EC_TAG_FRIEND_HASH`, `EC_TAG_FRIEND_IP`, `EC_TAG_FRIEND_PORT`, and `EC_TAG_FRIEND_NAME`.
- `CFriendListRem::RemoveFriend`, `SetFriendSlot`, and `RequestSharedFileList(CFriend*)` send `EC_OP_FRIEND` with `EC_TAG_FRIEND_REMOVE`, `EC_TAG_FRIEND_FRIENDSLOT`, or `EC_TAG_FRIEND_SHARED`, each containing `EC_TAG_FRIEND`.
- `CFriendListRem::RequestSharedFileList(CClientRef&)` sends `EC_OP_FRIEND` with `EC_TAG_FRIEND_SHARED` containing `EC_TAG_CLIENT`.
- `src/ExternalConn.cpp` handles `EC_TAG_FRIEND_SHARED` by returning `EC_OP_FAILED` with `Request shared files list not implemented yet.`; native UI must not advertise or enable this action until daemon result transfer is implemented.
- `src/ChatWnd.cpp` and `src/ChatSelector.cpp` expose chat UI paths, but `CChatSelector::SendMessage` has an `#ifndef CLIENT_GUI` block and a source comment `EC needed here`; `ECCodes.h` has no chat/message EC opcode. Remote chat send/receive is therefore unsupported/deferred for this branch.
