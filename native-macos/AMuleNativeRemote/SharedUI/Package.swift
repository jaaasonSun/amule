// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SharedUI",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(name: "SharedUI", targets: ["SharedUI"])
    ],
    targets: [
        .target(
            name: "SharedUI",
            path: "Sources/SharedUI"
        ),
        .testTarget(
            name: "SharedUITests",
            dependencies: ["SharedUI"],
            path: "Tests/SharedUITests"
        )
    ]
)