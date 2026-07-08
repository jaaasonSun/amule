/// Canonical V1 operation names for the aMule External Connections protocol.
///
/// This is the SwiftEC-owned operation surface used by the native Apple apps.
public struct ECSupportedOps {
    /// Reports supported protocol capabilities.
    public static let capabilities = "capabilities"
    /// Returns the current remote status.
    public static let status = "status"
    public static let shutdown = "shutdown"
    public static let connectionState = "connection-state"
    /// Lists active and queued downloads.
    public static let downloads = "downloads"
    /// Returns sources for a download.
    public static let sources = "sources"
    /// Performs a search request.
    public static let search = "search"
    /// Stops an active search.
    public static let searchStop = "search-stop"
    /// Requests a specific download.
    public static let download = "download"
    /// Adds a download link.
    public static let addLink = "add-link"
    /// Renames an item.
    public static let rename = "rename"
    /// Connects to the daemon.
    public static let connect = "connect"
    /// Disconnects from the daemon.
    public static let disconnect = "disconnect"
    /// Pauses one or more transfers.
    public static let pause = "pause"
    /// Resumes one or more transfers.
    public static let resume = "resume"
    public static let downloadStop = "download-stop"
    public static let downloadA4AFThis = "download-a4af-this"
    public static let downloadA4AFAuto = "download-a4af-auto"
    public static let downloadA4AFOthers = "download-a4af-others"
    /// Cancels one or more transfers.
    public static let cancel = "cancel"
    /// Updates transfer priority.
    public static let priority = "priority"
    /// Clears completed items.
    public static let clearCompleted = "clear-completed"
    /// Lists available servers.
    public static let servers = "servers"
    /// Connects to a server.
    public static let serverConnect = "server-connect"
    /// Disconnects from the current server.
    public static let serverDisconnect = "server-disconnect"
    /// Adds a server.
    public static let serverAdd = "server-add"
    /// Removes a server.
    public static let serverRemove = "server-remove"
    /// Updates servers from a URL.
    public static let serverUpdateFromURL = "server-update-from-url"
    /// Updates KAD from a URL.
    public static let kadUpdateFromURL = "kad-update-from-url"
    /// Starts KAD.
    public static let kadStart = "kad-start"
    /// Stops KAD.
    public static let kadStop = "kad-stop"
    /// Bootstraps KAD from a host and port.
    public static let kadBootstrap = "kad-bootstrap"
    /// Gets connection preferences.
    public static let prefsConnectionGet = "prefs-connection-get"
    /// Sets connection preferences.
    public static let prefsConnectionSet = "prefs-connection-set"
    public static let uploads = "uploads"
    public static let sharedFiles = "shared-files"
    public static let sharedFilesReload = "shared-files-reload"
    public static let log = "log"
    public static let lastLogEntry = "last-log-entry"
    public static let debugLog = "debug-log"
    public static let resetDebugLog = "reset-debug-log"
    public static let categories = "categories"
    public static let categoryCreate = "category-create"
    public static let categoryUpdate = "category-update"
    public static let categoryDelete = "category-delete"
    public static let downloadSetCategory = "download-set-category"
    public static let sharedFilePriority = "shared-file-priority"
    public static let sharedFileCommentRating = "shared-file-comment-rating"
    public static let serverSetStatic = "server-set-static"
    public static let serverSetPriority = "server-set-priority"
    public static let serverInfo = "server-info"
    public static let clearServerInfo = "clear-server-info"
    public static let resetLog = "reset-log"
    public static let ipfilterReload = "ipfilter-reload"
    public static let ipfilterUpdate = "ipfilter-update"
    public static let friends = "friends"
    public static let friendAdd = "friend-add"
    public static let friendRemove = "friend-remove"
    public static let friendSlot = "friend-slot"
    public static let friendShared = "friend-shared"
    public static let statsTree = "stats-tree"
    public static let statsGraphs = "stats-graphs"
    public static let clientSwapToAnotherFile = "client-swap-to-another-file"

    /// Known operation names that remain intentionally absent from capability
    /// advertisement until they have a complete builder, adapter endpoint, and
    /// app bridge contract.
    public static let unsupportedDisabledOperations: [String] = [
        friendShared,
        clientSwapToAnotherFile,
    ]

    /// All supported V1 operations in canonical order.
    public static let allOperations: [String] = [
        capabilities,
        status,
        shutdown,
        connectionState,
        downloads,
        sources,
        search,
        searchStop,
        download,
        addLink,
        rename,
        connect,
        disconnect,
        pause,
        resume,
        downloadStop,
        downloadA4AFThis,
        downloadA4AFAuto,
        downloadA4AFOthers,
        cancel,
        priority,
        downloadSetCategory,
        clearCompleted,
        servers,
        serverConnect,
        serverDisconnect,
        serverAdd,
        serverRemove,
        serverUpdateFromURL,
        serverSetStatic,
        serverSetPriority,
        serverInfo,
        clearServerInfo,
        kadStart,
        kadStop,
        kadBootstrap,
        kadUpdateFromURL,
        prefsConnectionGet,
        prefsConnectionSet,
        uploads,
        sharedFiles,
        sharedFilesReload,
        sharedFilePriority,
        sharedFileCommentRating,
        log,
        lastLogEntry,
        debugLog,
        resetDebugLog,
        resetLog,
        categories,
        categoryCreate,
        categoryUpdate,
        categoryDelete,
        ipfilterReload,
        ipfilterUpdate,
        friends,
        friendAdd,
        friendRemove,
        friendSlot,
        statsTree,
        statsGraphs,
    ]
}
