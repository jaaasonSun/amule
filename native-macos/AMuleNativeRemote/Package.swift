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
    targets: [
        .executableTarget(
            name: "AMuleNativeRemote"
        ),
        .testTarget(
            name: "AMuleNativeRemoteTests",
            dependencies: ["AMuleNativeRemote"],
            path: "Tests/AMuleNativeRemoteTests"
        )
    ]
)
