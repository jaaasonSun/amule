import Foundation

struct AMuleConnectionConfig {
    var bridgePath: String
    var host: String
    var port: Int
    var password: String

    static let fallbackBridgeCommand = "amule-ec-bridge"

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

        return fallbackBridgeCommand
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
    struct AlternativeName: Decodable {
        let name: String
        let count: Int
    }

    let ecid: Int
    let hash: String
    let name: String
    let size: UInt64
    let done: UInt64
    let transferred: UInt64
    let progress: Double
    let sourcesCurrent: Int
    let sourcesTotal: Int
    let sourcesTransferring: Int
    let sourcesA4AF: Int
    let statusCode: Int
    let isCompleted: Bool
    let status: String
    let speed: Int
    let priority: Int
    let category: Int
    let partMet: String
    let lastSeenComplete: UInt64
    let lastReceived: UInt64
    let activeSeconds: Int
    let availableParts: Int
    let shared: Bool
    let alternativeNames: [AlternativeName]
    let progressColors: [UInt32]?

    private enum CodingKeys: String, CodingKey {
        case ecid
        case hash
        case name
        case size
        case done
        case transferred
        case progress
        case sourcesCurrent = "sources_current"
        case sourcesTotal = "sources_total"
        case sourcesTransferring = "sources_transferring"
        case sourcesA4AF = "sources_a4af"
        case statusCode = "status_code"
        case isCompleted = "is_completed"
        case status
        case speed
        case priority
        case category
        case partMet = "part_met"
        case lastSeenComplete = "last_seen_complete"
        case lastReceived = "last_received"
        case activeSeconds = "active_seconds"
        case availableParts = "available_parts"
        case shared
        case alternativeNames = "alternative_names"
        case progressColors = "progress_colors"
    }
}

struct BridgeDownloadSourcePayload: Decodable {
    let clientID: Int
    let requestFileID: Int
    let clientName: String
    let userIP: String
    let userPort: Int
    let serverName: String
    let serverIP: String
    let serverPort: Int
    let software: String
    let softwareVersion: String
    let downloadState: Int
    let downloadStateText: String
    let sourceFrom: Int
    let sourceFromText: String
    let downSpeedKBps: Double
    let availableParts: Int
    let remoteQueueRank: Int
    let obfuscationStatus: Int
    let extendedProtocol: Bool
    let remoteFilename: String

    private enum CodingKeys: String, CodingKey {
        case clientID = "client_id"
        case requestFileID = "request_file_id"
        case clientName = "client_name"
        case userIP = "user_ip"
        case userPort = "user_port"
        case serverName = "server_name"
        case serverIP = "server_ip"
        case serverPort = "server_port"
        case software
        case softwareVersion = "software_version"
        case downloadState = "download_state"
        case downloadStateText = "download_state_text"
        case sourceFrom = "source_from"
        case sourceFromText = "source_from_text"
        case downSpeedKBps = "down_speed_kbps"
        case availableParts = "available_parts"
        case remoteQueueRank = "remote_queue_rank"
        case obfuscationStatus = "obfuscation_status"
        case extendedProtocol = "extended_protocol"
        case remoteFilename = "remote_filename"
    }
}

struct BridgeSearchPayload: Decodable {
    let id: Int
    let hash: String
    let name: String
    let size: UInt64
    let sources: Int
    let completeSources: Int
    let statusCode: Int
    let status: String
    let parentID: Int
    let alreadyHave: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case hash
        case name
        case size
        case sources
        case completeSources = "complete_sources"
        case statusCode = "status_code"
        case status
        case parentID = "parent_id"
        case alreadyHave = "already_have"
    }
}

struct BridgeServerPayload: Decodable {
    let id: Int
    let name: String
    let description: String
    let version: String
    let address: String
    let ip: String
    let port: Int
    let users: Int
    let maxUsers: Int
    let files: Int
    let ping: Int
    let failed: Int
    let priority: Int
    let isStatic: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case version
        case address
        case ip
        case port
        case users
        case maxUsers = "max_users"
        case files
        case ping
        case failed
        case priority
        case isStatic = "is_static"
    }
}

private struct BridgeEnvelope: Decodable {
    let ok: Bool
    let error: String?
    let message: String?
    let status: BridgeStatusPayload?
    let downloads: [BridgeDownloadPayload]?
    let sources: [BridgeDownloadSourcePayload]?
    let servers: [BridgeServerPayload]?
    let progress: Int?
    let results: [BridgeSearchPayload]?
}

enum AMuleECBridgeClient {
    private final class ThreadSafeDataBuffer: @unchecked Sendable {
        private let lock = NSLock()
        private var value = Data()

        func append(_ data: Data) {
            lock.lock()
            value.append(data)
            lock.unlock()
        }

        func snapshot() -> Data {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
    }

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

    static func sources(hash: String, config: AMuleConnectionConfig) async throws -> ([BridgeDownloadSourcePayload], String) {
        let (envelope, raw) = try await invoke(op: "sources", extraArgs: ["--hash", hash], config: config)
        return (envelope.sources ?? [], raw)
    }

    static func servers(config: AMuleConnectionConfig) async throws -> ([BridgeServerPayload], String) {
        let (envelope, raw) = try await invoke(op: "servers", extraArgs: [], config: config)
        return (envelope.servers ?? [], raw)
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

    static func searchStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(op: "search-stop", extraArgs: [], config: config)
        return (envelope.message ?? "Search stop requested", raw)
    }

    static func download(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(op: "download", extraArgs: ["--hash", hash], config: config)
        return (envelope.message ?? "Download request accepted", raw)
    }

    static func addLink(link: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(op: "add-link", extraArgs: ["--link", link], config: config)
        return (envelope.message ?? "Link add request accepted", raw)
    }

    static func rename(hash: String, name: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(
            op: "rename",
            extraArgs: ["--hash", hash, "--name", name],
            config: config
        )
        return (envelope.message ?? "Rename requested", raw)
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

    static func clearCompleted(ecids: [Int], config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        var extraArgs: [String] = []
        for ecid in ecids where ecid > 0 {
            extraArgs.append(contentsOf: ["--ecid", String(ecid)])
        }
        let (envelope, raw) = try await invoke(op: "clear-completed", extraArgs: extraArgs, config: config)
        return (envelope.message ?? "Completed downloads cleared", raw)
    }

    static func serverConnect(ip: String?, port: Int?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        var extraArgs: [String] = []
        if let ip, !ip.isEmpty, let port {
            extraArgs = ["--server-ip", ip, "--server-port", String(port)]
        }
        let (envelope, raw) = try await invoke(op: "server-connect", extraArgs: extraArgs, config: config)
        return (envelope.message ?? "Server connect requested", raw)
    }

    static func serverDisconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(op: "server-disconnect", extraArgs: [], config: config)
        return (envelope.message ?? "Server disconnect requested", raw)
    }

    static func serverAdd(address: String, name: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        var extraArgs: [String] = ["--server-address", address]
        if let name, !name.isEmpty {
            extraArgs += ["--server-name", name]
        }
        let (envelope, raw) = try await invoke(op: "server-add", extraArgs: extraArgs, config: config)
        return (envelope.message ?? "Server add requested", raw)
    }

    static func serverRemove(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(
            op: "server-remove",
            extraArgs: ["--server-ip", ip, "--server-port", String(port)],
            config: config
        )
        return (envelope.message ?? "Server remove requested", raw)
    }

    static func serverUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(
            op: "server-update-from-url",
            extraArgs: ["--server-url", url],
            config: config
        )
        return (envelope.message ?? "Server list update requested", raw)
    }

    static func kadUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(
            op: "kad-update-from-url",
            extraArgs: ["--kad-url", url],
            config: config
        )
        return (envelope.message ?? "Kad nodes update requested", raw)
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

            let collected = ThreadSafeDataBuffer()
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                collected.append(data)
            }

            process.terminationHandler = { process in
                outputPipe.fileHandleForReading.readabilityHandler = nil
                let tail = outputPipe.fileHandleForReading.readDataToEndOfFile()
                collected.append(tail)
                let data = collected.snapshot()
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
