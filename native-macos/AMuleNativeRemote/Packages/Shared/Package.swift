// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Shared",
    platforms: [
        .macOS(.v26),
        .iOS(.v26)
    ],
    products: [
        .library(name: "SharedModels", targets: ["SharedModels"]),
        .library(name: "SharedViews", targets: ["SharedViews"]),
        .library(name: "SharedServices", targets: ["SharedServices"])
    ],
    dependencies: [
        .package(path: "../../SwiftEC")
    ],
    targets: [
        .target(
            name: "SharedModels",
            dependencies: [
                .product(name: "AMuleECClient", package: "SwiftEC"),
                .product(name: "AMuleECBridgeAdapter", package: "SwiftEC")
            ],
            path: "Sources/SharedModels"
        ),
        .target(
            name: "SharedViews",
            path: "Sources/SharedViews"
        ),
        .target(
            name: "SharedServices",
            path: "Sources/SharedServices"
        ),
        .testTarget(
            name: "SharedViewsTests",
            dependencies: ["SharedViews"],
            path: "Tests/SharedViewsTests"
        )
    ]
)
