# SwiftEC

A pure-Swift implementation of the aMule External Connections (EC) protocol for Apple platforms.

## Overview

SwiftEC provides a native Swift implementation of the EC protocol used to communicate with aMule daemon instances. It enables macOS and iOS applications to control and monitor aMule without relying on external binaries or C++ bindings.

## Features

- **Pure Swift Implementation**: No C++ dependencies, no external processes
- **Apple Platform Native**: Built on Network.framework for optimal performance
- **Full Protocol Support**: Implements all 23 EC operations
- **Type-Safe API**: Strongly typed models with Codable and Sendable conformance
- **Async/Await**: Modern Swift concurrency throughout
- **Automatic Reconnection**: Built-in retry logic with exponential backoff
- **Thread Safety**: All public APIs are Sendable-safe

## Requirements

- macOS 27+ or iOS 27+
- Swift 6.2+
- Xcode 27.0+

## Installation

### Swift Package Manager

Add SwiftEC to your `Package.swift`:

```swift
dependencies: [
    .package(path: "native-macos/AMuleNativeRemote/SwiftEC")
]
```

Or in Xcode: File → Add Package Dependencies → Select the SwiftEC folder.

## Architecture

SwiftEC is organized into three layers:

```
┌─────────────────────────────────────────┐
│     AMuleECBridgeAdapter                │  ← Bridge Protocol
│     (Platform Integration Layer)        │
├─────────────────────────────────────────┤
│     AMuleECClient                       │  ← Session Management
│     (Session, Connection, Operations)   │
├─────────────────────────────────────────┤
│     AMuleECProtocol                     │  ← Binary Protocol
│     (Packet, Tag, Compression, Auth)    │
└─────────────────────────────────────────┘
```

### Layers Explained

1. **AMuleECProtocol**: Low-level binary protocol implementation
   - Packet encoding/decoding
   - Tag serialization
   - MD5 authentication
   - Zlib compression

2. **AMuleECClient**: High-level client implementation
   - Session management with state machine
   - Connection handling via Network.framework
   - Operation builders for all EC commands
   - Response parsing

3. **AMuleECBridgeAdapter**: Platform integration
   - BridgeProtocol conformance
   - JSON envelope generation
   - Unified API for macOS/iOS apps

## Usage

### Basic Connection

```swift
import AMuleECClient

let config = ECSession.Configuration(
    host: "127.0.0.1",
    port: 4712,
    password: "your-password"
)

let session = ECSession(configuration: config)
try await session.connectAndAuthenticate()
```

### Get Server Status

```swift
let statusPacket = try await session.send(ECOperations.status())
let status = try ECResponseParser.parseStatus(statusPacket)
print("Download speed: \(status.downloadSpeed) bytes/s")
print("Upload speed: \(status.uploadSpeed) bytes/s")
```

### List Downloads

```swift
let downloadsPacket = try await session.send(ECOperations.downloads())
let downloads = try ECResponseParser.parseDownloads(downloadsPacket)
for download in downloads {
    print("\(download.name) - \(download.progress)%")
}
```

### Search for Files

```swift
// Start search
_ = try await session.send(ECOperations.search(scope: "kad", query: "example"))

// Poll for results
var progress = 0
var results: [ECSearchResult] = []

repeat {
    try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
    progress = try ECResponseParser.parseSearchProgress(
        try await session.send(ECOperations.searchProgress())
    )
    let newResults = try ECResponseParser.parseSearchResults(
        try await session.send(ECOperations.searchResults())
    )
    results.append(contentsOf: newResults)
} while progress < 100
```

### Pause a Download

```swift
try await session.send(ECOperations.pause(hash: "a1b2c3d4..."))
```

### Using the Bridge Adapter

For applications using the BridgeProtocol interface:

```swift
import AMuleECBridgeAdapter

let adapter = SwiftECBridgeAdapter()
let config = AMuleConnectionConfig(
    host: "127.0.0.1",
    port: 4712,
    password: "your-password"
)

// Get capabilities
let (_, caps, _) = try await adapter.capabilities(config: config)
print("Supported operations: \(caps.ops)")

// Get status
let (status, _) = try await adapter.status(config: config)
print("Connected: \(status.connected)")

// Search with polling built-in
let (progress, results, _) = try await adapter.search(
    scope: "kad",
    query: "search term",
    polls: 20,
    pollIntervalMs: 500,
    config: config
)
```

## Supported Operations

SwiftEC implements 23 EC protocol operations:

| Operation | Description | Category |
|-----------|-------------|----------|
| `capabilities` | Get bridge capabilities | Info |
| `status` | Get connection status | Info |
| `downloads` | List active downloads | Read |
| `sources` | Get download sources | Read |
| `servers` | List configured servers | Read |
| `search` | Start file search | Action |
| `searchStop` | Stop active search | Action |
| `download` | Download search result | Action |
| `addLink` | Add ED2K link | Action |
| `pause` | Pause download | Action |
| `resume` | Resume download | Action |
| `connect` | Connect to networks | Network |
| `disconnect` | Disconnect from networks | Network |
| `serverConnect` | Connect to specific server | Network |
| `serverDisconnect` | Disconnect from server | Network |
| `serverAdd` | Add server to list | Management |
| `serverRemove` | Remove server from list | Management |
| `prefsConnectionGet` | Get connection preferences | Prefs |
| `prefsConnectionSet` | Set connection preferences | Prefs |

## Data Models

All models are Codable, Equatable, and Sendable:

- `ECCapabilities`: Bridge capability advertisement
- `ECStatus`: Connection and transfer status
- `ECDownload`: Download file information
- `ECSource`: Download source details
- `ECServer`: Server configuration
- `ECSearchResult`: File search result
- `ECConnectionPrefs`: Connection speed limits

## Error Handling

SwiftEC provides detailed error types:

```swift
do {
    try await session.connect()
} catch ECSessionError.connectionFailed(let reason) {
    print("Connection failed: \(reason)")
} catch ECSessionError.authenticationFailed(let reason) {
    print("Authentication failed: \(reason)")
} catch ECResponseParserError.downloadNotFound(let hash) {
    print("Download not found: \(hash)")
}
```

## Thread Safety

All public APIs are Sendable-safe:

- `ECSession` is an actor - all mutable state is isolated
- All models conform to `Sendable`
- All error types conform to `Sendable`
- Safe to use from multiple concurrent contexts

## Testing

Run the test suite:

```bash
cd native-macos/AMuleNativeRemote/SwiftEC
swift test
```

Tests are organized by module:

- `AMuleECProtocolTests`: Binary protocol, tags, packets, compression
- `AMuleECClientTests`: Session, connection, operations
- `AMuleECBridgeAdapterTests`: Adapter layer integration

### Integration Tests

To run tests against a real aMule daemon:

```bash
export AMULE_EC_HOST=127.0.0.1
export AMULE_EC_PORT=4712
export AMULE_EC_PASSWORD=your-password
swift test
```

Tests requiring a real daemon are automatically skipped if these variables are not set.

## Documentation

- [Architecture](Docs/Architecture.md) - Detailed architecture overview
- [Operations](Docs/Operations.md) - Complete operation reference
- [SwiftECV1Contract](Docs/SwiftECV1Contract.md) - Protocol contract specification

## Dependencies

SwiftEC uses only Apple platform frameworks:

- **Network.framework**: TCP transport (required)
- **CryptoKit.Insecure.MD5**: Legacy authentication (required)
- **Compression**: Zlib compression (required)
- **Foundation**: Core types (required)

No third-party dependencies are used.

## Platform Notes

### macOS

- Minimum deployment: macOS 27
- Optimal for native macOS aMule remote applications
- Can replace process-based bridge adapters

### iOS

- Minimum deployment: iOS 27
- Designed for iOS remote control applications
- No external binary dependencies

## License

SwiftEC is part of the aMule project and follows the same license terms.

## Contributing

When contributing to SwiftEC:

1. Maintain Sendable conformance for all public types
2. Follow the three-layer architecture
3. Add tests for new functionality
4. Update documentation for API changes
5. Ensure no TODO/FIXME items remain in production code

## See Also

- [aMule Project](https://github.com/amule-project/amule)
- [EC Protocol Documentation](Docs/SwiftECV1Contract.md)
