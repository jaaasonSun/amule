import Foundation

public struct AMuleConnectionConfig: Sendable {
    public var bridgePath: String
    public var host: String
    public var port: Int
    public var password: String

    public init(bridgePath: String, host: String, port: Int, password: String) {
        self.bridgePath = bridgePath
        self.host = host
        self.port = port
        self.password = password
    }

    public static let fallbackBridgeCommand = "amule-ec-bridge"

    public static var bundledBridgePath: String? {
        let fm = FileManager.default
        #if os(macOS)
        if let resource = Bundle.main.resourceURL?.appendingPathComponent("amule-ec-bridge").path,
           fm.isExecutableFile(atPath: resource) {
            return resource
        }

        let appBundlePath = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/amule-ec-bridge")
            .path
        if fm.isExecutableFile(atPath: appBundlePath) {
            return appBundlePath
        }
        #endif
        return nil
    }

    public static func preferredDefaultPath() -> String {
        let fm = FileManager.default
        if let bundled = bundledBridgePath {
            return bundled
        }

        #if os(macOS)
        let cwd = fm.currentDirectoryPath
        let candidates = [
            URL(fileURLWithPath: cwd)
                .appendingPathComponent("build/src/amule-ec-bridge")
                .path,
            URL(fileURLWithPath: cwd)
                .appendingPathComponent("../build/src/amule-ec-bridge")
                .standardized.path,
            URL(fileURLWithPath: cwd)
                .appendingPathComponent("../../build/src/amule-ec-bridge")
                .standardized.path,
            "/opt/homebrew/bin/amule-ec-bridge",
            "/usr/local/bin/amule-ec-bridge"
        ]

        for candidate in candidates where fm.isExecutableFile(atPath: candidate) {
            return candidate
        }
        #endif

        return fallbackBridgeCommand
    }
}

public enum AMuleClientError: LocalizedError {
    case missingBridge(String)
    case processFailure(Int32, String)
    case invalidResponse(String)
    case bridgeFailure(String)

    public var errorDescription: String? {
        switch self {
        case .missingBridge(let path):
            return "amule-ec-bridge not found at: \(path)"
        case .processFailure(let code, let output):
            return "amule-ec-bridge exited with code \(code).\n\(output)"
        case .invalidResponse(let output):
            return "Invalid bridge response.\n\(output)"
        case .bridgeFailure(let message):
            return message
        }
    }
}
