# Swift EC V1 Contract

## Overview

This document defines the V1 contract for the Swift Native EC Bridge, a pure-Swift implementation of the aMule External Connections (EC) protocol for Apple platforms (macOS and iOS).

**Implementation Status:** COMPLETE

**Last Updated:** July 2026

## Implementation Summary

SwiftEC implements a three-layer architecture:

1. **AMuleECProtocol**: Binary packet encoding/decoding, tag serialization, MD5 auth, zlib compression
2. **AMuleECClient**: Session management, Network.framework transport, operation builders, response parsing
3. **AMuleECBridgeAdapter**: BridgeProtocol conformance, JSON envelope generation, platform integration

The native SwiftEC operation surface is defined in `ECSupportedOps` and covered by tests. SwiftEC advertises approximately 57 bridge operations across fourteen categories. The canonical source of truth is `Sources/AMuleECProtocol/ECSupportedOps.swift`.

## Canonical V1 Operation Surface

The Swift EC bridge operation surface is owned by
`Sources/AMuleECProtocol/ECSupportedOps.swift`. Keep that source and
`ECSupportedOpsTests` as the canonical list instead of duplicating operation
membership in older bridge-specific code or documents.

The table below summarizes representative operations from each category. It is not the authoritative list.

| # | Operation | Handler | Category | Status | Swift Method |
|---|-----------|---------|----------|--------|--------------|
| 1 | `capabilities` | ECOperations.capabilities() | Info | Complete | `capabilities()` |
| 2 | `status` | ECOperations.status() | Info | Complete | `status()` |
| 3 | `shutdown` | ECOperations.shutdown() | Admin | Complete | `shutdown()` |
| 4 | `connection-state` | ECOperations.connectionState() | Info | Complete | `connectionState()` |
| 5 | `downloads` | ECOperations.downloads() | Read | Complete | `downloads()` |
| 6 | `sources` | ECOperations.sources() | Read | Complete | `sources(hash:)` |
| 7 | `search` | ECOperations.search() | Action | Complete | `search(scope:query:)` |
| 8 | `search-stop` | ECOperations.searchStop() | Action | Complete | `searchStop()` |
| 9 | `download` | ECOperations.download() | Action | Complete | `download(hash:)` |
| 10 | `add-link` | ECOperations.addLink() | Action | Complete | `addLink(_:)` |
| 11 | `pause` | ECOperations.pause() | Action | Complete | `pause(hash:)` |
| 12 | `resume` | ECOperations.resume() | Action | Complete | `resume(hash:)` |
| 13 | `connect` | ECOperations.coreConnect() | Network | Complete | `coreConnect()` |
| 14 | `disconnect` | ECOperations.coreDisconnect() | Network | Complete | `coreDisconnect()` |
| 15 | `server-connect` | ECOperations.serverConnect() | Network | Complete | `serverConnect(ip:port:)` |
| 16 | `server-disconnect` | ECOperations.serverDisconnect() | Network | Complete | `serverDisconnect()` |
| 17 | `server-add` | ECOperations.serverAdd() | Server Management | Complete | `serverAdd(address:name:)` |
| 18 | `server-remove` | ECOperations.serverRemove() | Server Management | Complete | `serverRemove(ip:port:)` |
| 19 | `servers` | ECOperations.servers() | Read | Complete | `servers()` |
| 20 | `prefs-connection-get` | ECOperations.prefsConnectionGet() | Preferences | Complete | `prefsConnectionGet()` |
| 21 | `prefs-connection-set` | ECOperations.prefsConnectionSet() | Preferences | Complete | `prefsConnectionSet(maxDownload:maxUpload:)` |
| 22 | `kad-start` | ECOperations.kadStart() | Kad | Complete | `kadStart()` |
| 23 | `kad-stop` | ECOperations.kadStop() | Kad | Complete | `kadStop()` |
| 24 | `kad-bootstrap` | ECOperations.kadBootstrap() | Kad | Complete | `kadBootstrap(ip:port:)` |
| 25 | `kad-update-from-url` | ECOperations.kadUpdateFromURL() | Kad | Complete | `kadUpdateFromURL(url:)` |
| 26 | `uploads` | ECOperations.uploads() | Read | Complete | `uploads()` |
| 27 | `shared-files` | ECOperations.sharedFiles() | Read | Complete | `sharedFiles()` |
| 28 | `shared-files-reload` | ECOperations.sharedFilesReload() | Shared Files | Complete | `sharedFilesReload()` |
| 29 | `log` | ECOperations.log() | Logs | Complete | `log()` |
| 30 | `debug-log` | ECOperations.debugLog() | Logs | Complete | `debugLog()` |
| 31 | `categories` | ECOperations.categories() | Read | Complete | `categories()` |
| 32 | `category-create` | ECOperations.categoryCreate() | Categories | Complete | `categoryCreate(...)` |
| 33 | `category-update` | ECOperations.categoryUpdate() | Categories | Complete | `categoryUpdate(...)` |
| 34 | `category-delete` | ECOperations.categoryDelete() | Categories | Complete | `categoryDelete(categoryID:)` |
| 35 | `ipfilter-reload` | ECOperations.ipfilterReload() | IP Filter | Complete | `ipfilterReload()` |
| 36 | `ipfilter-update` | ECOperations.ipfilterUpdate() | IP Filter | Complete | `ipfilterUpdate(url:)` |
| 37 | `friends` | ECOperations.friends() | Read | Complete | `friends()` |
| 38 | `friend-add` | ECOperations.friendAdd() | Friends | Complete | `friendAdd(...)` |
| 39 | `friend-remove` | ECOperations.friendRemove() | Friends | Complete | `friendRemove(friendID:)` |
| 40 | `friend-slot` | ECOperations.friendSlot() | Friends | Complete | `friendSlot(friendID:enabled:)` |
| 41 | `stats-tree` | ECOperations.statsTree() | Stats | Complete | `statsTree(capping:)` |
| 42 | `stats-graphs` | ECOperations.statsGraphs() | Stats | Complete | `statsGraphs(width:scale:last:)` |
| 43 | `clear-completed` | ECOperations.clearCompleted() | Action | Complete | `clearCompleted(ecids:)` |
| 44 | `download-stop` | ECOperations.stop() | Action | Complete | `stop(hash:)` |
| 45 | `cancel` | ECOperations.cancel() | Action | Complete | `cancel(hash:)` |
| 46 | `priority` | ECOperations.priority() | Action | Complete | `priority(hash:value:)` |
| 47 | `rename` | ECOperations.rename() | Action | Complete | `rename(hash:name:)` |
| 48 | `download-a4af-this` | ECOperations.swapA4AF() | Action | Complete | `swapA4AF(hash:mode:)` |
| 49 | `download-set-category` | ECOperations.downloadSetCategory() | Action | Complete | `downloadSetCategory(hash:categoryID:)` |
| 50 | `server-update-from-url` | ECOperations.serverUpdateFromURL() | Server Management | Complete | `serverUpdateFromURL(url:)` |
| 51 | `server-set-static` | ECOperations.serverSetStatic() | Server Management | Complete | `serverSetStatic(ecid:isStatic:)` |
| 52 | `server-set-priority` | ECOperations.serverSetPriority() | Server Management | Complete | `serverSetPriority(ecid:priority:)` |
| 53 | `server-info` | ECOperations.serverInfo() | Logs | Complete | `serverInfo()` |
| 54 | `clear-server-info` | ECOperations.clearServerInfo() | Logs | Complete | `clearServerInfo()` |
| 55 | `reset-log` | ECOperations.resetLog() | Logs | Complete | `resetLog()` |
| 56 | `shared-file-priority` | ECOperations.sharedFilePriority() | Shared Files | Complete | `sharedFilePriority(hash:priority:)` |
| 57 | `shared-file-comment-rating` | ECOperations.sharedFileCommentRating() | Shared Files | Complete | `sharedFileCommentRating(hash:comment:rating:)` |

**Notes:**
- Supported operation names are advertised by SwiftEC capabilities.
- BridgeProtocol exposes supported operations uniformly.
- Platform-specific feature flags control availability in apps.
- The full canonical list is in `ECSupportedOps.swift`.

## Protocol Compatibility

### SwiftEC BridgeAdapter

**SwiftECBridgeAdapter** (`Sources/AMuleECBridgeAdapter/SwiftECBridgeAdapter.swift`):
- Implements the full advertised SwiftEC operation surface
- Conforms to BridgeProtocol for seamless integration
- Provides JSON envelope output for all responses
- Supports capability gating for progressive enhancement

**Key Features:**
- Pure Swift implementation - no external binaries
- Network.framework transport (macOS 10.14+, iOS 12.0+)
- Automatic reconnection with exponential backoff
- Full Sendable conformance for Swift 6 compatibility
- Thread-safe via actor isolation

### Implementation Status by Component

| Component | Status | File |
|-----------|--------|------|
| Binary Protocol | Complete | `AMuleECProtocol/ECPacket.swift` |
| Tag Serialization | Complete | `AMuleECProtocol/ECTag.swift` |
| MD5 Authentication | Complete | `AMuleECProtocol/ECLegacyAuth.swift` |
| Zlib Compression | Complete | `AMuleECProtocol/ECCompression.swift` |
| Session Management | Complete | `AMuleECClient/ECSession.swift` |
| Network Transport | Complete | `AMuleECClient/ECConnection.swift` |
| Operation Builders | Complete | `AMuleECClient/ECOperations.swift` |
| Response Parsing | Complete | `AMuleECClient/ECResponseParser.swift` |
| JSON Envelopes | Complete | `AMuleECClient/ECJSONEnvelope.swift` |
| Bridge Adapter | Complete | `AMuleECBridgeAdapter/SwiftECBridgeAdapter.swift` |

## Envelope Schema Version 1

### JSON Envelope Structure

All responses follow this envelope format defined in `ECJSONEnvelope`:

```json
{
  "ok": boolean,
  "error": string | null,
  "message": string,
  "schema_version": 1,
  "capabilities": { ... },
  "status": { ... },
  "downloads": [ ... ],
  "sources": [ ... ],
  "servers": [ ... ],
  "uploads": [ ... ],
  "shared_files": [ ... ],
  "categories": [ ... ],
  "friends": [ ... ],
  "stats_tree": { ... },
  "stats_graphs": { ... },
  "log": { ... },
  "progress": number,
  "results": [ ... ],
  "prefs_connection": { ... }
}
```

### Top-Level Keys

- `ok`: Boolean success indicator
- `error`: Error message if ok=false, null otherwise
- `message`: Human-readable status message
- `schema_version`: Always 1 for V1 protocol
- `capabilities`: Bridge capability advertisement (capabilities op)
- `status`: Connection status (status op)
- `downloads`: Array of download payloads (downloads op)
- `sources`: Array of source payloads (sources op)
- `servers`: Array of server payloads (servers op)
- `uploads`: Array of upload payloads (uploads op)
- `shared_files`: Array of shared file payloads (shared-files op)
- `categories`: Array of category payloads (categories op)
- `friends`: Array of friend payloads (friends op)
- `stats_tree`: Statistics tree payload (stats-tree op)
- `stats_graphs`: Statistics graphs payload (stats-graphs op)
- `log`: Log payload (log or debug-log op)
- `progress`: Search progress percentage 0-100 (search op)
- `results`: Array of search results (search op)
- `prefs_connection`: Connection preferences (prefs-connection-get op)

### Implementation: ECJSONEnvelope

```swift
public struct ECBridgeEnvelope<Payload: Encodable>: Encodable {
    public let ok: Bool
    public let schemaVersion: Int?
    public let error: String?
    public let message: String?
    public let capabilities: ECCapabilities?
    public let status: ECStatus?
    public let downloads: [ECDownload]?
    public let sources: [ECSource]?
    public let servers: [ECServer]?
    public let uploads: [ECUpload]?
    public let sharedFiles: [ECSharedFile]?
    public let categories: [ECCategory]?
    public let friends: [ECFriend]?
    public let statsTree: ECStatsTreeNode?
    public let statsGraphs: ECStatsGraphs?
    public let log: ECCoreLog?
    public let progress: Int?
    public let results: [ECSearchResult]?
    public let prefsConnection: ECConnectionPrefs?
}
```

## Adapter Interface

### SwiftECBridgeAdapter

The unified adapter conforms to BridgeProtocol and implements the full advertised operation surface:

```swift
@available(macOS 10.15, iOS 13.0, *)
public struct SwiftECBridgeAdapter: BridgeProtocol, Sendable {
    public init(session: ECSession? = nil)

    // Info
    public func capabilities(config: AMuleConnectionConfig) async throws -> (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String)
    public func status(config: AMuleConnectionConfig) async throws -> (BridgeStatusPayload, String)

    // Network
    public func connect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func disconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)

    // Read
    public func downloads(config: AMuleConnectionConfig) async throws -> ([BridgeDownloadPayload], String)
    public func sources(hash: String, config: AMuleConnectionConfig) async throws -> ([BridgeDownloadSourcePayload], String)
    public func servers(config: AMuleConnectionConfig) async throws -> ([BridgeServerPayload], String)
    public func uploads(config: AMuleConnectionConfig) async throws -> ([BridgeUploadPayload], String)
    public func sharedFiles(config: AMuleConnectionConfig) async throws -> ([BridgeSharedFilePayload], String)
    public func categories(config: AMuleConnectionConfig) async throws -> ([BridgeCategoryPayload], String)
    public func friends(config: AMuleConnectionConfig) async throws -> ([BridgeFriendPayload], String)
    public func statsTree(capping: Int?, config: AMuleConnectionConfig) async throws -> (BridgeStatsTreeNodePayload, String)
    public func statsGraphs(width: Int, scale: Int, last: Double?, config: AMuleConnectionConfig) async throws -> (BridgeStatsGraphsPayload, String)

    // Search
    public func search(scope: String, query: String, polls: Int, pollIntervalMs: Int, config: AMuleConnectionConfig) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String)
    public func search(request: ECSearchRequest, polls: Int, pollIntervalMs: Int, config: AMuleConnectionConfig) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String)
    public func searchStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)

    // Action
    public func download(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func addLink(link: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func rename(hash: String, name: String, config: AMuleConnectionConfig) async throws -> RenameAcknowledgement
    public func pause(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func resume(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func stop(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func swapA4AF(hash: String, mode: ECOperations.A4AFSwapMode, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func cancel(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func priority(hash: String, value: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func downloadSetCategory(hash: String, categoryID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func clearCompleted(ecids: [Int], config: AMuleConnectionConfig) async throws -> (message: String, raw: String)

    // Server Management
    public func serverConnect(ip: String?, port: Int?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func serverDisconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func serverAdd(address: String, name: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func serverRemove(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func serverUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func serverSetStatic(ecid: Int, isStatic: Bool, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func serverSetPriority(ecid: Int, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)

    // Kad
    public func kadStart(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func kadStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func kadBootstrap(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func kadUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)

    // Shared Files
    public func sharedFilesReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func sharedFilePriority(hash: String, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func sharedFileCommentRating(hash: String, comment: String, rating: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)

    // Preferences
    public func prefsConnectionGet(config: AMuleConnectionConfig) async throws -> (BridgeConnectionPrefsPayload, String)
    public func prefsConnectionSet(maxDownload: Int, maxUpload: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func prefsConnectionSet(prefs: BridgeConnectionPrefsPayload, group: ECOperations.PreferencesGroup, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)

    // Categories
    public func categoryCreate(name: String, path: String, comment: String, color: Int, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func categoryUpdate(id: Int, name: String, path: String, comment: String, color: Int, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func categoryDelete(categoryID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)

    // Logs
    public func coreLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String)
    public func debugLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String)
    public func serverInfo(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String)
    public func clearServerInfo(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func resetLog(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)

    // IP Filter
    public func ipfilterReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func ipfilterUpdate(url: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)

    // Friends
    public func friendAdd(hash: String, ip: String, port: Int, name: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func friendRemove(friendID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func friendRequestSharedList(friendID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
    public func friendSlot(friendID: Int, enabled: Bool, config: AMuleConnectionConfig) async throws -> (message: String, raw: String)
}
```

### Capability Advertisement

The adapter reports supported operations via the capabilities operation:

```swift
public struct ECCapabilities: Codable, Equatable, Sendable {
    public let bridgeVersion: String
    public let clientName: String
    public let defaultHost: String
    public let defaultPort: Int
    public let ops: [String]  // List of supported operation names
}
```

Default capability set includes all advertised operations from `ECSupportedOps.allOperations`.

## Binary Protocol Layer

### Packet Framing (EC Protocol)

**Implementation:** `AMuleECProtocol/ECPacket.swift`

- **Header**: 8 bytes (4-byte flags + 4-byte body length, little-endian)
- **Body**: Variable length, opcode-bearing, tag-encoded
- **Max body size**: 16 MiB (rejection threshold)

```swift
public struct ECPacketHeader {
    public let flags: UInt32      // Protocol flags
    public let bodyLength: UInt32 // Body size in bytes

    public static let byteCount = 8
}
```

### Tag Encoding

**Implementation:** `AMuleECProtocol/ECTag.swift`

- **Header**: 2-byte name + 1-byte type + 4-byte length
- **Child flag**: Bit 0 of name indicates nested children present
- **Types**: uint8/16/32/64, string, double, IPv4, MD4 hash (16 bytes)
- **Empty tags**: Zero-length data for capability markers

```swift
public struct ECTag {
    public let name: UInt16       // Tag identifier
    public let type: ECType       // Value type
    public let value: ECValue     // Typed value
    public let children: [ECTag]  // Nested tags
}

public enum ECType: UInt8 {
    case custom = 0
    case uint8 = 1
    case uint16 = 2
    case uint32 = 3
    case uint64 = 4
    case string = 5
    case double = 6
    case ipv4 = 7
    case hash16 = 8
}
```

### Compression

**Implementation:** `AMuleECProtocol/ECCompression.swift`

- **Zlib**: Negotiated via EC_FLAG_ZLIB capability
- **Threshold**: Applied when body > 1024 bytes
- **Implementation**: Apple Compression framework (zlib)

```swift
public enum ECCompression {
    public static let threshold = 1024

    public static func compress(_ data: Data) throws -> Data
    public static func decompress(_ data: Data) throws -> Data
}
```

### UTF-8 Numbers

- **Negotiation**: EC_FLAG_UTF8_NUMBERS capability
- **Encoding**: Variable-length UTF-8 for integers instead of fixed-width
- **Not currently used in SwiftEC**: Fixed-width encoding used for simplicity

## Authentication

### Legacy MD5 Auth

**Implementation:** `AMuleECProtocol/ECLegacyAuth.swift` and `AMuleECProtocol/ECAuthPacket.swift`

1. Client sends `EC_OP_AUTH_REQ` with client info and capabilities
2. Server replies `EC_OP_AUTH_SALT` with random salt
3. Client computes: `MD5(password_hex_lower + MD5(salt_hex))`
4. Client sends `EC_OP_AUTH_PASSWD` with computed hash
5. Server replies `EC_OP_AUTH_OK` or `EC_OP_AUTH_FAIL`

**Password formats:**
- Plaintext: Converted to MD5 hex internally
- Pre-hashed: 32-character lowercase MD5 hex string accepted directly

**Implementation:** `CryptoKit.Insecure.MD5` (marked as insecure, used only for EC compatibility)

```swift
public enum ECLegacyAuth {
    public static func parseSalt(from packet: ECPacket) throws -> Data
    public static func computePasswordHash(password: String, salt: Data) -> Data
    public static func parseAuthResponse(_ packet: ECPacket) throws -> ECAuthResult
}

public enum ECAuthPacket {
    public static func authRequest(clientName: String, version: String) -> ECPacket
    public static func authPassword(password: String, salt: Data) throws -> ECPacket
}
```

## Platform Integration

### macOS

- **Minimum Version**: macOS 27
- **Swift Version**: Swift 6.2+
- **Available Adapters**:
  - Existing `MacOSBridgeAdapter` (process-based) - legacy
  - `SwiftECBridgeAdapter` (pure Swift) - new
- **Migration Path**: Swift adapter can be adopted incrementally
- **Framework Dependencies**: Network.framework, CryptoKit, Compression

### iOS

- **Minimum Version**: iOS 27
- **Swift Version**: Swift 6.2+
- **Production Adapter**: `SwiftECBridgeAdapter` (pure Swift)
- **No External Dependencies**: No bundled binaries required
- **Sand-box Compatible**: Uses only Apple frameworks
- **Framework Dependencies**: Network.framework, CryptoKit, Compression

## Dependencies

### Allowed (Apple Platform)
- `Network.framework` / `NWConnection` - TCP transport
- `CryptoKit.Insecure.MD5` - Legacy auth hashing
- `Compression` framework (zlib) - Packet compression
- `Foundation` - Core types

### Forbidden
- wxWidgets
- Crypto++
- OpenSSL
- Boost
- C++ runtime in Swift package
- `Process()` on iOS production path

## Testing Strategy

### Test Organization

Tests are organized by module in `Tests/`:

| Test Target | Coverage | Dependencies |
|-------------|----------|--------------|
| `AMuleECProtocolTests` | Packet, tag, compression, auth | Fixtures |
| `AMuleECClientTests` | Session, connection, operations | None |
| `AMuleECBridgeAdapterTests` | Adapter integration | None |

### Fixtures

Test fixtures in `Tests/Fixtures/`:
1. **ECAuthFixtures.swift**: Authentication test vectors
2. **ECTagFixtures.swift**: Tag serialization examples

### Test Categories

1. **Unit tests**: Codec, auth, compression (offline, always run)
2. **Integration tests**: Real daemon connection (env-gated)
3. **Adapter contract tests**: SwiftEC JSON envelope and app-facing bridge behavior

### Running Tests

```bash
cd native-macos/AMuleNativeRemote/SwiftEC
swift test
```

### Environment Variables

Real-daemon integration tests require:
- `AMULE_EC_HOST` - Daemon hostname/IP
- `AMULE_EC_PORT` - Daemon port (default: 4712)
- `AMULE_EC_PASSWORD` - EC password

Tests skip gracefully with documentation when vars unavailable.

### Test Coverage

- **Protocol Layer**: Packet encoding/decoding, tag serialization, compression round-trip, MD5 auth
- **Client Layer**: Session state machine, connection handling, operation builders, response parsing
- **Adapter Layer**: BridgeProtocol conformance, JSON envelope formatting, error handling

## Implementation Details

### Thread Safety Model

SwiftEC uses Swift 6's strict concurrency checking:

1. **Actors for Mutable State:**
   - `ECSession`: Manages connection state
   - `ECConnection`: Wraps NWConnection
   - `ECRequestPipeline`: Queues requests

2. **Sendable Value Types:**
   - All models: `ECCapabilities`, `ECStatus`, `ECDownload`, etc.
   - All errors: `ECProtocolError`, `ECSessionError`, etc.
   - Protocol types: `ECPacket`, `ECTag`, `ECPacketHeader`

3. **No Data Races:**
   - Compiler-enforced isolation
   - All public APIs are Sendable-safe

### Session Configuration

```swift
public struct Configuration: Sendable {
    public let host: String
    public let port: UInt16
    public let password: String
    public let clientName: String
    public let clientVersion: String
    public let connectTimeout: TimeInterval
    public let requestTimeout: TimeInterval
    public let partialReadTimeout: TimeInterval
    public let automaticReconnect: Bool
    public let maximumReconnectDelay: TimeInterval
}
```

Defaults:
- `clientName`: "SwiftEC"
- `clientVersion`: "1.0"
- `connectTimeout`: 30 seconds
- `requestTimeout`: 30 seconds
- `partialReadTimeout`: 10 seconds
- `automaticReconnect`: true
- `maximumReconnectDelay`: 30 seconds

### Reconnection Strategy

Exponential backoff with configurable maximum:

```
Attempt 1: 1s delay
Attempt 2: 2s delay
Attempt 3: 4s delay
...
Attempt N: min(2^(N-1), maximumReconnectDelay)
```

Reset on successful connection.

### Error Hierarchy

```
ECProtocolError          - Protocol encoding/decoding errors
  ├── invalidHeader
  ├── packetTooLarge
  └── unknownTagType

ECSessionError           - Session/connection errors
  ├── invalidState
  ├── connectionClosed
  ├── connectionFailed
  ├── authenticationFailed
  ├── packetTooLarge
  └── invalidPort

ECResponseParserError    - Response parsing errors
  ├── unexpectedOpcode
  ├── downloadNotFound
  ├── operationFailed
  └── missingPreferences

ECOperationError         - Operation validation errors
  ├── unsupportedOperation
  ├── invalidHash
  └── invalidServerEndpoint
```

## References

- Native operation surface: `Sources/AMuleECProtocol/ECSupportedOps.swift`
- Swift adapter protocol: `Sources/AMuleECBridgeAdapter/SwiftECBridgeAdapter.swift`
- EC protocol headers: `src/libs/ec/cpp/ECSocket.h`, `ECPacket.h`, `ECTag.h`
- Apple Network.framework: TN3151

## Document History

- **Initial**: Contract specification for SwiftEC implementation
- **May 2026**: Updated with final implementation details, confirmed core operation set complete
- **July 2026**: Expanded to reflect the full ~57-operation advertised surface across fourteen categories
