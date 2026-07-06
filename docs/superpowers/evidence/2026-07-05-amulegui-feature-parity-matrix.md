# aMuleGUI Feature Parity Matrix

Baseline: upstream `amulegui` / `CLIENT_GUI`.

| Area | Upstream source | Upstream capability | SwiftEC op | macOS UI surface | Status |
| --- | --- | --- | --- | --- | --- |
| Downloads | `src/DownloadListCtrl.cpp` | Pause/resume/cancel/stop | pause/resume/cancel/download-stop | Downloads context menu | stop missing |
| Downloads | `src/DownloadListCtrl.cpp` | A4AF swap to this/auto/others | download-a4af-this/download-a4af-auto/download-a4af-others | Details sources menu | missing |
| Downloads | `src/DownloadListCtrl.cpp` | Assign category | download-set-category | Downloads context menu | missing |
| Search | `src/SearchDlg.cpp` | Extended fields and filters | search with options | Search window | missing |
| Shared Files | `src/SharedFilesCtrl.cpp` | Upload priority/comment/rating/link variants | shared-file-priority/shared-file-comment-rating | Shared Files window | missing mutations |
| Servers | `src/amule-remote-gui.cpp` | Static server and priority | server-set-static/server-set-priority | eD2k window | missing mutations |
| Logs | `src/amule-remote-gui.cpp` | core/server log read and reset | log/debug-log/server-info/reset-log/clear-server-info | Diagnostics/Server Logs | partial |
| Friends | `src/FriendListCtrl.cpp`, `src/amule-remote-gui.cpp` | add/remove/details/friend slot/shared list; message UI is present but remote chat send is not EC-backed in this branch | friends/friend-add/friend-remove/friend-slot/friend-shared; no friend-message EC op verified | Friends/Messages windows | partial |
| Preferences | `src/amule-remote-gui.h` | remote preference load/apply | prefs-* | Preferences window | partial |

Task 2 RED evidence: the packet-builder tests were run before the builders existed and failed to compile on missing `ECOperations` builder members and missing server tag constants. This was observed during the implementation turn and was not isolated into a separate commit.

Task 9 upstream verification:
- `src/libs/ec/cpp/ECCodes.h` defines `EC_OP_FRIEND = 0x57`, `EC_TAG_CLIENT = 0x0600`, `EC_TAG_FRIEND = 0x0800`, `EC_TAG_FRIEND_NAME = 0x0801`, `EC_TAG_FRIEND_HASH = 0x0802`, `EC_TAG_FRIEND_IP = 0x0803`, `EC_TAG_FRIEND_PORT = 0x0804`, `EC_TAG_FRIEND_ADD = 0x0806`, `EC_TAG_FRIEND_REMOVE = 0x0807`, `EC_TAG_FRIEND_FRIENDSLOT = 0x0808`, and `EC_TAG_FRIEND_SHARED = 0x0809`.
- `CFriendListRem::AddFriend(const CClientRef&)` sends `EC_OP_FRIEND` with `EC_TAG_FRIEND_ADD` containing `EC_TAG_CLIENT`.
- `CFriendListRem::AddFriend(const CMD4Hash&, uint32, uint32, const wxString&)` sends `EC_OP_FRIEND` with `EC_TAG_FRIEND_ADD` containing `EC_TAG_FRIEND_HASH`, `EC_TAG_FRIEND_IP`, `EC_TAG_FRIEND_PORT`, and `EC_TAG_FRIEND_NAME`.
- `CFriendListRem::RemoveFriend`, `SetFriendSlot`, and `RequestSharedFileList(CFriend*)` send `EC_OP_FRIEND` with `EC_TAG_FRIEND_REMOVE`, `EC_TAG_FRIEND_FRIENDSLOT`, or `EC_TAG_FRIEND_SHARED`, each containing `EC_TAG_FRIEND`.
- `CFriendListRem::RequestSharedFileList(CClientRef&)` sends `EC_OP_FRIEND` with `EC_TAG_FRIEND_SHARED` containing `EC_TAG_CLIENT`.
- `src/ChatWnd.cpp` and `src/ChatSelector.cpp` expose chat UI paths, but `CChatSelector::SendMessage` has an `#ifndef CLIENT_GUI` block and a source comment `EC needed here`; `ECCodes.h` has no chat/message EC opcode. Remote chat send/receive is therefore unsupported/deferred for this branch.
