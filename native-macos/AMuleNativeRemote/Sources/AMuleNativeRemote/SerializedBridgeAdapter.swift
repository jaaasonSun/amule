import Foundation
import AMuleECBridgeAdapter

struct SerializedBridgeAdapter: BridgeProtocol {
    private let wrapped: any BridgeProtocol
    private let queue = BridgeOperationQueue()

    init(wrapping wrapped: any BridgeProtocol) {
        self.wrapped = wrapped
    }

    func connect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.connect(config: config) }
    }

    func disconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.disconnect(config: config) }
    }

    func capabilities(config: AMuleConnectionConfig) async throws -> (schemaVersion: Int?, capabilities: BridgeCapabilitiesPayload, raw: String) {
        try await queue.perform { try await wrapped.capabilities(config: config) }
    }

    func status(config: AMuleConnectionConfig) async throws -> (BridgeStatusPayload, String) {
        try await queue.perform { try await wrapped.status(config: config) }
    }

    func downloads(config: AMuleConnectionConfig) async throws -> ([BridgeDownloadPayload], String) {
        try await queue.perform { try await wrapped.downloads(config: config) }
    }

    func search(scope: String, query: String, polls: Int, pollIntervalMs: Int, config: AMuleConnectionConfig) async throws -> (progress: Int, results: [BridgeSearchPayload], raw: String) {
        try await queue.perform { try await wrapped.search(scope: scope, query: query, polls: polls, pollIntervalMs: pollIntervalMs, config: config) }
    }

    func searchStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.searchStop(config: config) }
    }

    func download(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.download(hash: hash, config: config) }
    }

    func addLink(link: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.addLink(link: link, config: config) }
    }

    func rename(hash: String, name: String, config: AMuleConnectionConfig) async throws -> RenameAcknowledgement {
        try await queue.perform { try await wrapped.rename(hash: hash, name: name, config: config) }
    }

    func pause(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.pause(hash: hash, config: config) }
    }

    func resume(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.resume(hash: hash, config: config) }
    }

    func cancel(hash: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.cancel(hash: hash, config: config) }
    }

    func servers(config: AMuleConnectionConfig) async throws -> ([BridgeServerPayload], String) {
        try await queue.perform { try await wrapped.servers(config: config) }
    }

    func serverConnect(ip: String?, port: Int?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.serverConnect(ip: ip, port: port, config: config) }
    }

    func serverDisconnect(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.serverDisconnect(config: config) }
    }

    func serverAdd(address: String, name: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.serverAdd(address: address, name: name, config: config) }
    }

    func serverRemove(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.serverRemove(ip: ip, port: port, config: config) }
    }

    func serverUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.serverUpdateFromURL(url: url, config: config) }
    }

    func sources(hash: String, config: AMuleConnectionConfig) async throws -> ([DownloadSourceItem], String) {
        try await queue.perform { try await wrapped.sources(hash: hash, config: config) }
    }

    func prefsConnectionGet(config: AMuleConnectionConfig) async throws -> (BridgeConnectionPrefsPayload, String) {
        try await queue.perform { try await wrapped.prefsConnectionGet(config: config) }
    }

    func prefsConnectionSet(maxDownload: Int, maxUpload: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.prefsConnectionSet(maxDownload: maxDownload, maxUpload: maxUpload, config: config) }
    }

    func kadStart(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.kadStart(config: config) }
    }

    func kadStop(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.kadStop(config: config) }
    }

    func kadBootstrap(ip: String, port: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.kadBootstrap(ip: ip, port: port, config: config) }
    }

    func kadUpdateFromURL(url: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.kadUpdateFromURL(url: url, config: config) }
    }

    func uploads(config: AMuleConnectionConfig) async throws -> ([BridgeUploadPayload], String) {
        try await queue.perform { try await wrapped.uploads(config: config) }
    }

    func sharedFiles(config: AMuleConnectionConfig) async throws -> ([BridgeSharedFilePayload], String) {
        try await queue.perform { try await wrapped.sharedFiles(config: config) }
    }

    func sharedFilesReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.sharedFilesReload(config: config) }
    }

    func coreLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) {
        try await queue.perform { try await wrapped.coreLog(config: config) }
    }

    func debugLog(config: AMuleConnectionConfig) async throws -> (BridgeCoreLogPayload, String) {
        try await queue.perform { try await wrapped.debugLog(config: config) }
    }

    func categories(config: AMuleConnectionConfig) async throws -> ([BridgeCategoryPayload], String) {
        try await queue.perform { try await wrapped.categories(config: config) }
    }

    func categoryCreate(name: String, path: String, comment: String, color: Int, priority: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.categoryCreate(name: name, path: path, comment: comment, color: color, priority: priority, config: config) }
    }

    func categoryDelete(categoryID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.categoryDelete(categoryID: categoryID, config: config) }
    }

    func ipfilterReload(config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.ipfilterReload(config: config) }
    }

    func ipfilterUpdate(url: String?, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.ipfilterUpdate(url: url, config: config) }
    }

    func friends(config: AMuleConnectionConfig) async throws -> ([BridgeFriendPayload], String) {
        try await queue.perform { try await wrapped.friends(config: config) }
    }

    func friendRemove(friendID: Int, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.friendRemove(friendID: friendID, config: config) }
    }

    func friendSlot(friendID: Int, enabled: Bool, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.friendSlot(friendID: friendID, enabled: enabled, config: config) }
    }

    func clearCompleted(ecids: [Int], config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.clearCompleted(ecids: ecids, config: config) }
    }

    func priority(hash: String, value: String, config: AMuleConnectionConfig) async throws -> (message: String, raw: String) {
        try await queue.perform { try await wrapped.priority(hash: hash, value: value, config: config) }
    }

    func statsTree(capping: Int?, config: AMuleConnectionConfig) async throws -> (BridgeStatsTreeNodePayload, String) {
        try await queue.perform { try await wrapped.statsTree(capping: capping, config: config) }
    }

    func statsGraphs(width: Int, scale: Int, last: Double?, config: AMuleConnectionConfig) async throws -> (BridgeStatsGraphsPayload, String) {
        try await queue.perform { try await wrapped.statsGraphs(width: width, scale: scale, last: last, config: config) }
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
