# SwiftEC Operations Reference

Complete reference for the SwiftEC operation surface. SwiftEC advertises approximately 57 bridge operations across fourteen major categories. The canonical list lives in `Sources/AMuleECProtocol/ECSupportedOps.swift` and should be treated as the source of truth. This document describes the categories and provides detailed examples for the most common operations.

## Operation Categories

| Category | Representative Operations | Description |
|----------|--------------------------|-------------|
| **Info** | capabilities, status, shutdown, connection-state | Bridge, connection, and daemon information |
| **Read** | downloads, sources, servers, uploads, shared-files, categories, friends, stats-tree, stats-graphs | Data retrieval operations |
| **Action** | search, search-stop, download, add-link, pause, resume, stop, cancel, priority, rename, clear-completed, download-set-category | File and transfer actions |
| **Network** | connect, disconnect, server-connect, server-disconnect | Network management |
| **Server Management** | server-add, server-remove, server-update-from-url, server-set-static, server-set-priority, server-info, clear-server-info | Server list and configuration |
| **Kad** | kad-start, kad-stop, kad-bootstrap, kad-update-from-url | Kademlia DHT management |
| **Shared Files** | shared-files-reload, shared-file-priority, shared-file-comment-rating | Shared file management |
| **Preferences** | prefs-connection-get, prefs-connection-set | Preferences access across 12 remote groups |
| **Categories** | category-create, category-update, category-delete | Download category management |
| **Friends** | friend-add, friend-remove, friend-slot | Friend list management |
| **Logs** | log, debug-log, reset-log, last-log-entry, reset-debug-log, server-info, clear-server-info | Log and server info access |
| **IP Filter** | ipfilter-reload, ipfilter-update | IP filter management |
| **Link Intake** | add-link | ED2K and magnet link intake |
| **Admin** | shutdown | Daemon shutdown |

---

## Info Operations

### capabilities

Returns bridge capability information.

**SwiftEC Operation:**
```swift
let capabilities = ECOperations.capabilities()
```

**BridgeProtocol Method:**
```swift
func capabilities(config: AMuleConnectionConfig) async throws -> (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String)
```

**Response Model:** `ECCapabilities`
- `bridgeVersion`: Bridge implementation version
- `clientName`: Client identifier
- `defaultHost`: Default daemon host
- `defaultPort`: Default daemon port
- `ops`: Array of supported operation names

**Example Response:**
```json
{
  "ok": true,
  "schema_version": 1,
  "capabilities": {
    "bridge_version": "SwiftEC",
    "client_name": "SwiftEC",
    "default_host": "127.0.0.1",
    "default_port": 4712,
    "ops": ["capabilities", "status", "downloads", "search", ...]
  }
}
```

---

### status

Returns current connection and transfer status.

**SwiftEC Operation:**
```swift
let packet = try await session.send(ECOperations.status())
let status = try ECResponseParser.parseStatus(packet)
```

**BridgeProtocol Method:**
```swift
func status(config: AMuleConnectionConfig) async throws -> (BridgeStatusPayload, String)
```

**Response Model:** `ECStatus`
- `connected`: Boolean connection state
- `ed2k`: ED2K network status text
- `kad`: Kademlia network status text
- `downloadSpeed`: Current download speed (bytes/s)
- `uploadSpeed`: Current upload speed (bytes/s)
- `queue`: Upload queue length
- `sources`: Total source count

**Example Response:**
```json
{
  "ok": true,
  "status": {
    "connected": true,
    "ed2k": "Connected",
    "kad": "Unknown",
    "download_speed": 1048576,
    "upload_speed": 524288,
    "queue": 10,
    "sources": 150
  }
}
```

---

## Read Operations

### downloads

Returns list of active downloads.

**SwiftEC Operation:**
```swift
let packet = try await session.send(ECOperations.downloads())
let downloads = try ECResponseParser.parseDownloads(packet)
```

**BridgeProtocol Method:**
```swift
func downloads(config: AMuleConnectionConfig) async throws -> ([BridgeDownloadPayload], String)
```

**Response Model:** `[ECDownload]`
- `ecid`: EC ID for the download
- `hash`: File hash (MD4)
- `name`: Filename
- `size`: Total file size (bytes)
- `done`: Bytes downloaded
- `progress`: Download percentage (0-100)
- `sourcesCurrent`: Currently available sources
- `sourcesTotal`: Total sources known
- `speed`: Current download speed
- `status`: Human-readable status
- `priority`: Download priority

**Example Response:**
```json
{
  "ok": true,
  "downloads": [
    {
      "ecid": 12345,
      "hash": "a1b2c3d4e5f6...",
      "name": "example.pdf",
      "size": 104857600,
      "done": 52428800,
      "progress": 50.0,
      "sources_current": 25,
      "sources_total": 30,
      "speed": 1048576,
      "status": "Downloading",
      "priority": 0
    }
  ]
}
```

---

### sources

Returns source details for a specific download.

**SwiftEC Operation:**
```swift
// First get the queue to find the file ID
let queuePacket = try await session.send(ECOperations.sourcesQueueLookup())
// Then get source updates
let updatePacket = try await session.send(ECOperations.sourcesUpdate())
let sources = try ECResponseParser.parseSources(updatePacket, requestFileID: fileID)
```

**BridgeProtocol Method:**
```swift
func sources(hash: String, config: AMuleConnectionConfig) async throws -> ([DownloadSourceItem], String)
```

**Response Model:** `[ECSource]`
- `clientID`: Client identifier
- `clientName`: Peer client name
- `userIP`: Peer IP address
- `userPort`: Peer port
- `software`: Client software
- `downloadState`: State code
- `downloadStateText`: Human-readable state
- `downSpeedKBps`: Download speed from this source

**Example Response:**
```json
{
  "ok": true,
  "sources": [
    {
      "client_id": 12345,
      "client_name": "eMule User",
      "user_ip": "192.168.1.100",
      "user_port": 4662,
      "software": "eMule",
      "download_state": 3,
      "download_state_text": "Downloading",
      "down_speed_kbps": 128.5
    }
  ]
}
```

---

### servers

Returns configured server list.

**SwiftEC Operation:**
```swift
let packet = try await session.send(ECOperations.servers())
let servers = try ECResponseParser.parseServers(packet)
```

**BridgeProtocol Method:**
```swift
func servers(config: AMuleConnectionConfig) async throws -> ([BridgeServerPayload], String)
```

**Response Model:** `[ECServer]`
- `id`: Server identifier
- `name`: Server name
- `address`: Server address string
- `ip`: Server IP
- `port`: Server port
- `users`: Current user count
- `maxUsers`: Maximum users
- `files`: File count on server
- `ping`: Ping time

**Example Response:**
```json
{
  "ok": true,
  "servers": [
    {
      "id": 1,
      "name": "eMule Security",
      "address": "80.208.228.241:4321",
      "ip": "80.208.228.241",
      "port": 4321,
      "users": 12456,
      "max_users": 50000,
      "files": 8923412,
      "ping": 45
    }
  ]
}
```

---

## Action Operations

### search

Starts a file search and polls for results.

**SwiftEC Operation:**
```swift
// Start search
_ = try await session.send(ECOperations.search(scope: "kad", query: "search term"))

// Poll for progress and results
let progress = try ECResponseParser.parseSearchProgress(
    try await session.send(ECOperations.searchProgress())
)
let results = try ECResponseParser.parseSearchResults(
    try await session.send(ECOperations.searchResults())
)
```

**BridgeProtocol Method:**
```swift
func search(scope: String, query: String, polls: Int, pollIntervalMs: Int, config: AMuleConnectionConfig) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String)
```

**Parameters:**
- `scope`: Search scope ("local", "global", "kad")
- `query`: Search string
- `polls`: Maximum number of poll iterations
- `pollIntervalMs`: Milliseconds between polls

**Response Model:** `[ECSearchResult]`
- `id`: Result identifier
- `hash`: File hash
- `name`: Filename
- `size`: File size (bytes)
- `sources`: Source count
- `completeSources`: Sources with complete file
- `alreadyHave`: Whether already downloaded

**Example Response:**
```json
{
  "ok": true,
  "progress": 100,
  "results": [
    {
      "id": 1,
      "hash": "a1b2c3d4...",
      "name": "search result.pdf",
      "size": 10485760,
      "sources": 25,
      "complete_sources": 20,
      "already_have": false
    }
  ]
}
```

---

### searchStop

Stops an active search.

**SwiftEC Operation:**
```swift
let packet = try ECOperations.searchStop()
```

**BridgeProtocol Method:**
```swift
func searchStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
```

**Example Response:**
```json
{
  "ok": true,
  "message": "Search stop requested"
}
```

---

### download

Downloads a file from search results.

**SwiftEC Operation:**
```swift
let packet = try ECOperations.download(hash: "a1b2c3d4...")
```

**BridgeProtocol Method:**
```swift
func download(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
```

**Example Response:**
```json
{
  "ok": true,
  "message": "Download request accepted"
}
```

---

### addLink

Adds an ED2K link to downloads.

**SwiftEC Operation:**
```swift
let packet = try ECOperations.addLink("ed2k://|file|name|size|hash|/")
```

**BridgeProtocol Method:**
```swift
func addLink(link: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
```

**Example Response:**
```json
{
  "ok": true,
  "message": "Link add request accepted"
}
```

---

### pause

Pauses a download.

**SwiftEC Operation:**
```swift
let packet = try ECOperations.pause(hash: "a1b2c3d4...")
```

**BridgeProtocol Method:**
```swift
func pause(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
```

**Example Response:**
```json
{
  "ok": true,
  "message": "Action completed"
}
```

---

### resume

Resumes a paused download.

**SwiftEC Operation:**
```swift
let packet = try ECOperations.resume(hash: "a1b2c3d4...")
```

**BridgeProtocol Method:**
```swift
func resume(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
```

**Example Response:**
```json
{
  "ok": true,
  "message": "Action completed"
}
```

---

## Network Operations

### connect

Connects to ED2K/Kad networks.

**SwiftEC Operation:**
```swift
let packet = try ECOperations.coreConnect()
```

**BridgeProtocol Method:**
```swift
func connect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
```

**Example Response:**
```json
{
  "ok": true,
  "message": "Connected"
}
```

---

### disconnect

Disconnects from ED2K/Kad networks.

**SwiftEC Operation:**
```swift
let packet = try ECOperations.coreDisconnect()
```

**BridgeProtocol Method:**
```swift
func disconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
```

**Example Response:**
```json
{
  "ok": true,
  "message": "Disconnected"
}
```

---

### serverConnect

Connects to a specific server.

**SwiftEC Operation:**
```swift
let packet = try ECOperations.serverConnect(ip: "80.208.228.241", port: 4321)
```

**BridgeProtocol Method:**
```swift
func serverConnect(ip: String?, port: Int?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
```

**Parameters:**
- `ip`: Server IP (optional - uses current server if nil)
- `port`: Server port (optional)

**Example Response:**
```json
{
  "ok": true,
  "message": "Server connect requested"
}
```

---

### serverDisconnect

Disconnects from current server.

**SwiftEC Operation:**
```swift
let packet = try ECOperations.serverDisconnect()
```

**BridgeProtocol Method:**
```swift
func serverDisconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
```

**Example Response:**
```json
{
  "ok": true,
  "message": "Server disconnect requested"
}
```

---

## Management Operations

### serverAdd

Adds a server to the server list.

**SwiftEC Operation:**
```swift
let packet = try ECOperations.serverAdd(address: "80.208.228.241:4321", name: "My Server")
```

**BridgeProtocol Method:**
```swift
func serverAdd(address: String, name: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
```

**Parameters:**
- `address`: Server address (IP:port format)
- `name`: Optional server name

**Example Response:**
```json
{
  "ok": true,
  "message": "Server add requested"
}
```

---

### serverRemove

Removes a server from the server list.

**SwiftEC Operation:**
```swift
let packet = try ECOperations.serverRemove(ip: "80.208.228.241", port: 4321)
```

**BridgeProtocol Method:**
```swift
func serverRemove(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
```

**Example Response:**
```json
{
  "ok": true,
  "message": "Server remove requested"
}
```

---

## Preferences Operations

### prefsConnectionGet

Gets connection preferences.

**SwiftEC Operation:**
```swift
let packet = try await session.send(ECOperations.prefsConnectionGet())
let prefs = try ECResponseParser.parseConnectionPrefs(packet)
```

**BridgeProtocol Method:**
```swift
func prefsConnectionGet(config: AMuleConnectionConfig) async throws -> (BridgeConnectionPrefsPayload, String)
```

**Response Model:** `ECConnectionPrefs`
- `maxDownload`: Maximum download speed (bytes/s)
- `maxUpload`: Maximum upload speed (bytes/s)

**Example Response:**
```json
{
  "ok": true,
  "prefs_connection": {
    "max_dl": 1048576,
    "max_ul": 524288
  }
}
```

---

### prefsConnectionSet

Sets connection preferences.

**SwiftEC Operation:**
```swift
let packet = try ECOperations.prefsConnectionSet(maxDownload: 2097152, maxUpload: 1048576)
```

**BridgeProtocol Method:**
```swift
func prefsConnectionSet(maxDownload: Int, maxUpload: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
```

**Parameters:**
- `maxDownload`: Maximum download speed (bytes/s)
- `maxUpload`: Maximum upload speed (bytes/s)

**Example Response:**
```json
{
  "ok": true,
  "message": "Connection speed limits updated"
}
```

---

## Downloads Management

Beyond pause and resume, SwiftEC supports a full suite of download control operations.

**Stop** (`download-stop`) halts a transfer permanently.
**Cancel** (`cancel`) removes a download from the queue.
**Priority** (`priority`) changes the transfer priority level.
**Rename** (`rename`) changes the destination filename.
**A4AF Swap** (`download-a4af-this`, `download-a4af-auto`, `download-a4af-others`) swaps an asked-for-another-file source between targets.
**Clear Completed** (`clear-completed`) removes finished transfers from the queue.
**Set Category** (`download-set-category`) assigns a download to a category.

---

## Server Management

Beyond add and remove, the server surface includes connect, disconnect, update from URL, static flag toggling, priority setting, and server info logging.

**Server Update from URL** (`server-update-from-url`) fetches a fresh server list.
**Server Set Static** (`server-set-static`) marks a server as static.
**Server Set Priority** (`server-set-priority`) changes a server priority.
**Server Info** (`server-info`) retrieves server log information.
**Clear Server Info** (`clear-server-info`) clears the server info log.

---

## Kad Operations

Kademlia DHT management covers start, stop, bootstrap, and update.

**Kad Start** (`kad-start`) brings the DHT online.
**Kad Stop** (`kad-stop`) shuts the DHT down.
**Kad Bootstrap** (`kad-bootstrap`) seeds the DHT from a known host and port.
**Kad Update from URL** (`kad-update-from-url`) refreshes the nodes list from a remote URL.

---

## Shared Files Operations

Shared file management covers listing, reloading, priority, and metadata.

**Shared Files** (`shared-files`) lists files currently shared by the daemon.
**Shared Files Reload** (`shared-files-reload`) rescans the shared directories.
**Shared File Priority** (`shared-file-priority`) changes the upload priority of a shared file.
**Shared File Comment/Rating** (`shared-file-comment-rating`) sets a comment and rating on a shared file.

---

## Categories Operations

Download category management covers create, update, and delete.

**Categories** (`categories`) lists existing categories.
**Category Create** (`category-create`) adds a new category with name, path, comment, color, and priority.
**Category Update** (`category-update`) modifies an existing category.
**Category Delete** (`category-delete`) removes a category.

---

## Friends Operations

Friend list management covers add, remove, and slot control.

**Friends** (`friends`) lists current friends.
**Friend Add** (`friend-add`) adds a friend by hash, IP, port, and name.
**Friend Remove** (`friend-remove`) removes a friend.
**Friend Slot** (`friend-slot`) grants or revokes an upload slot for a friend.

---

## Stats Operations

Statistics retrieval covers tree and graph data.

**Stats Tree** (`stats-tree`) returns a hierarchical statistics tree.
**Stats Graphs** (`stats-graphs`) returns historical graph data for bandwidth and connections.

---

## Logs Operations

Log access covers core logs, debug logs, server info, and reset operations.

**Log** (`log`) retrieves the main application log.
**Debug Log** (`debug-log`) retrieves the debug log.
**Last Log Entry** (`last-log-entry`) fetches the most recent log line.
**Reset Log** (`reset-log`) clears the main log.
**Reset Debug Log** (`reset-debuglog`) clears the debug log.
**Server Info** (`server-info`) retrieves server-specific log output.
**Clear Server Info** (`clear-server-info`) clears the server info log.

---

## IP Filter Operations

IP filter management covers reload and remote update.

**IP Filter Reload** (`ipfilter-reload`) reloads the local IP filter list.
**IP Filter Update** (`ipfilter-update`) downloads and applies an updated IP filter from a URL.

---

## Admin Operations

**Shutdown** (`shutdown`) requests a graceful daemon shutdown.

---

## Operation Codes

Reference table of EC protocol opcodes used internally. Several opcodes serve dual purposes depending on context.

| Opcode | Hex | Operation |
|--------|-----|-----------|
| 0x01 | 1 | noop |
| 0x05 | 5 | failed |
| 0x06 | 6 | strings |
| 0x07 | 7 | miscData |
| 0x09 | 9 | addLink |
| 0x0A | 10 | shutdown / statRequest |
| 0x0C | 12 | stats |
| 0x0D | 13 | getConnectionState / getDownloadQueue |
| 0x0E | 14 | getLastLogEntry / getUploadQueue |
| 0x10 | 16 | getSharedFiles |
| 0x11 | 17 | sharedSetPriority |
| 0x12 | 18 | resetDebugLog |
| 0x16 | 22 | partFileSwapA4AFThis |
| 0x17 | 23 | partFileSwapA4AFThisAuto |
| 0x18 | 24 | partFileSwapA4AFOthers |
| 0x19 | 25 | partFilePause |
| 0x1A | 26 | partFileResume |
| 0x1B | 27 | partFileStop |
| 0x1C | 28 | partFilePrioSet |
| 0x1D | 29 | partFileDelete |
| 0x1E | 30 | partFileSetCat |
| 0x1F | 31 | downloadQueue |
| 0x20 | 32 | uploadQueue |
| 0x22 | 34 | sharedFiles |
| 0x23 | 35 | sharedFilesReload |
| 0x25 | 37 | renameFile |
| 0x26 | 38 | searchStart |
| 0x27 | 39 | searchStop |
| 0x28 | 40 | searchResults |
| 0x29 | 41 | searchProgress |
| 0x2A | 42 | clientSwapToAnotherFile / downloadSearchResult |
| 0x2B | 43 | ipfilterReload |
| 0x2C | 44 | getServerList |
| 0x2D | 45 | serverList |
| 0x2E | 46 | serverDisconnect |
| 0x2F | 47 | serverConnect |
| 0x30 | 48 | serverRemove |
| 0x31 | 49 | serverAdd |
| 0x32 | 50 | serverUpdateFromURL |
| 0x35 | 53 | getLog |
| 0x36 | 54 | getDebugLog |
| 0x37 | 55 | getServerInfo |
| 0x38 | 56 | log |
| 0x39 | 57 | debugLog |
| 0x3B | 59 | resetLog |
| 0x3D | 61 | clearServerInfo |
| 0x3F | 63 | getPreferences |
| 0x40 | 64 | setPreferences |
| 0x41 | 65 | createCategory |
| 0x42 | 66 | updateCategory |
| 0x43 | 67 | deleteCategory |
| 0x44 | 68 | getStatsGraphs |
| 0x45 | 69 | statsGraphs |
| 0x46 | 70 | getStatsTree |
| 0x47 | 71 | statsTree |
| 0x48 | 72 | kadStart |
| 0x49 | 73 | kadStop |
| 0x4A | 74 | connect |
| 0x4B | 75 | disconnect |
| 0x4D | 77 | kadUpdateFromURL |
| 0x4E | 78 | kadBootstrapFromIP |
| 0x51 | 81 | ipfilterUpdate |
| 0x52 | 82 | getUpdate |
| 0x53 | 83 | clearCompleted |
| 0x55 | 85 | sharedFileSetComment |
| 0x56 | 86 | serverSetStaticPriority |
| 0x57 | 87 | friend |

## Error Handling

All operations can throw the following errors:

### ECOperationError
- `unsupportedOperation(String)`: Operation not in capability set
- `invalidHash(String)`: Malformed file hash
- `invalidServerEndpoint(String)`: Invalid IP:port format

### ECResponseParserError
- `unexpectedOpcode(expected: UInt8, actual: UInt8)`: Wrong response type
- `downloadNotFound(hash: String)`: File hash not in queue
- `operationFailed(String)`: Core returned error
- `missingPreferences`: Expected prefs missing

### ECSessionError
- `invalidState(expected: State, actual: State)`: Wrong session state
- `connectionClosed`: Connection lost
- `connectionFailed(String)`: Connection error
- `authenticationFailed(String)`: Auth error
- `packetTooLarge(Int)`: Packet exceeds max size
- `invalidPort(UInt16)`: Invalid port number

## Capability Gating

Operations can be gated by capabilities:

```swift
let gate = ECCapabilityGate(["downloads", "search"])
let packet = try ECOperations.downloads(gate: gate) // Succeeds
let packet = try ECOperations.servers(gate: gate)   // Throws unsupportedOperation
```

Use `nil` gate to skip capability checking.
