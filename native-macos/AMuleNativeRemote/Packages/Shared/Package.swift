// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Shared",
    platforms: [
        .macOS("27.0"),
        .iOS("27.0")
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
                .product(name: "AMuleECProtocol", package: "SwiftEC"),
                .product(name: "AMuleECClient", package: "SwiftEC"),
                .product(name: "AMuleECBridgeAdapter", package: "SwiftEC")
            ],
            path: "Sources/SharedModels"
        ),
        .target(
            name: "SharedViews",
            dependencies: ["SharedModels"],
            path: "Sources/SharedViews"
        ),
        .target(
            name: "SharedServices",
            dependencies: [
                .product(name: "AMuleECBridgeAdapter", package: "SwiftEC")
            ],
            path: "Sources/SharedServices"
        ),
        .testTarget(
            name: "SharedViewsTests",
            dependencies: ["SharedViews", "SharedModels"],
            path: "Tests/SharedViewsTests"
        )
    ]
)
