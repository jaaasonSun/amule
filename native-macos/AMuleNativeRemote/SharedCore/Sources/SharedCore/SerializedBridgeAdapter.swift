import Foundation
import AMuleECBridgeAdapter

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
        try await queue.perform { try await wrapped.search(scope: scope, query: query, polls: polls, pollIntervalMs: pollIntervalMs, config: config) }
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

    public func rename(hash: String, name: String, config: AMuleConnectionConfig) async throws -> RenameAcknowledgement {
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
        try await queue.perform { try await wrapped.prefsConnectionSet(maxDownload: maxDownload, maxUpload: maxUpload, config: config) }
    }

    public func kadStart(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.kadStart(config: config) }
    }

    public func kadStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.kadStop(config: config) }
    }

    public func kadBootstrap(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.kadBootstrap(ip: ip, port: port, config: config) }
    }

    public func kadUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.kadUpdateFromURL(url: url, config: config) }
    }

    public func uploads(config: AMuleConnectionConfig) async throws -> ([BridgeUploadPayload], String) {
        try await queue.perform { try await wrapped.uploads(config: config) }
    }

    public func sharedFiles(config: AMuleConnectionConfig) async throws -> ([BridgeSharedFilePayload], String) {
        try await queue.perform { try await wrapped.sharedFiles(config: config) }
    }

    public func sharedFilesReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.sharedFilesReload(config: config) }
    }

    public func coreLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) {
        try await queue.perform { try await wrapped.coreLog(config: config) }
    }

    public func debugLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) {
        try await queue.perform { try await wrapped.debugLog(config: config) }
    }

    public func categories(config: AMuleConnectionConfig) async throws -> ([BridgeCategoryPayload], String) {
        try await queue.perform { try await wrapped.categories(config: config) }
    }

    public func categoryCreate(name: String, path: String, comment: String, color: Int, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.categoryCreate(name: name, path: path, comment: comment, color: color, priority: priority, config: config) }
    }

    public func categoryDelete(categoryID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.categoryDelete(categoryID: categoryID, config: config) }
    }

    public func ipfilterReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.ipfilterReload(config: config) }
    }

    public func ipfilterUpdate(url: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.ipfilterUpdate(url: url, config: config) }
    }

    public func friends(config: AMuleConnectionConfig) async throws -> ([BridgeFriendPayload], String) {
        try await queue.perform { try await wrapped.friends(config: config) }
    }

    public func friendRemove(friendID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.friendRemove(friendID: friendID, config: config) }
    }

    public func friendSlot(friendID: Int, enabled: Bool, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.friendSlot(friendID: friendID, enabled: enabled, config: config) }
    }

    public func clearCompleted(ecids: [Int], config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.clearCompleted(ecids: ecids, config: config) }
    }

    public func priority(hash: String, value: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.priority(hash: hash, value: value, config: config) }
    }

    public func statsTree(capping: Int?, config: AMuleConnectionConfig) async throws -> (BridgeStatsTreeNodePayload, String) {
        try await queue.perform { try await wrapped.statsTree(capping: capping, config: config) }
    }

    public func statsGraphs(width: Int, scale: Int, last: Double?, config: AMuleConnectionConfig) async throws -> (BridgeStatsGraphsPayload, String) {
        try await queue.perform { try await wrapped.statsGraphs(width: width, scale: scale, last: last, config: config) }
    }
}

actor BridgeOperationQueue {
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
