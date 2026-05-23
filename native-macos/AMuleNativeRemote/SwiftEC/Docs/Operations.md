# SwiftEC Operations Reference

Complete reference for all 23 operations supported by SwiftEC.

## Operation Categories

| Category | Operations | Description |
|----------|-----------|-------------|
| **Info** | capabilities, status | Bridge and connection information |
| **Read** | downloads, sources, servers | Data retrieval operations |
| **Action** | search, searchStop, download, addLink, pause, resume | File and transfer actions |
| **Network** | connect, disconnect, serverConnect, serverDisconnect | Network management |
| **Management** | serverAdd, serverRemove | Server list management |
| **Prefs** | prefsConnectionGet, prefsConnectionSet | Preferences access |

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

## Operation Codes

Reference table of EC protocol opcodes used internally:

| Opcode | Hex | Operation |
|--------|-----|-----------|
| 0x09 | 9 | addLink |
| 0x0A | 10 | statRequest |
| 0x0D | 13 | getDownloadQueue |
| 0x19 | 25 | partFilePause |
| 0x1A | 26 | partFileResume |
| 0x1F | 31 | downloadQueue |
| 0x26 | 38 | searchStart |
| 0x27 | 39 | searchStop |
| 0x28 | 40 | searchResults |
| 0x29 | 41 | searchProgress |
| 0x2A | 42 | downloadSearchResult |
| 0x2C | 44 | getServerList |
| 0x2D | 45 | serverList |
| 0x2E | 46 | serverDisconnect |
| 0x2F | 47 | serverConnect |
| 0x30 | 48 | serverRemove |
| 0x31 | 49 | serverAdd |
| 0x3F | 63 | getPreferences |
| 0x40 | 64 | setPreferences |
| 0x4A | 74 | connect |
| 0x4B | 75 | disconnect |
| 0x52 | 82 | getUpdate |

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
