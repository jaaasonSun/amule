import Foundation

public struct SerializedBridgeAdapter: BridgeProtocol {
    private let wrapped: any BridgeProtocol
    private let queue = BridgeOperationQueue()

    public init(wrapping wrapped: any BridgeProtocol) {
        self.wrapped = wrapped
    }

    public func connect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.connect(config: config) }
    }

    public func disconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.disconnect(config: config) }
    }

    public func capabilities(config: AMuleConnectionConfig) async throws -> (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String) {
        try await queue.perform { try await wrapped.capabilities(config: config) }
    }

    public func status(config: AMuleConnectionConfig) async throws -> (BridgeStatusPayload, String) {
        try await queue.perform { try await wrapped.status(config: config) }
    }

    public func downloads(config: AMuleConnectionConfig) async throws -> ([BridgeDownloadPayload], String) {
        try await queue.perform { try await wrapped.downloads(config: config) }
    }

    public func search(scope: String, query: String, polls: Int, pollIntervalMs: Int, config: AMuleConnectionConfig) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String) {
        try await queue.perform {
            try await wrapped.search(scope: scope, query: query, polls: polls, pollIntervalMs: pollIntervalMs, config: config)
        }
    }

    public func searchStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.searchStop(config: config) }
    }

    public func download(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.download(hash: hash, config: config) }
    }

    public func addLink(link: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.addLink(link: link, config: config) }
    }

    public func rename(hash: String, name: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.rename(hash: hash, name: name, config: config) }
    }

    public func pause(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.pause(hash: hash, config: config) }
    }

    public func resume(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.resume(hash: hash, config: config) }
    }

    public func cancel(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.cancel(hash: hash, config: config) }
    }

    public func servers(config: AMuleConnectionConfig) async throws -> ([BridgeServerPayload], String) {
        try await queue.perform { try await wrapped.servers(config: config) }
    }

    public func serverConnect(ip: String?, port: Int?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.serverConnect(ip: ip, port: port, config: config) }
    }

    public func serverDisconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.serverDisconnect(config: config) }
    }

    public func serverAdd(address: String, name: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.serverAdd(address: address, name: name, config: config) }
    }

    public func serverRemove(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.serverRemove(ip: ip, port: port, config: config) }
    }

    public func serverUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.serverUpdateFromURL(url: url, config: config) }
    }

    public func sources(hash: String, config: AMuleConnectionConfig) async throws -> ([DownloadSourceItem], String) {
        try await queue.perform { try await wrapped.sources(hash: hash, config: config) }
    }

    public func prefsConnectionGet(config: AMuleConnectionConfig) async throws -> (BridgeConnectionPrefsPayload, String) {
        try await queue.perform { try await wrapped.prefsConnectionGet(config: config) }
    }

    public func prefsConnectionSet(maxDownload: Int, maxUpload: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform {
            try await wrapped.prefsConnectionSet(maxDownload: maxDownload, maxUpload: maxUpload, config: config)
        }
    }
}

private actor BridgeOperationQueue {
    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func perform<T: Sendable>(_ operation: () async throws -> T) async throws -> T {
        await acquire()
        do {
            let result = try await operation()
            release()
            return result
        } catch {
            release()
            throw error
        }
    }

    private func acquire() async {
        guard isLocked else {
            isLocked = true
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func release() {
        guard !waiters.isEmpty else {
            isLocked = false
            return
        }

        waiters.removeFirst().resume()
    }
}
