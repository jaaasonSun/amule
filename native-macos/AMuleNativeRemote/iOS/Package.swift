// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AMuleRemoteIOSShared",
    platforms: [
        .iOS(.v26),
        .macOS(.v13)
    ],
    products: [
        .library(name: "AMuleRemoteIOSShared", targets: ["AMuleRemoteIOSShared"])
    ],
    dependencies: [
        .package(path: "../SwiftEC"),
        .package(path: "../Packages/Shared")
    ],
    targets: [
        .target(
            name: "AMuleRemoteIOSShared",
            dependencies: [
                .product(name: "AMuleECClient", package: "SwiftEC"),
                .product(name: "AMuleECBridgeAdapter", package: "SwiftEC"),
                .product(name: "SharedViews", package: "Shared"),
                .product(name: "SharedModels", package: "Shared"),
                .product(name: "SharedServices", package: "Shared")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "AMuleRemoteIOSTests",
            dependencies: [
                "AMuleRemoteIOSShared",
                .product(name: "AMuleECClient", package: "SwiftEC")
            ],
            path: "Tests/AMuleRemoteIOSTests"
        )
    ]
)
