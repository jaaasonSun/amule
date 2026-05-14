import Foundation
import AmuleBridgeWrapper

struct IOSBridgeTimeoutError: LocalizedError, Equatable {
    let seconds: TimeInterval

    var errorDescription: String? {
        "iOS in-process bridge timed out after \(seconds) seconds"
    }
}

struct IOSInProcessBridgeAdapter: BridgeProtocol {
    typealias Runner = @Sendable (_ operation: String, _ arguments: [String], _ config: AMuleConnectionConfig) async throws -> String

    private let timeoutSeconds: TimeInterval
    private let runner: Runner

    init(timeoutSeconds: TimeInterval = 30, runner: @escaping Runner = IOSInProcessBridgeAdapter.defaultRunner) {
        self.timeoutSeconds = timeoutSeconds
        self.runner = runner
    }

    func connect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(operation: "connect", arguments: [], config: config)
        return (envelope.message ?? "Connect requested", raw)
    }

    func disconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(operation: "disconnect", arguments: [], config: config)
        return (envelope.message ?? "Disconnect requested", raw)
    }

    func capabilities(config: AMuleConnectionConfig) async throws -> (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String) {
        let (envelope, raw) = try await invoke(operation: "capabilities", arguments: [], config: config)
        guard let capabilities = envelope.capabilities else {
            throw AMuleClientError.invalidResponse(raw)
        }
        return (envelope.schemaVersion, capabilities, raw)
    }

    func status(config: AMuleConnectionConfig) async throws -> (BridgeStatusPayload, String) {
        let (envelope, raw) = try await invoke(operation: "status", arguments: [], config: config)
        guard let status = envelope.status else {
            throw AMuleClientError.invalidResponse(raw)
        }
        return (status, raw)
    }

    func downloads(config: AMuleConnectionConfig) async throws -> ([BridgeDownloadPayload], String) {
        let (envelope, raw) = try await invoke(operation: "downloads", arguments: [], config: config)
        return (envelope.downloads ?? [], raw)
    }

    func search(scope: String, query: String, polls: Int, pollIntervalMs: Int, config: AMuleConnectionConfig) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String) {
        let arguments = ["--scope", scope, "--query", query, "--polls", String(max(1, polls)), "--poll-interval-ms", String(max(100, pollIntervalMs))]
        let (envelope, raw) = try await invoke(operation: "search", arguments: arguments, config: config)
        return (envelope.progress ?? 0, envelope.results ?? [], raw)
    }

    func searchStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(operation: "search-stop", arguments: [], config: config)
        return (envelope.message ?? "Search stop requested", raw)
    }

    func download(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(operation: "download", arguments: ["--hash", hash], config: config)
        return (envelope.message ?? "Download request accepted", raw)
    }

    func addLink(link: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(operation: "add-link", arguments: ["--link", link], config: config)
        return (envelope.message ?? "Link add request accepted", raw)
    }

    func pause(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(operation: "pause", arguments: ["--hash", hash], config: config)
        return (envelope.message ?? "Pause requested", raw)
    }

    func resume(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(operation: "resume", arguments: ["--hash", hash], config: config)
        return (envelope.message ?? "Resume requested", raw)
    }

    func cancel(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let (envelope, raw) = try await invoke(operation: "cancel", arguments: ["--hash", hash], config: config)
        return (envelope.message ?? "Cancel requested", raw)
    }

    func serverConnect(ip: String?, port: Int?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        var arguments: [String] = []
        if let ip, !ip.isEmpty, let port {
            arguments = ["--server-ip", ip, "--server-port", String(port)]
        }
        let (envelope, raw) = try await invoke(operation: "server-connect", arguments: arguments, config: config)
        return (envelope.message ?? "Server connect requested", raw)
    }

    func sources(hash: String, config: AMuleConnectionConfig) async throws -> ([DownloadSourceItem], String) {
        let (envelope, raw) = try await invoke(operation: "sources", arguments: ["--hash", hash], config: config)
        let payloads = envelope.sources ?? []
        return (DownloadSourceItem.fromBridge(payloads), raw)
    }

    func prefsConnectionGet(config: AMuleConnectionConfig) async throws -> (BridgeConnectionPrefsPayload, String) {
        let (envelope, raw) = try await invoke(operation: "prefs-connection-get", arguments: [], config: config)
        guard let prefs = envelope.prefsConnection else {
            throw AMuleClientError.invalidResponse(raw)
        }
        return (prefs, raw)
    }

    func prefsConnectionSet(maxDownload: Int, maxUpload: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        let arguments = ["--max-dl", String(maxDownload), "--max-ul", String(maxUpload)]
        let (envelope, raw) = try await invoke(operation: "prefs-connection-set", arguments: arguments, config: config)
        return (envelope.message ?? "Connection speed limits updated", raw)
    }

    private func invoke(operation: String, arguments: [String], config: AMuleConnectionConfig) async throws -> (BridgeEnvelope, String) {
        let raw = try await withTaskCancellationHandler {
            try await withTimeout(seconds: timeoutSeconds) {
                try await runner(operation, arguments, config)
            }
        } onCancel: {}

        let envelope = try Self.decodeEnvelope(from: raw)
        guard envelope.ok else {
            throw AMuleClientError.bridgeFailure(envelope.error ?? "Bridge request failed")
        }
        return (envelope, raw)
    }

    private static func defaultRunner(operation: String, arguments: [String], config: AMuleConnectionConfig) async throws -> String {
        try Task.checkCancellation()
        return try await Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let json = runBridgeOperation(operation: operation, arguments: arguments, config: config)
            guard let json else { throw AMuleClientError.invalidResponse("Bridge wrapper returned null for operation '\(operation)'") }
            defer { AMuleBridgeWrapperFreeString(json) }
            let raw = String(cString: json)
            try Task.checkCancellation()
            return raw
        }.value
    }

    private static func runBridgeOperation(operation: String, arguments: [String], config: AMuleConnectionConfig) -> UnsafePointer<CChar>? {
        switch operation {
        case "capabilities":
            return AMuleBridgeWrapperCopyCapabilitiesJSON()
        case "connect":
            return AMuleBridgeWrapperCopyConnectJSON(config.host, Int32(config.port), config.password)
        case "disconnect":
            return AMuleBridgeWrapperCopyDisconnectJSON(config.host, Int32(config.port), config.password)
        case "status":
            return AMuleBridgeWrapperCopyStatusJSON(config.host, Int32(config.port), config.password)
        case "downloads":
            return AMuleBridgeWrapperCopyDownloadsJSON(config.host, Int32(config.port), config.password)
        case "search":
            return AMuleBridgeWrapperCopySearchJSON(
                config.host,
                Int32(config.port),
                config.password,
                argumentValue("--scope", in: arguments) ?? "kad",
                argumentValue("--query", in: arguments) ?? "",
                Int32(argumentValue("--polls", in: arguments).flatMap(Int.init) ?? 1),
                Int32(argumentValue("--poll-interval-ms", in: arguments).flatMap(Int.init) ?? 100)
            )
        case "search-stop":
            return AMuleBridgeWrapperCopySearchStopJSON(config.host, Int32(config.port), config.password)
        case "download":
            return AMuleBridgeWrapperCopyDownloadJSON(config.host, Int32(config.port), config.password, argumentValue("--hash", in: arguments) ?? "")
        case "add-link":
            return AMuleBridgeWrapperCopyAddLinkJSON(config.host, Int32(config.port), config.password, argumentValue("--link", in: arguments) ?? "")
        case "pause":
            return AMuleBridgeWrapperCopyPauseJSON(config.host, Int32(config.port), config.password, argumentValue("--hash", in: arguments) ?? "")
        case "resume":
            return AMuleBridgeWrapperCopyResumeJSON(config.host, Int32(config.port), config.password, argumentValue("--hash", in: arguments) ?? "")
        case "cancel":
            return AMuleBridgeWrapperCopyCancelJSON(config.host, Int32(config.port), config.password, argumentValue("--hash", in: arguments) ?? "")
        case "server-connect":
            let serverIP = argumentValue("--server-ip", in: arguments)
            let serverPort = Int32(argumentValue("--server-port", in: arguments).flatMap(Int.init) ?? 0)
            return AMuleBridgeWrapperCopyServerConnectJSON(config.host, Int32(config.port), config.password, serverIP, serverPort)
        case "sources":
            return AMuleBridgeWrapperCopySourcesJSON(config.host, Int32(config.port), config.password, argumentValue("--hash", in: arguments) ?? "")
        case "prefs-connection-get":
            return AMuleBridgeWrapperCopyPrefsConnectionGetJSON(config.host, Int32(config.port), config.password)
        case "prefs-connection-set":
            return AMuleBridgeWrapperCopyPrefsConnectionSetJSON(
                config.host,
                Int32(config.port),
                config.password,
                Int32(argumentValue("--max-dl", in: arguments).flatMap(Int.init) ?? 0),
                Int32(argumentValue("--max-ul", in: arguments).flatMap(Int.init) ?? 0)
            )
        default:
            return nil
        }
    }

    private static func argumentValue(_ flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                let nanoseconds = UInt64(max(0, seconds) * 1_000_000_000)
                try await Task.sleep(nanoseconds: nanoseconds)
                throw IOSBridgeTimeoutError(seconds: seconds)
            }

            guard let result = try await group.next() else {
                throw CancellationError()
            }
            group.cancelAll()
            return result
        }
    }

    private static func decodeEnvelope(from raw: String) throws -> BridgeEnvelope {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            throw AMuleClientError.invalidResponse(raw)
        }
        do {
            return try JSONDecoder().decode(BridgeEnvelope.self, from: data)
        } catch {
            throw AMuleClientError.invalidResponse(raw)
        }
    }
}
