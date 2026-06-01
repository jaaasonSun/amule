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
        .package(path: "Packages/Shared"),
        .package(path: "SwiftEC")
    ],
    targets: [
        .executableTarget(
            name: "AMuleNativeRemote",
            dependencies: [
                .product(name: "SharedViews", package: "Shared"),
                .product(name: "SharedModels", package: "Shared"),
                .product(name: "SharedServices", package: "Shared"),
                .product(name: "AMuleECClient", package: "SwiftEC"),
                .product(name: "AMuleECBridgeAdapter", package: "SwiftEC")
            ]
        ),
        .testTarget(
            name: "AMuleNativeRemoteTests",
            dependencies: ["AMuleNativeRemote"],
            path: "Tests/AMuleNativeRemoteTests"
        ),
    ]
)
