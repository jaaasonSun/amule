// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SharedCore",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(name: "SharedCore", targets: ["SharedCore"])
    ],
    dependencies: [
        .package(path: "../SwiftEC")
    ],
    targets: [
        .target(
            name: "SharedCore",
            dependencies: [
                .product(name: "AMuleECClient", package: "SwiftEC"),
                .product(name: "AMuleECBridgeAdapter", package: "SwiftEC")
            ]
        )
    ]
)
