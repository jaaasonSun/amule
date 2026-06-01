// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AMuleNativeRemote",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "AMuleNativeRemote", targets: ["AMuleNativeRemote"])
    ],
    dependencies: [
        .package(path: "SharedUI"),
        .package(path: "SwiftEC"),
        .package(path: "SharedCore")
    ],
    targets: [
        .executableTarget(
            name: "AMuleNativeRemote",
            dependencies: [
                "SharedUI",
                .product(name: "AMuleECClient", package: "SwiftEC"),
                .product(name: "AMuleECBridgeAdapter", package: "SwiftEC"),
                .product(name: "SharedCore", package: "SharedCore")
            ]
        ),
        .testTarget(
            name: "AMuleNativeRemoteTests",
            dependencies: ["AMuleNativeRemote"],
            path: "Tests/AMuleNativeRemoteTests"
        ),
    ]
)
