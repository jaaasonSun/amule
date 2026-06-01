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
        .package(path: "../SharedUI"),
        .package(path: "../SharedCore")
    ],
    targets: [
        .target(
            name: "AMuleRemoteIOSShared",
            dependencies: [
                .product(name: "AMuleECClient", package: "SwiftEC"),
                .product(name: "AMuleECBridgeAdapter", package: "SwiftEC"),
                .product(name: "SharedUI", package: "SharedUI"),
                .product(name: "SharedCore", package: "SharedCore")
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
