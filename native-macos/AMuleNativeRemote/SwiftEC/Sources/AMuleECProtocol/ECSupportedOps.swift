/// Canonical V1 operation names for the aMule External Connections protocol.
///
/// This is the SwiftEC-owned operation surface used by the native Apple apps.
public struct ECSupportedOps {
    /// Reports supported protocol capabilities.
    public static let capabilities = "capabilities"
    /// Returns the current remote status.
    public static let status = "status"
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
    public static let debugLog = "debug-log"
    public static let categories = "categories"
    public static let categoryCreate = "category-create"
    public static let categoryDelete = "category-delete"
    public static let ipfilterReload = "ipfilter-reload"
    public static let ipfilterUpdate = "ipfilter-update"
    public static let friends = "friends"
    public static let friendRemove = "friend-remove"
    public static let friendSlot = "friend-slot"
    public static let statsTree = "stats-tree"
    public static let statsGraphs = "stats-graphs"

    /// Known operation names that remain intentionally absent from capability
    /// advertisement until they have a complete builder, adapter endpoint, and
    /// app bridge contract.
    public static let unsupportedDisabledOperations: [String] = [
        "category-update",
        "download-set-category",
    ]

    /// All supported V1 operations in canonical order.
    public static let allOperations: [String] = [
        capabilities,
        status,
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
        cancel,
        priority,
        clearCompleted,
        servers,
        serverConnect,
        serverDisconnect,
        serverAdd,
        serverRemove,
        serverUpdateFromURL,
        kadStart,
        kadStop,
        kadBootstrap,
        kadUpdateFromURL,
        prefsConnectionGet,
        prefsConnectionSet,
        uploads,
        sharedFiles,
        sharedFilesReload,
        log,
        debugLog,
        categories,
        categoryCreate,
        categoryDelete,
        ipfilterReload,
        ipfilterUpdate,
        friends,
        friendRemove,
        friendSlot,
        statsTree,
        statsGraphs,
    ]
}
