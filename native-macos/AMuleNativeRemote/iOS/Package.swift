// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AMuleRemoteiOSWrapper",
    platforms: [
        .iOS(.v26)
    ],
    products: [
        .executable(name: "AMuleRemoteiOSWrapper", targets: ["AMuleRemoteiOSWrapper"])
    ],
    targets: [
        .executableTarget(
            name: "AMuleRemoteiOSWrapper",
            path: "AMuleRemoteiOS"
        )
    ]
)
