// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SwiftEC",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
    ],
    products: [
        .library(name: "AMuleECProtocol", targets: ["AMuleECProtocol"]),
        .library(name: "AMuleECClient", targets: ["AMuleECClient", "AMuleECProtocol"]),
        .library(name: "AMuleECBridgeAdapter", targets: ["AMuleECBridgeAdapter", "AMuleECClient", "AMuleECProtocol"]),
    ],
    targets: [
        .target(
            name: "AMuleECProtocol",
            path: "Sources/AMuleECProtocol"
        ),
        .target(
            name: "AMuleECClient",
            dependencies: ["AMuleECProtocol"],
            path: "Sources/AMuleECClient"
        ),
        .target(
            name: "AMuleECBridgeAdapter",
            dependencies: ["AMuleECClient", "AMuleECProtocol"],
            path: "Sources/AMuleECBridgeAdapter"
        ),
        .testTarget(
            name: "AMuleECProtocolTests",
            dependencies: ["AMuleECProtocol", "Fixtures"],
            path: "Tests/AMuleECProtocolTests"
        ),
        .target(
            name: "Fixtures",
            dependencies: ["AMuleECProtocol"],
            path: "Tests/Fixtures",
            sources: [
                "ECTagFixtures.swift",
                "ECAuthFixtures.swift",
                "ECJsonEnvelopeFixtures.swift",
                "ECPacketHeaderFixtures.swift",
                "ECDownloadPacketFixtures.swift",
            ]
        ),
        .testTarget(
            name: "AMuleECClientTests",
            dependencies: ["AMuleECClient", "Fixtures"],
            path: "Tests/AMuleECClientTests"
        ),
        .testTarget(
            name: "AMuleECBridgeAdapterTests",
            dependencies: ["AMuleECBridgeAdapter", "Fixtures"],
            path: "Tests/AMuleECBridgeAdapterTests"
        ),
    ]
)
