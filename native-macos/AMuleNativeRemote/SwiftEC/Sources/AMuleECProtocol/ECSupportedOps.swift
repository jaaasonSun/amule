/// Canonical V1 operation names for the aMule External Connections protocol.
///
/// Based on `src/AMuleECBridgeCore.cpp::SupportedOps()`.
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
    /// Gets connection preferences.
    public static let prefsConnectionGet = "prefs-connection-get"
    /// Sets connection preferences.
    public static let prefsConnectionSet = "prefs-connection-set"

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
        kadUpdateFromURL,
        prefsConnectionGet,
        prefsConnectionSet,
    ]
}
