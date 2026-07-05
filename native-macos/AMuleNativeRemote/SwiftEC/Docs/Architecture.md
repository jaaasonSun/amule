# SwiftEC Architecture

## Overview

SwiftEC implements the aMule External Connections (EC) protocol in pure Swift. The architecture follows a three-layer design that separates concerns and enables platform-specific integration while sharing core protocol implementation.

## Three-Layer Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     APPLICATION LAYER                            │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  AMuleECBridgeAdapter (BridgeProtocol Conformance)      │    │
│  │  • SwiftECBridgeAdapter.swift                           │    │
│  │  • BridgeAdapterFactory.swift                           │    │
│  │  • Platform-specific integration                        │    │
│  └─────────────────────────────────────────────────────────┘    │
├─────────────────────────────────────────────────────────────────┤
│                     CLIENT LAYER                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  AMuleECClient (High-Level EC Operations)               │    │
│  │  • ECSession.swift         - Session management         │    │
│  │  • ECConnection.swift      - Network transport          │    │
│  │  • ECRequestPipeline.swift - Request queuing            │    │
│  │  • ECOperations.swift      - Operation builders         │    │
│  │  • ECResponseParser.swift  - Response parsing           │    │
│  │  • ECJSONEnvelope.swift    - JSON output formatting     │    │
│  │  • ECModels.swift          - Data models                │    │
│  └─────────────────────────────────────────────────────────┘    │
├─────────────────────────────────────────────────────────────────┤
│                     PROTOCOL LAYER                               │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  AMuleECProtocol (Binary EC Protocol)                   │    │
│  │  • ECPacket.swift          - Packet encoding/decoding   │    │
│  │  • ECPacketHeader.swift    - 8-byte header format       │    │
│  │  • ECTag.swift             - Tag serialization          │    │
│  │  • ECCompression.swift     - Zlib compression           │    │
│  │  • ECAuthPacket.swift      - Auth packet builders       │    │
│  │  • ECLegacyAuth.swift      - MD5 authentication         │    │
│  │  • ECSupportedOps.swift    - Operation codes            │    │
│  │  • ECProtocolError.swift   - Protocol errors            │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## Layer Responsibilities

### 1. Protocol Layer (AMuleECProtocol)

The foundation layer handles raw binary protocol communication.

**Key Components:**

- **ECPacket**: Complete packet with header + body
  - Encoding/decoding to/from Data
  - Opcode and tag management
  - Compression support

- **ECPacketHeader**: 8-byte wire format
  - 4-byte flags (little-endian)
  - 4-byte body length (little-endian)

- **ECTag**: Protocol tag structure
  - Name (2 bytes)
  - Type (1 byte)
  - Length (4 bytes)
  - Value (variable)
  - Children (nested tags)

- **ECCompression**: Zlib compression
  - Uses Apple Compression framework
  - Automatic compression for large payloads
  - Threshold: 1024 bytes

- **ECLegacyAuth**: MD5 password authentication
  - Salt exchange
  - Password hashing
  - Response parsing

**Design Decisions:**
- Pure value types (structs) for immutability
- No external dependencies
- Extensive use of Data for binary operations

### 2. Client Layer (AMuleECClient)

The middle layer provides high-level Swift APIs for EC operations.

**Key Components:**

- **ECSession**: Connection state machine
  - Actor-based for thread safety
  - States: disconnected → connecting → connected → authenticating → authenticated
  - Automatic reconnection with exponential backoff
  - Request queuing support

- **ECConnection**: Network transport
  - Network.framework implementation
  - Async/await API
  - Timeout handling
  - Cancellation support

- **ECRequestPipeline**: Request management
  - Queues multiple requests
  - Single-flight requests
  - Timeout enforcement

- **ECOperations**: Operation builders
  - Type-safe operation creation
  - Capability gating
  - All 23 EC operations supported

- **ECResponseParser**: Response interpretation
  - Tag-to-model mapping
  - Error detection
  - Status code translation

- **ECJSONEnvelope**: Output formatting
  - JSON envelope generation
  - Consistent response format
  - Schema versioning

**Design Decisions:**
- Actors for mutable state (ECSession, ECConnection, ECRequestPipeline)
- Value types for data (ECStatus, ECDownload, etc.)
- Async/await throughout
- Comprehensive error types

### 3. Bridge Adapter Layer (AMuleECBridgeAdapter)

The top layer integrates with existing aMule applications.

**Key Components:**

- **SwiftECBridgeAdapter**: BridgeProtocol implementation
  - Wraps ECSession
  - Provides BridgeProtocol API
  - JSON envelope output
  - Operation orchestration

- **BridgeProtocol**: Interface definition
  - Platform-agnostic protocol
  - Used by macOS and iOS apps
  - Consistent API across platforms

**Design Decisions:**
- Protocol-based for testability
- Sendable conformance for Swift 6
- Optional session injection for testing

## Data Flow

### Typical Request Flow

```
1. Application calls adapter method
   ↓
2. Adapter creates/uses ECSession
   ↓
3. ECSession ensures connection (ECConnection)
   ↓
4. ECOperations builds ECPacket
   ↓
5. ECRequestPipeline sends packet
   ↓
6. ECConnection writes to Network.framework
   ↓
7. AMuleECProtocol encodes binary data
   ↓
8. Network sends to aMule daemon
   ↓
9. Response received
   ↓
10. AMuleECProtocol decodes packet
    ↓
11. ECResponseParser extracts data
    ↓
12. ECJSONEnvelope formats output
    ↓
13. Adapter returns to application
```

### Session State Machine

```
                    connect()
    ┌───────────────┐
    │               ▼
disconnected ──► connecting
    ▲               │
    │               ▼
    │           connected
    │               │
    │               │ authenticate()
    │               ▼
    │          authenticating
    │               │
    │               ▼
    └─────────► authenticated
      disconnect()
```

## Thread Safety Model

### Actors (Mutable State)

All classes with mutable state are Swift actors:

- **ECSession**: Connection state, transport reference
- **ECConnection**: NWConnection, connection state
- **ECRequestPipeline**: Queue, in-progress flag

### Sendable Types (Immutable Data)

All data models and errors are Sendable:

- **Models**: ECCapabilities, ECStatus, ECDownload, ECSource, ECServer, ECSearchResult, ECConnectionPrefs
- **Errors**: All error enums conform to LocalizedError and Sendable
- **Value Types**: ECPacket, ECTag, ECPacketHeader

### Why Actors?

1. **Compiler Enforcement**: Swift 6 prevents data races at compile time
2. **Clear Semantics**: Actor isolation makes thread safety explicit
3. **Performance**: No locks needed for data access
4. **Cancellation**: Built-in support for cooperative cancellation

## Network Architecture

### Transport Layer

Uses Apple's Network.framework:

```swift
NWConnection(host:port:using:)
```

Benefits:
- Native integration with iOS/macOS networking
- Automatic IPv4/IPv6 support
- Built-in TLS support (future)
- Proper lifecycle management

### Connection Handling

- **Connection Pooling**: Single connection per session
- **Reconnection**: Exponential backoff (1s → 2s → 4s... max 30s)
- **Timeouts**: Configurable per operation type
- **Cancellation**: Full cancellation support via Task

## Memory Model

### Ownership

- **Value Types**: Most types are structs (copy-on-write)
- **Actors**: Own their mutable state
- **References**: Minimal use of classes, primarily for actors

### Lifetime

- **ECSession**: Long-lived, application-managed
- **ECConnection**: Session-managed, recreated on reconnect
- **ECPacket**: Short-lived, created per request

## Extension Points

### Adding New Operations

1. Add opcode to `ECOperations.OpCode`
2. Add tag names to `ECOperations.TagName`
3. Create builder method in `ECOperations`
4. Add parser support in `ECResponseParser`
5. Add to `ECOperationName` enum
6. Expose in `BridgeProtocol`
7. Implement in `SwiftECBridgeAdapter`

### Custom Transports

Implement `ECConnectionTransport`:

```swift
public protocol ECConnectionTransport: Sendable {
    func connect(timeout: TimeInterval) async throws
    func disconnect() async
    func send(_ packet: ECPacket, timeout: TimeInterval) async throws
    func receivePacket(timeout: TimeInterval, partialReadTimeout: TimeInterval) async throws -> ECPacket
}
```

Useful for:
- Mocking in tests
- Proxy connections
- Custom network stacks

## Platform Considerations

### macOS

- Full feature support
- Native SwiftEC app integration
- Feature flags expose daemon/app capability availability

### iOS

- No external binary dependencies
- Sandboxed-friendly
- Optimized for mobile use cases

## Testing Architecture

### Unit Tests

- Test individual components in isolation
- Use fixture data for binary packets
- Mock transport for connection tests

### Integration Tests

- Test against real aMule daemon
- Environment-variable gated
- Validate end-to-end flows

### Test Organization

```
Tests/
├── AMuleECProtocolTests/  - Protocol layer
├── AMuleECClientTests/    - Client layer
├── AMuleECBridgeAdapterTests/ - Adapter layer
└── Fixtures/              - Shared test data
```

## Future Considerations

### Potential Enhancements

1. **TLS Support**: Encrypted connections via NWParameters
2. **WebSocket Transport**: Browser-based clients
3. **Connection Pooling**: Multiple concurrent sessions
4. **Metrics**: Built-in telemetry
5. **Caching**: Response caching for read operations

### Swift Evolution

- **Typed Throws**: When available, add to error types
- **Global Actors**: Consider for singleton patterns
- **Macros**: Potential for operation definition
