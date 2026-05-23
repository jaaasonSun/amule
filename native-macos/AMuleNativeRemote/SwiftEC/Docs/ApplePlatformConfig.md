# Apple Platform Configuration

SwiftEC is a pure-Swift EC client package for Apple platforms. It must remain free of C++, wxWidgets, Crypto++, OpenSSL, Boost, and other external/native bridge dependencies.

## Supported platforms

`Network.framework` TCP APIs such as `NWConnection` require:

- macOS 10.14 or newer
- iOS 12.0 or newer

The package manifest declares these minimums with SwiftPM platform guards. Any public API that imports or exposes `Network.framework` types must be annotated:

```swift
@available(macOS 10.14, iOS 12.0, *)
public func connect(...) async throws { ... }
```

Keep this annotation on public Network-backed clients, transports, adapters, and factory methods so downstream apps get compile-time availability checks.

## iOS local network privacy

iOS apps that use SwiftEC to connect to an aMule daemon on the LAN must include a local network usage string in the app target's `Info.plist`:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>aMule Remote needs local network access to connect to your aMule daemon on your LAN.</string>
```

If the app adds Bonjour discovery later, also include `NSBonjourServices` entries for the advertised service types. SwiftEC currently documents TCP connection requirements only and does not require Bonjour service declarations by itself.

Example Bonjour shape if discovery is introduced:

```xml
<key>NSBonjourServices</key>
<array>
    <string>_amule-ec._tcp</string>
</array>
```

Do not add entitlements from the SwiftEC package. App targets own their privacy strings, App Sandbox choices, and network entitlements.

## App Transport Security

For local, non-HTTP TCP connections through `Network.framework`, ATS is not a SwiftEC package setting. Existing iOS app targets may include `NSAllowsLocalNetworking` when their broader networking stack needs it, but SwiftEC itself does not modify app `Info.plist` files.

## Dependency guardrails

SwiftEC allows Apple system frameworks only:

- Foundation
- Network.framework
- CryptoKit for EC-compatible legacy MD5 hashing
- Compression for zlib-compatible packet compression

Forbidden dependencies include:

- OpenSSL
- Crypto++ / cryptopp
- wxWidgets / wx
- Boost
- C++ runtime usage from SwiftEC package sources

Run the dependency scanner before release:

```bash
SwiftEC/Scripts/check-forbidden-deps.sh
```

The script scans SwiftEC package sources and manifest files for forbidden imports, linker flags, include paths, and package references.
