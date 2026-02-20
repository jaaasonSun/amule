import Foundation

struct AMuleConnectionConfig {
    var bridgePath: String
    var host: String
    var port: Int
    var password: String

    static let legacyFallbackBridgePath = "/path/to/amule/build/src/amule-ec-bridge"

    static var bundledBridgePath: String? {
        let fm = FileManager.default
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

        return nil
    }

    static func preferredDefaultPath() -> String {
        let fm = FileManager.default
        if let bundled = bundledBridgePath {
            return bundled
        }

        let candidates = [
            legacyFallbackBridgePath,
            "/opt/homebrew/bin/amule-ec-bridge",
            "/usr/local/bin/amule-ec-bridge"
        ]

        for candidate in candidates where fm.isExecutableFile(atPath: candidate) {
            return candidate
        }

        return legacyFallbackBridgePath
    }
}

enum AMuleClientError: LocalizedError {
    case missingBridge(String)
    case processFailure(Int32, String)
    case invalidResponse(String)
    case bridgeFailure(String)

    var errorDescription: String? {
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

struct BridgeStatusPayload: Decodable {
    let connected: Bool
    let ed2k: String
    let kad: String
    let downloadSpeed: Int
    let uploadSpeed: Int
    let queue: Int
    let sources: Int

    private enum CodingKeys: String, CodingKey {
        case connected
        case ed2k
        case kad
        case downloadSpeed = "download_speed"
        case uploadSpeed = "upload_speed"
        case queue
        case sources
    }
}

struct BridgeDownloadPayload: Decodable {
    let hash: String
    let name: String
    let progress: Double
    let sourcesCurrent: Int
    let sourcesTotal: Int
    let status: String
    let speed: Int
    let priority: Int

    private enum CodingKeys: String, CodingKey {
        case hash
        case name
        case progress
        case sourcesCurrent = "sources_current"
        case sourcesTotal = "sources_total"
        case status
        case speed
        case priority
    }
}

struct BridgeSearchPayload: Decodable {
    let id: Int
    let hash: String
    let name: String
    let size: UInt64
    let sources: Int
    let alreadyHave: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case hash
        case name
        case size
        case sources
        case alreadyHave = "already_have"
    }
}

private struct BridgeEnvelope: Decodable {
    let ok: Bool
    let error: String?
    let message: String?
    let status: BridgeStatusPayload?
    let downloads: [BridgeDownloadPayload]?
    let progress: Int?
    let results: [BridgeSearchPayload]?
}

enum AMuleECBridgeClient {
    static func connect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(op: "connect", extraArgs: [], config: config)
        return (envelope.message ?? "Connect requested", raw)
    }

    static func disconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(op: "disconnect", extraArgs: [], config: config)
        return (envelope.message ?? "Disconnect requested", raw)
    }

    static func status(config: AMuleConnectionConfig) async throws -> (BridgeStatusPayload, String) {
        let (envelope, raw) = try await invoke(op: "status", extraArgs: [], config: config)
        guard let status = envelope.status else {
            throw AMuleClientError.invalidResponse(raw)
        }
        return (status, raw)
    }

    static func downloads(config: AMuleConnectionConfig) async throws -> ([BridgeDownloadPayload], String) {
        let (envelope, raw) = try await invoke(op: "downloads", extraArgs: [], config: config)
        return (envelope.downloads ?? [], raw)
    }

    static func search(
        scope: String,
        query: String,
        polls: Int,
        pollIntervalMs: Int,
        config: AMuleConnectionConfig
    ) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String) {
        let extra = [
            "--scope", scope,
            "--query", query,
            "--polls", String(max(1, polls)),
            "--poll-interval-ms", String(max(100, pollIntervalMs))
        ]
        let (envelope, raw) = try await invoke(op: "search", extraArgs: extra, config: config)
        return (envelope.progress ?? 0, envelope.results ?? [], raw)
    }

    static func download(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(op: "download", extraArgs: ["--hash", hash], config: config)
        return (envelope.message ?? "Download request accepted", raw)
    }

    static func pause(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(op: "pause", extraArgs: ["--hash", hash], config: config)
        return (envelope.message ?? "Pause requested", raw)
    }

    static func resume(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(op: "resume", extraArgs: ["--hash", hash], config: config)
        return (envelope.message ?? "Resume requested", raw)
    }

    static func cancel(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(op: "cancel", extraArgs: ["--hash", hash], config: config)
        return (envelope.message ?? "Cancel requested", raw)
    }

    static func priority(hash: String, value: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(
            op: "priority",
            extraArgs: ["--hash", hash, "--priority", value],
            config: config
        )
        return (envelope.message ?? "Priority changed", raw)
    }

    private static func invoke(
        op: String,
        extraArgs: [String],
        config: AMuleConnectionConfig
    ) async throws -> (BridgeEnvelope, String) {
        let arguments = [
            "--host", config.host,
            "--port", String(config.port),
            "--password", config.password,
            "--op", op
        ] + extraArgs

        let result = try await run(arguments: arguments, bridgePath: config.bridgePath)
        let envelope: BridgeEnvelope

        do {
            envelope = try parseEnvelope(from: result.output)
        } catch {
            if result.status != 0 {
                throw AMuleClientError.processFailure(result.status, result.output)
            }
            throw error
        }

        if !envelope.ok {
            throw AMuleClientError.bridgeFailure(envelope.error ?? "Bridge request failed")
        }

        if result.status != 0 {
            throw AMuleClientError.processFailure(result.status, result.output)
        }

        return (envelope, result.output)
    }

    private struct ProcessResult {
        let status: Int32
        let output: String
    }

    private static func run(arguments: [String], bridgePath: String) async throws -> ProcessResult {
        guard let executablePath = resolveExecutablePath(bridgePath) else {
            throw AMuleClientError.missingBridge(bridgePath)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.environment = utf8ProcessEnvironment()

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            process.terminationHandler = { process in
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let text = String(decoding: data, as: UTF8.self)
                continuation.resume(returning: ProcessResult(status: process.terminationStatus, output: text))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func parseEnvelope(from output: String) throws -> BridgeEnvelope {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        var candidates: [String] = []

        if !trimmed.isEmpty {
            candidates.append(trimmed)
        }

        let lines = output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        candidates.append(contentsOf: lines.reversed())

        let decoder = JSONDecoder()
        for candidate in candidates {
            if let data = candidate.data(using: .utf8),
               let envelope = try? decoder.decode(BridgeEnvelope.self, from: data) {
                return envelope
            }
        }

        throw AMuleClientError.invalidResponse(output)
    }

    private static func resolveExecutablePath(_ bridgePath: String) -> String? {
        let fm = FileManager.default
        let expanded = (bridgePath as NSString).expandingTildeInPath

        if expanded.contains("/") {
            return fm.isExecutableFile(atPath: expanded) ? expanded : nil
        }

        let envPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for dir in envPath.split(separator: ":") {
            let fullPath = String(dir) + "/" + expanded
            if fm.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }

        return nil
    }

    private static func utf8ProcessEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        if env["LANG"]?.localizedCaseInsensitiveContains("UTF-8") != true {
            env["LANG"] = "en_US.UTF-8"
        }
        if env["LC_ALL"]?.localizedCaseInsensitiveContains("UTF-8") != true {
            env["LC_ALL"] = "en_US.UTF-8"
        }
        env["LC_CTYPE"] = "UTF-8"
        return env
    }
}
