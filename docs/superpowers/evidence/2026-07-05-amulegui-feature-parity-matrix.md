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
| Friends | `src/FriendListCtrl.cpp` | add/remove/message/details/friend slot/shared list | friends/friend-add/friend-remove/friend-slot/friend-message | Friends/Messages windows | partial |
| Preferences | `src/amule-remote-gui.h` | remote preference load/apply | prefs-* | Preferences window | partial |
